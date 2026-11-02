# Tibia Android (Tibia Droid)

Roda o **cliente Linux oficial do Tibia** num tablet Android, sem root e sem PC:
um app que, ao tocar no ícone, prepara o ambiente, baixa/atualiza o cliente pela
CDN oficial da CipSoft e abre o jogo em tela cheia, desenhado pela GPU do aparelho.

Testado no **Samsung Galaxy Tab S10 FE** (Exynos 1580, GPU Xclipse 540, Android 16).

> Projeto pessoal, sem relação com a CipSoft. Nenhum arquivo do Tibia é
> distribuído aqui: o app baixa o cliente direto de `static.tibia.com`.

**Download:** [TibiaDroid.apk (v0.1)](https://github.com/gabrihhh/Tibia-Android/releases/download/v0.1/TibiaDroid.apk)
· [todas as versões](https://github.com/gabrihhh/Tibia-Android/releases)

## Como funciona

```
Tibia Droid (app Android, serviço em primeiro plano)
 ├─ servidor X ........ Termux:X11 (app separado) mostra a tela
 ├─ servidor de GPU ... virgl → ANGLE → Vulkan do Android (driver da Samsung)
 └─ cliente Tibia ..... x86_64, emulado pelo box64 sobre um glibc ARM64
                        OpenGL via Mesa "virpipe" (vai para o virgl)
```

Detalhes de cada problema encontrado e de como foi resolvido estão em
[`PLANO-APK.md`](PLANO-APK.md).

## Para jogar (no tablet)

**Requisitos**

- Tablet/celular Android **ARM64** (Android 9 ou mais novo; testado no 16).
- App **Termux:X11** instalado:
  <https://github.com/termux/termux-x11/releases> (`termux-x11-universal-debug.apk`).
- ~2 GB livres (runtime ~350 MB + cliente ~700 MB) e internet.
- Teclado e mouse (USB ou Bluetooth) recomendados. A barra de teclas do
  Termux:X11 tem um botão para abrir o teclado da tela.

**Instalação**

1. Instale o Termux:X11.
2. Baixe e instale o [`TibiaDroid.apk`](https://github.com/gabrihhh/Tibia-Android/releases/download/v0.1/TibiaDroid.apk)
   (permita "instalar de fontes desconhecidas"), ou gere o seu como descrito abaixo.
3. Toque em **Tibia Droid**. Na primeira vez ele prepara o ambiente (1–2 min) e
   baixa o cliente (~700 MB). Depois o jogo abre no Termux:X11.

Durante o jogo fica uma notificação "Tibia em execução" com o botão **Encerrar**.

**Limitações conhecidas**

- Precisa do app Termux:X11 instalado à parte.
- Tela interna em 1600×1000 ampliada (trocar nas preferências do Termux:X11).
- **BattlEye**: ainda não testado em mundos protegidos; jogar neles é por sua conta.

## Para compilar (no PC Linux)

**Ferramentas**

- Android SDK com `build-tools;36.0.0`, `platforms;android-36` e NDK (27.x).
- JDK 17, Python 3, Docker (cross-compiler ARM64 do Debian), `adb`.

**Insumos que não ficam no repositório** (binários de terceiros; os caminhos
são os que os scripts esperam):

| Caminho | O que é | De onde vem |
|---|---|---|
| `proto/runtime-src/rootfs/` | rootfs Debian trixie ARM64 com `box64` (0.4.3, do sid), Mesa, Qt deps, `python3` e libs amd64 instaladas | montado no aparelho com proot + `apt`; ver `PLANO-APK.md` |
| `proto/dl/virgl/` | `virgl_test_server_android`, `libvirglrenderer.so`, `libepoxy.so` e ANGLE (`angle/vulkan`, `angle/gl`) | pacote `virglrenderer-android` do Termux |
| `proto/dl/x11/deb/.../loader.apk` | loader do Termux:X11 | pacote `.deb` das releases do Termux:X11 |

`proto/used-libs.txt` (no repositório) é a lista de libs que o cliente carrega,
capturada de um cliente em execução; o runtime é montado a partir dela.

**Passos**

```bash
tools/build-shims.sh                       # libs de compatibilidade (proto/shim/*.so)
python3 tools/build-runtime.py proto/runtime-src/rootfs proto/used-libs.txt \
        android/assets/runtime.tar.gz      # runtime mínimo (~109 MB)
tools/build-apk.sh                         # android/build/TibiaDroid.apk
adb install -r android/build/TibiaDroid.apk
```

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `android/` | app (Java), manifesto e scripts do runtime (`runtime/bin/*.sh`) |
| `tools/` | `tibia-fetch.py` (atualizador da CDN), builds do runtime, das libs e do APK |
| `proto/shim/` | libs de compatibilidade (threads do Qt no box64, seccomp, sockets) |
| `proto/device/` | protótipo rodando pelo `adb shell`, antes do APK |
| `proto/tests/` | testes e diagnósticos usados durante o port |
| `GUIA.md`, `PLANO.md` | tentativa anterior com Winlator (histórico; não funcionou) |

## Licenças de terceiros

O APK empacota componentes de terceiros com licenças próprias: box64 (MIT),
glibc e demais pacotes Debian (GPL/LGPL e outras), Mesa (MIT), virglrenderer
(MIT), ANGLE (BSD) e o loader do Termux:X11 (GPL-3.0). O cliente do Tibia e
seus arquivos pertencem à CipSoft GmbH e não fazem parte deste repositório.
