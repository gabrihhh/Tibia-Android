#!/usr/bin/env python3
"""Monta o runtime mínimo que vai dentro do APK (android/assets/runtime.tar.gz).

Parte do rootfs Debian ARM64 copiado do tablet e leva só o necessário:
- as libs que o cliente carregou (lista capturada em proto/used-libs.txt) e as
  dependências delas (DT_NEEDED, recursivo), ARM64 e x86_64;
- box64, o loader glibc, o Python (para o atualizador) e os módulos dele;
- dados que o Android não tem: teclado (xkb), fusos, fontes, locale C.UTF-8;
- virgl/ANGLE, as libs de compatibilidade, certificados e scripts.

O cliente do Tibia NÃO entra: ele é baixado da CDN oficial pelo app.

Uso: build-runtime.py <rootfs-src> <used-libs.txt> <saida.tar.gz>
"""
import os
import re
import struct
import subprocess
import sys
import tarfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARM = "usr/lib/aarch64-linux-gnu"
X86 = "usr/lib/x86_64-linux-gnu"
PY = "usr/lib/python3.13"
PY_SKIP = {"test", "idlelib", "tkinter", "turtledemo", "ensurepip", "lib2to3", "pydoc_data", "venv"}
DATA_DIRS = [
    "usr/share/X11/xkb", "usr/share/X11/locale", "usr/share/zoneinfo", "usr/share/fonts",
    "usr/share/glvnd", "usr/lib/locale/C.utf8", "etc/fonts", f"{ARM}/dri",
]
# extras vindos do projeto/dispositivo: destino no runtime -> origem
EXTRAS = {
    "bin": "android/runtime/bin",
    "bin/tibia-fetch.py": "tools/tibia-fetch.py",
    "libqtthreadfix.so": "proto/shim/libqtthreadfix.so",
    "libseccompfix.so": "proto/shim/libseccompfix.so",
    "virgl/libabstractsock-glibc.so": "proto/shim/libabstractsock-glibc.so",
    "virgl/libabstractsock-bionic.so": "proto/shim/libabstractsock-bionic.so",
    "virgl/virgl_server": "proto/dl/virgl/virgl_test_server_android",  # original; o app ajusta os caminhos
    "virgl/libepoxy.so": "proto/dl/virgl/lib/libepoxy.so",
    "virgl/libvirglrenderer.so": "proto/dl/virgl/lib/libvirglrenderer.so",
    "virgl/angle/vulkan": "proto/dl/virgl/angle/vulkan",
    "virgl/angle/gl": "proto/dl/virgl/angle/gl",
    "x11-loader.apk": "proto/dl/x11/deb/data/data/com.termux/files/usr/libexec/termux-x11/loader.apk",
}


# Syscalls que o seccomp dos apps Android proíbe (SIGSYS mata o processo) e que o
# glibc faz no loader e em cada thread nova: set_robust_list (99) e rseq (293).
# Trocamos o "svc #0" dessas chamadas por "movn x0, #37": retorna -ENOSYS, que o
# glibc trata como "não suportado".
BLOCKED_SYSCALLS = {99: "set_robust_list", 293: "rseq"}
SVC0, MOVN_X0_ENOSYS = 0xd4000001, 0x928004a0


