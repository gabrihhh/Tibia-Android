# 📱 PLANO-APK — App Android que abre o Tibia (cliente Linux)

Mudança de rumo em 2026-11-01: o Winlator (cliente Windows) **foi testado e não
funcionou**. Novo objetivo: um **APK próprio** que, ao tocar no ícone, abre o
**cliente Linux oficial** direto, sem launcher e sem tela intermediária.

---

## O que descobrimos sobre o cliente Linux (análise feita em 2026-11-01)

- **Download:** `https://static.tibia.com/download/tibia.x64.tar.gz` (a CDN
  exige header `Referer`, como o pacote do AUR faz). Esse arquivo é **só o
  launcher** (Qt6, ~73 MB descompactado). Fica em `linux-client/`.
- **O jogo de verdade** é baixado pelo launcher a partir de:
  - `https://static.tibia.com/launcher/tibiametadata.json` → índice
  - `https://static.tibia.com/launcher/tibiaclient-linux-current/package.json`
    → lista com 1662 arquivos, `executable: bin/client`, versão `15.33.8791c6`
  - Cada arquivo é `<caminho>.lzma` = **32 bytes de cabeçalho + stream LZMA
    "alone"** (o campo de tamanho vem errado, então tem que decodificar como
    tamanho desconhecido). **Já decodificamos isso com sucesso.**
  - Os assets do jogo vêm de `assets-current/assets.json`.
- **`bin/client`**: ELF x86_64, 55 MB, glibc ≥ 2.34. Depende de Qt6
  (Quick, Qml, Widgets, Multimedia, **WebEngine/Chromium**, que vêm junto no
  pacote) e só de libc/libstdc++/libz do sistema.
- **Renderização:** o cliente tem `renderer_opengl` **e `renderer_vulkan`**
  (Qt RHI). 👉 Vulkan é ótimo pra nós: a Xclipse 540 tem Vulkan nativo, e não
  precisamos de OpenGL desktop (que o Android não tem).
- **Janela:** só os plugins Qt `xcb` (X11) e `wayland`, ou seja, precisamos de um
  servidor X (ou compositor Wayland) dentro do app.
- **BattlEye:** vem em `bin/BattlEye/BEClient.so` (x86_64, ofuscado). Existem
  mundos com e sem BattlEye.

---

## Arquitetura proposta do APK

```
┌──────────────── Tibia.apk ────────────────┐
│ Activity Kotlin (fullscreen, paisagem)    │
│   ├─ SurfaceView ← servidor X embutido     │  (base: Termux:X11 / "lorie")
│   └─ teclado/mouse físicos → eventos X     │
│                                            │
│ Runtime glibc arm64 (sem proot, sem root)  │
│   └─ box64 → executa bin/client (x86_64)   │
│        ├─ Qt6 do Tibia (emulado)           │
│        └─ libvulkan (wrapped pelo box64)   │
│             └─ bionic-vulkan-wrapper ──► driver Xclipse (Samsung)
│                                            │
│ Updater próprio em Kotlin                  │
│   └─ baixa/atualiza o cliente da CDN       │
│      oficial na 1ª execução (não           │
│      redistribuímos nada da CipSoft)       │
└────────────────────────────────────────────┘
```

- **Abrir o Tibia direto:** o próprio app faz o papel do launcher (confere
  `package.json.version`, baixa o que mudou e executa `bin/client`).
- **Plano B gráfico:** se Vulkan→Xclipse der problema, usar OpenGL por
  Zink ou por software (llvmpipe). O Tibia é 2D, então software pode ser
  aceitável em resolução menor.

---

## Riscos (em ordem de gravidade)

1. **BattlEye rodando sob box64.** Ele escaneia memória, e o dynarec do box64
   gera código em tempo de execução. Pode dar kick, recusar iniciar ou, no pior
   caso, ser visto como adulteração. **Começar só em mundo sem BattlEye**
   até sabermos como ele se comporta.
2. **QtWebEngine (Chromium) sob box64**: pesado e multiprocesso. Talvez
   precise de `--no-sandbox` / `--single-process` ou nem precise carregar
   (provavelmente é usado em notícias/loja).
3. **Apresentação Vulkan numa janela X dentro do Android**: é a parte mais
   difícil, a mesma que o Winlator resolve com código próprio.
4. **Desempenho**: tradução x86→ARM de um cliente Qt grande.

---

## Fases

