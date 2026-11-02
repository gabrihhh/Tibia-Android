<div align="center">

# ⚔️ Tibia Droid

**O cliente oficial do Tibia rodando no seu tablet Android — sem root, sem PC.**

Toque no ícone e jogue: o app prepara o ambiente, baixa o cliente oficial da
CipSoft e abre o jogo em tela cheia, desenhado pela GPU do aparelho.

<br>

<a href="https://github.com/gabrihhh/Tibia-Android/releases/download/v0.1/TibiaDroid.apk">
  <img src="https://img.shields.io/badge/Baixar_APK-v0.1-2ea44f?style=for-the-badge&logo=android&logoColor=white" alt="Baixar APK v0.1" height="48">
</a>

<br><br>

<a href="https://github.com/termux/termux-x11/releases">
  <img src="https://img.shields.io/badge/Requer-Termux:X11-1f1f1f?style=flat-square&logo=x.org&logoColor=white" alt="Requer Termux:X11">
</a>
<img src="https://img.shields.io/badge/Android-9%2B_ARM64-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android 9+ ARM64">
<img src="https://img.shields.io/badge/root-n%C3%A3o_precisa-blue?style=flat-square" alt="Sem root">
<img src="https://img.shields.io/badge/status-pre--release-orange?style=flat-square" alt="Pre-release">
<a href="https://github.com/gabrihhh/Tibia-Android/releases">
  <img src="https://img.shields.io/github/v/release/gabrihhh/Tibia-Android?include_prereleases&style=flat-square&label=release" alt="Release">
</a>

</div>

---

> [!NOTE]
> Projeto pessoal, sem relação com a CipSoft. **Nenhum arquivo do Tibia é
> distribuído aqui**: o app baixa o cliente direto de `static.tibia.com`.

## ✨ Destaques

| | |
|---|---|
| 🎮 **Cliente oficial** | O mesmo cliente Linux que a CipSoft publica, sempre atualizado pela CDN oficial. |
| 🚀 **Abre direto** | Um ícone na tela inicial; nada de terminal nem configuração. |
| 🖥️ **GPU de verdade** | Desenho pela GPU do aparelho (virgl → ANGLE → Vulkan), não pelo processador. |
| 🔓 **Sem root** | Roda como um app comum. |
| 📱 **Testado** | Samsung Galaxy Tab S10 FE (Exynos 1580 · Xclipse 540 · Android 16). |

## 📲 Instalação

> [!IMPORTANT]
> Precisa de um Android **ARM64** (9 ou mais novo), **~2 GB livres** e internet.
> Teclado e mouse (USB ou Bluetooth) são recomendados.

1. **Instale o [Termux:X11](https://github.com/termux/termux-x11/releases)**
   (`termux-x11-universal-debug.apk`) — é ele que mostra a tela do jogo.
2. **Baixe e instale o [`TibiaDroid.apk`](https://github.com/gabrihhh/Tibia-Android/releases/download/v0.1/TibiaDroid.apk)**
   (permita "instalar de fontes desconhecidas").
3. **Abra o Tibia Droid.** Na primeira vez:

   | Etapa | Tempo |
   |---|---|
   | Preparar o ambiente | 1–2 min |
   | Baixar o cliente oficial (~700 MB) | depende da internet |
   | Abrir o jogo no Termux:X11 | ~30 s |

Durante o jogo fica uma notificação **"Tibia em execução"** com o botão
**Encerrar**. Tocar no ícone ou na notificação volta para o jogo.

> [!TIP]
> Sem teclado físico? A barra de teclas do Termux:X11 tem um botão ⌨ que abre o
> teclado da tela.

## ⚠️ Limitações conhecidas

- Precisa do app **Termux:X11** instalado à parte.
- A tela interna é **1600×1000**, ampliada para o tamanho do aparelho
  (dá para trocar nas preferências do Termux:X11).
- **BattlEye** ainda não foi testado em mundos protegidos — jogue neles por sua conta.
- O APK é assinado com chave de debug.

## 🛠️ Como funciona

```
Tibia Droid (app Android, serviço em primeiro plano)
 ├─ servidor X ........ Termux:X11 (app separado) mostra a tela
 ├─ servidor de GPU ... virgl → ANGLE → Vulkan do Android (driver da Samsung)
 └─ cliente Tibia ..... x86_64, emulado pelo box64 sobre um glibc ARM64
                        OpenGL via Mesa "virpipe" (vai para o virgl)
```

O caminho até aqui teve vários obstáculos (seccomp do Android, threads do Qt
sob o box64, DNS, certificados, fuso horário…). Cada um, com a causa e a
correção, está documentado em [`PLANO-APK.md`](PLANO-APK.md).

<details>
<summary><b>🧱 Compilar o APK (PC Linux)</b></summary>

<br>

**Ferramentas**

- Android SDK com `build-tools;36.0.0`, `platforms;android-36` e NDK (27.x)
- JDK 17, Python 3, Docker (cross-compiler ARM64 do Debian), `adb`

**Insumos que não ficam no repositório** (binários de terceiros; os caminhos
são os que os scripts esperam):

| Caminho | O que é | De onde vem |
|---|---|---|
| `proto/runtime-src/rootfs/` | rootfs Debian trixie ARM64 com `box64` (0.4.3, do sid), Mesa, dependências do Qt, `python3` e libs amd64 | montado no aparelho com proot + `apt` (ver `PLANO-APK.md`) |
| `proto/dl/virgl/` | `virgl_test_server_android`, `libvirglrenderer.so`, `libepoxy.so` e ANGLE (`angle/vulkan`, `angle/gl`) | pacote `virglrenderer-android` do Termux |
| `proto/dl/x11/deb/.../loader.apk` | loader do Termux:X11 | `.deb` das releases do Termux:X11 |

`proto/used-libs.txt` é a lista de libs que o cliente carrega, capturada de um
cliente em execução; o runtime é montado a partir dela.

**Passos**

```bash
tools/build-shims.sh                       # libs de compatibilidade (proto/shim/*.so)
python3 tools/build-runtime.py proto/runtime-src/rootfs proto/used-libs.txt \
        android/assets/runtime.tar.gz      # runtime mínimo (~109 MB)
tools/build-apk.sh                         # android/build/TibiaDroid.apk
adb install -r android/build/TibiaDroid.apk
```

</details>

<details>
<summary><b>📁 Estrutura do repositório</b></summary>

<br>

| Pasta | Conteúdo |
|---|---|
| `android/` | app (Java), manifesto e scripts do runtime (`runtime/bin/*.sh`) |
| `tools/` | `tibia-fetch.py` (atualizador da CDN) e os builds do runtime, das libs e do APK |
| `proto/shim/` | libs de compatibilidade (threads do Qt no box64, seccomp, sockets) |
| `proto/device/` | protótipo rodando pelo `adb shell`, antes do APK |
| `proto/tests/` | testes e diagnósticos usados durante o port |
| `GUIA.md`, `PLANO.md` | tentativa anterior com Winlator (histórico; não funcionou) |

</details>

## 📜 Licenças de terceiros

O APK empacota componentes de terceiros com licenças próprias: box64 (MIT),
glibc e demais pacotes Debian (GPL/LGPL e outras), Mesa (MIT), virglrenderer
(MIT), ANGLE (BSD) e o loader do Termux:X11 (GPL-3.0). O cliente do Tibia e
seus arquivos pertencem à **CipSoft GmbH** e não fazem parte deste repositório.
