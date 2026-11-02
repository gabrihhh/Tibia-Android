#!/usr/bin/env python3
"""Baixa/atualiza o cliente Linux oficial do Tibia direto da CDN da CipSoft.

Faz o mesmo que o launcher oficial: lê os package.json do cliente e dos assets,
baixa só o que mudou (confere sha256) e descompacta os .lzma.

Uso: tibia-fetch.py <pasta-destino>
"""
import concurrent.futures
import hashlib
import json
import lzma
import os
import sys
import urllib.request

CDN = "https://static.tibia.com/launcher"
# (pasta na CDN, manifesto, arquivo de versão que o cliente lê na raiz)
SOURCES = [
    ("tibiaclient-linux-current", "package.json", "package.json.version"),
    ("assets-current", "assets.json", "assets.json.sha256"),
]
HEADER_SIZE = 32  # cabeçalho próprio da CipSoft antes do stream LZMA


def get(url, tries=5):
    req = urllib.request.Request(url, headers={"Referer": url, "User-Agent": "Mozilla/5.0"})
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except OSError:
            if attempt == tries - 1:
                raise


def unpack(data, entry):
    if entry["packedhash"] == entry["unpackedhash"]:
        return data  # arquivo guardado sem compressão
    # O campo de tamanho do cabeçalho LZMA vem errado: força "tamanho desconhecido".
    stream = data[HEADER_SIZE:]
    stream = stream[:5] + b"\xff" * 8 + stream[13:]
    out = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(stream)
    return out[: entry["unpackedsize"]]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_entry(base, entry, dest):
    if entry.get("unpack") is False:  # assets que vêm crus (sem .lzma)
        entry = dict(entry, unpackedhash=entry["packedhash"], unpackedsize=entry["packedsize"])
    path = os.path.join(dest, entry["localfile"])
    if os.path.exists(path) and sha256_file(path) == entry["unpackedhash"]:
        return 0
    data = get(f"{CDN}/{base}/{entry['url']}")
    if hashlib.sha256(data).hexdigest() != entry["packedhash"]:
        raise RuntimeError(f"hash do pacote não confere: {entry['url']}")
    out = unpack(data, entry)
    if hashlib.sha256(out).hexdigest() != entry["unpackedhash"]:
        raise RuntimeError(f"hash descompactado não confere: {entry['localfile']}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".part"
    with open(tmp, "wb") as f:
        f.write(out)
    os.replace(tmp, path)
    if entry.get("executable") or entry["localfile"] in ("bin/client", "bin/libexec/QtWebEngineProcess"):
        os.chmod(path, 0o755)
    return len(data)


def main():
    dest = sys.argv[1]
    os.makedirs(dest, exist_ok=True)
    for base, index, version_file in SOURCES:
        manifest = json.loads(get(f"{CDN}/{base}/{index}"))
        files = manifest["files"]
        print(f"{base}: {len(files)} arquivos, versão {manifest.get('version', '?')}", flush=True)
        done = total = 0
        with concurrent.futures.ThreadPoolExecutor(8) as pool:
            for n in pool.map(lambda e: fetch_entry(base, e, dest), files):
                done += 1
                total += n
                if done % 500 == 0:
                    print(f"  {done}/{len(files)} ({total / 1e6:.0f} MB baixados)", flush=True)
        with open(os.path.join(dest, index), "w") as f:
            json.dump(manifest, f)
        # Sem isto o login envia "assetversion" vazio e o servidor recusa
        # com "your client version is too old".
        with open(os.path.join(dest, version_file), "wb") as f:
            f.write(get(f"{CDN}/{base}/{version_file}"))
    print("ok")


if __name__ == "__main__":
    main()