def patch_blocked_syscalls(data):
    words = list(struct.unpack(f"<{len(data) // 4}I", data[: len(data) // 4 * 4]))
    movs = {0xd2800008 | (n << 5): name for n, name in BLOCKED_SYSCALLS.items()}  # mov x8, #n
    patched = {}
    for i, w in enumerate(words):
        if w not in movs:
            continue
        for j in range(i + 1, min(i + 10, len(words))):
            if words[j] == SVC0:
                words[j] = MOVN_X0_ENOSYS
                patched[movs[w]] = patched.get(movs[w], 0) + 1
                break
    assert patched, "nenhuma syscall proibida encontrada"
    print("  syscalls neutralizadas:", patched)
    return struct.pack(f"<{len(words)}I", *words) + data[len(words) * 4:]


def needed(path):
    out = subprocess.run(["readelf", "-d", path], capture_output=True, text=True).stdout
    return re.findall(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]", out)


def closure(src, libdir, names):
    """Resolve nomes de lib dentro de libdir, seguindo DT_NEEDED."""
    found, todo = set(), list(names)
    while todo:
        name = todo.pop()
        rel = f"{libdir}/{name}"
        if rel in found or not os.path.lexists(os.path.join(src, rel)):
            continue
        found.add(rel)
        real = os.path.realpath(os.path.join(src, rel))
        if real.startswith(os.path.realpath(src)) and os.path.isfile(real):
            todo.extend(needed(real))
    return found


def add_with_targets(src, rel, out):
    """Adiciona rel e, se for symlink, a cadeia até o arquivo real."""
    while rel not in out:
        out.add(rel)
        full = os.path.join(src, rel)
        if not os.path.islink(full):
            return
        target = os.readlink(full)
        rel = os.path.normpath(os.path.join(os.path.dirname(rel), target) if not target.startswith("/") else target[1:])


def main():
    src, used_list, dest = sys.argv[1:4]
    used = [l.strip() for l in open(used_list) if l.strip()]

    arm_names, x86_names = set(), set()
    for item in used:
        base = os.path.basename(item)
        if "/x86_64-linux-gnu/" in item:
            x86_names.add(base)
        elif "/aarch64-linux-gnu/" in item:
            arm_names.add(base)
        elif "/" not in item:
            # nomes soltos vêm do log do box64 ("Using native/emulated <soname>");
            # o closure ignora o que não existir em cada pasta
            arm_names.add(base)
            x86_names.add(base)

    files = set()
    # box64, python e seus módulos nativos também puxam libs
    for exe in ["usr/bin/box64", "usr/bin/python3.13"]:
        files.add(exe)
        arm_names.update(needed(os.path.join(src, exe)))
    files.add("usr/bin/python3")
    for dirpath, dirnames, filenames in os.walk(os.path.join(src, PY)):
        rel_dir = os.path.relpath(dirpath, src)
        dirnames[:] = [d for d in dirnames if d not in PY_SKIP]
        for f in filenames:
            files.add(os.path.join(rel_dir, f))
            if f.endswith(".so"):
                arm_names.update(needed(os.path.join(dirpath, f)))
    for d in DATA_DIRS:
        for dirpath, dirnames, filenames in os.walk(os.path.join(src, d)):
            rel_dir = os.path.relpath(dirpath, src)
            for f in filenames + [x for x in dirnames if os.path.islink(os.path.join(dirpath, x))]:
                files.add(os.path.join(rel_dir, f))
                full = os.path.join(dirpath, f)
                if f.endswith(".so") and os.path.isfile(full):
                    arm_names.update(needed(full))
    # loader glibc ARM64
    arm_names.add("ld-linux-aarch64.so.1")

    libs = closure(src, ARM, arm_names) | closure(src, X86, x86_names)
    for rel in list(files) + sorted(libs) + ["lib/ld-linux-aarch64.so.1"]:
        add_with_targets(src, rel, files)
    files.update(libs)

    # nomes alternativos (sonames): a lista capturada tem só os arquivos reais, mas
    # o libglvnd, por exemplo, abre "libGLX_mesa.so.0", que é um symlink
    for libdir in (ARM, X86):
        real_files = {os.path.realpath(os.path.join(src, r)) for r in files if r.startswith(libdir)}
        for name in os.listdir(os.path.join(src, libdir)):
            full = os.path.join(src, libdir, name)
            if os.path.islink(full) and os.path.realpath(full) in real_files:
                files.add(f"{libdir}/{name}")

    # usr-merge: lib/, bin/ e sbin/ são symlinks para usr/; grava tudo pelo caminho
    # real e cria os symlinks só no fim (o extrator do app não segue link pendente)
    merged = {"lib", "bin", "sbin"}
    files = {f"usr/{r}" if r.split("/", 1)[0] in merged and "/" in r else r for r in files} - merged
    tmp = os.path.join(os.path.dirname(dest), ".build-runtime.tmp")

    def add_bytes(tar, data, arcname, mode=0o755):
        with open(tmp, "wb") as f:
            f.write(data)
        os.chmod(tmp, mode)
        tar.add(tmp, arcname=arcname)
        os.remove(tmp)

    loader = f"{ARM}/ld-linux-aarch64.so.1"
    with tarfile.open(dest, "w:gz", compresslevel=6) as tar:
        for rel in sorted(files):
            full = os.path.join(src, rel)
            if rel == loader:
                add_bytes(tar, patch_blocked_syscalls(open(full, "rb").read()), f"rootfs/{rel}")
            elif os.path.lexists(full):
                tar.add(full, arcname=f"rootfs/{rel}", recursive=False)
        # glibc-fix: libc com /etc/resolv.conf trocado por /proc/self/cwd/r (mesmo
        # tamanho) e sem as syscalls proibidas
        libc = open(os.path.join(src, ARM, "libc.so.6"), "rb").read()
        a, b = b"/etc/resolv.conf\0", b"/proc/self/cwd/r\0"
        assert libc.count(a) == 1
        add_bytes(tar, patch_blocked_syscalls(libc.replace(a, b)), "glibc-fix/libc.so.6")
        # certificados: bundle completo + só ISRG (o cliente cai com o bundle completo)
        mozilla = os.path.join(src, "usr/share/ca-certificates/mozilla")
        tar.add(os.path.join(src, "etc/ssl/certs/ca-certificates.crt"), arcname="certs/ca-bundle.pem")
        isrg = os.path.join(os.path.dirname(dest), "tibia-ca.pem")
        with open(isrg, "wb") as f:
            for name in ("ISRG_Root_X1.crt", "ISRG_Root_X2.crt"):
                f.write(open(os.path.join(mozilla, name), "rb").read())
        tar.add(isrg, arcname="certs/tibia-ca.pem")
        os.remove(isrg)
        for arc, rel in EXTRAS.items():
            tar.add(os.path.join(ROOT, rel), arcname=arc)
        for link in sorted(merged):
            tar.add(os.path.join(src, link), arcname=f"rootfs/{link}")

    print(f"{len(files)} arquivos do rootfs, {len(libs)} libs; {os.path.getsize(dest) / 1e6:.0f} MB -> {dest}")


if __name__ == "__main__":
    main()