- [x] **Marco 2026-11-01:** a tela de login do Tibia abre no tablet (box64 0.4.3, sem
      proot, Xvfb, render por software). Precisou da shim `proto/shim/libqtthreadfix.so`
      (carregada via `BOX64_LD_PRELOAD`), que corrige três incompatibilidades do box64:
      `%fs:0x10` ≠ `pthread_self()` (deadlock no QQmlThread), `_SC_THREAD_STACK_MIN`
      de ARM (CHECK do Chromium) e `/dev/shm` inexistente no Android.
      Chromium com `--single-process --no-zygote --no-sandbox --disable-gpu --in-process-gpu`.
      A imagem cinza/listrada era só do Xvfb de teste (o Mesa por software no Xvfb
      deste aparelho envia pixels de 3 bytes; até o glxgears nativo sai assim).
- [x] **Marco 2026-11-01 (2):** login do Tibia aparece **na tela do tablet**, com cores
      certas, usando o Termux:X11 como servidor X (`app_process` via adb com
      `TMPDIR=/tmp` para o socket abstrato `@/tmp/.X11-unix/X0`, `DISPLAY=:0`).
- [x] **Marco 2026-11-01 (3): login e entrada no jogo funcionando no tablet.** Correções
      que faltavam para isso, todas fora do proot:
      - DNS: cópia do `libc.so.6` com `/etc/resolv.conf` trocado por `/proc/self/cwd/r`
        (arquivo `r` em `opt/Tibia/bin`), em `glibc-fix/` no início do `LD_LIBRARY_PATH`.
      - Certificados: o Qt só lê caminhos fixos; a shim redireciona
        `/etc/pki/tls/certs/ca-bundle.crt` para `$TIBIA_CA_BUNDLE` (só ISRG Root X1/X2;
        o bundle completo derruba o cliente).
      - Fuso horário: `TZ` + `TZDIR` (sem eles o calendário de eventos entra em laço
        infinito em `QDate::addDays`, a tela "loading game files").
      - Cliente iniciado com `--package-is-up-to-date` (como o launcher oficial).
      - `assets.json.sha256` na raiz do cliente; sem ele o login vai com
        `assetversion` vazio e o servidor responde "client version is too old".
      Script: `proto/device/start-tibia.sh`.
      **Desempenho ruim:** o llvmpipe (render por software) usa ~8×40% de CPU; load ~20.
- [x] **Marco 2026-11-01 (4): render pela GPU.** virgl → ANGLE → Vulkan da Samsung:
      `virgl_test_server_android` (pacote `virglrenderer-android` do Termux, copiado para
      `$B/virgl` com os caminhos do ANGLE trocados no binário) + Mesa `virpipe` no cliente
      (`GALLIUM_DRIVER=virpipe`, `VTEST_SOCKET_NAME=@tibia-virgl`). Como o SELinux não deixa
      o usuário shell criar sockets em arquivo, `proto/shim/abstractsock.c` (bionic no
      servidor via `LD_PRELOAD`, glibc no cliente via `ld-linux --preload`) converte
      `@nome` em socket abstrato. CPU total caiu de ~360% para ~70%; OpenGL 2.1 basta.
      Ajustes rápidos ativos: X em 1600×1000, FPS 30, luzes e auto-screenshots desligados.
      (RADV direto não funciona: o kernel usa o driver `sgpu`, não `amdgpu`; a ponte
      bionic-vulkan-wrapper é bionic e não carrega no processo glibc.)
- [ ] **Fase 0 — prova no PC (sem tablet):** container Docker arm64 (qemu) +
      box64 + Xvfb + llvmpipe executando o `bin/client`. Valida se o box64
      roda o cliente e o Qt6. Lento, mas responde "é viável?".
- [ ] **Fase 1 — prova no tablet com ferramentas prontas:** Termux +
      Termux:X11 + glibc + box64 executando o cliente. Valida GPU e input reais.
- [ ] **Fase 2 — APK mínimo:** Activity + X server embutido + runtime + box64,
      com o cliente copiado manualmente.
- [ ] **Fase 3 — updater próprio** (download da CDN oficial) + ícone → abre direto.
- [ ] **Fase 4 — polimento:** Vulkan nativo, teclado e mouse, desempenho, BattlEye.

## Ambiente de build (PC)

Android SDK em `~/Android/Sdk` (build-tools 36, platform 36, NDK 27.3), JDK 17,
Docker, CMake e Ninja já instalados. Tablet ainda **não** conectado via adb.
