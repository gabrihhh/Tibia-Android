# 🎮 Tibia Portátil no Tablet — Galaxy Tab S10 FE

Guia para rodar o **Tibia original (cliente oficial)** de forma **nativa** no seu
tablet Android, usando teclado e mouse.

> **Seu tablet:** Samsung Galaxy Tab S10 FE
> **Chip:** Exynos 1580 · **GPU:** Xclipse 540 (AMD RDNA 3)
> **Abordagem:** Winlator (Wine + Box64) + driver **ExynosTools** + cliente **Windows** do Tibia

---

## ⚠️ Leia antes de começar (expectativas reais)

- O Tibia **não tem app oficial para Android**. O que fazemos aqui é rodar o
  cliente de **Windows** dentro do **Winlator**, que traduz x86→ARM e Windows→Linux.
- A GPU do seu tablet (**Xclipse 540**) **não** usa o driver Turnip (esse é só
  pra Snapdragon/Adreno). Por isso usamos o **ExynosTools**, feito pra Xclipse.
- **Não dá pra garantir 100%** que vai rodar liso — drivers de GPU em Android são
  imprevisíveis. O Tibia é 2D e leve, então as chances são boas, mas pode exigir
  ajuste fino. Este guia já parte das configurações com maior chance de sucesso.
- **Isso é legal e dentro das regras da CipSoft:** você está usando o cliente
  **oficial**, sem bot/automação. Só está rodando-o num ambiente diferente.

---

## 📋 Pré-requisitos

- Galaxy Tab S10 FE com **Android atualizado** e pelo menos **~15 GB livres**.
- **Teclado e mouse** (USB via adaptador OTG USB-C, ou Bluetooth).
- Uma conta do Tibia (grátis) — https://www.tibia.com
- Esta pasta `tibia-port` copiada pro tablet (ou baixe os arquivos direto nele).

---

## 🗺️ Visão geral (o que vamos fazer)

1. Instalar o app **Winlator** no tablet.
2. Importar o driver **ExynosTools** no Winlator.
3. Criar um **container** (Windows virtual) com as configs recomendadas.
4. Instalar o **cliente do Tibia** dentro do container.
5. Configurar **teclado e mouse**.
6. Abrir e jogar. Ajustes finos se precisar.
7. Criar o **atalho na tela inicial** → clicar no ícone e abrir o Tibia direto.

---

## 1️⃣ Instalar o Winlator

O Winlator é um APK (não está na Play Store). Baixe a versão mais recente.

- **Site/Repo oficial:** https://winlator.org  → seção *Download*
  (ou GitHub: https://github.com/brunodev85/winlator/releases)
- Baixe o **APK** mais recente e instale no tablet
  (vai pedir pra permitir "instalar de fontes desconhecidas" — permita).

> 💡 Existem "forks" do Winlator (Bionic, Cmod, Frost, etc.). Comece pelo
> **oficial**. Se der problema de driver/gráfico, veja a seção *Alternativas*.

Veja detalhes e o link escolhido em [`winlator/README.md`](winlator/README.md).

---

## 2️⃣ Importar o driver ExynosTools (o passo mais importante)

Sem isso, a GPU Xclipse não roda direito no Winlator.

1. Baixe o ExynosTools (arquivo de driver, geralmente `.wcp` ou `.zip`):
   - **GitHub oficial:** https://github.com/WearyConcern1165/ExynosTools/releases
   - Pegue a **release mais recente** que liste a **Xclipse 540** como suportada.
2. Abra o **Winlator** → menu (☰) → **Settings / Contents** (ou *Drivers*).
3. Use **Import** e selecione o arquivo do ExynosTools baixado.
4. O driver passa a aparecer na lista de drivers de vídeo do container (passo 3).

Veja o passo detalhado em [`driver/README.md`](driver/README.md).

---

## 3️⃣ Criar o container com as configs recomendadas

No Winlator, toque em **+** (novo container) e use estes valores
(explicados em [`config/container.md`](config/container.md)):

| Opção | Valor recomendado |
|---|---|
| **Screen size** | 1600×1000 (ou a resolução nativa do tablet) |
| **Graphics Driver** | **ExynosTools** (o que você importou no passo 2) |
| **DX Wrapper** | DXVK (padrão) |
| **Box64 Preset** | Performance |
| **Windows version** | Windows 10 |
| **CPU cores** | deixe todos |

Salve o container. (Pode ajustar depois, veja a seção de *Ajustes*.)

---

## 4️⃣ Instalar o cliente do Tibia dentro do container

Você precisa do **instalador do Tibia para Windows**.

### Opção A — baixar no PC e copiar (recomendado)
1. No seu **PC**, rode o script desta pasta:
   ```bash
   ./scripts/baixar-cliente.sh
   ```
   Ele te guia até o instalador oficial e o guarda em `client/`.
2. Copie o instalador pro tablet (cabo USB, Google Drive, etc.).

### Opção B — baixar direto no tablet
- Acesse https://www.tibia.com/account/?subtopic=downloadclient
  e baixe o cliente **Windows**.

### Instalar no Winlator
1. Abra o container (toque nele → **Run**).
2. No ambiente Windows do Winlator, abra o **gerenciador de arquivos** e
   navegue até o instalador do Tibia.
3. Execute o instalador normalmente (como faria no Windows).
4. Ao terminar, o **launcher do Tibia** abre e baixa os arquivos do jogo —
   isso precisa de internet e pode demorar na primeira vez.

> ℹ️ O launcher do Tibia faz auto-update. A primeira execução baixa vários MB.

---

## 5️⃣ Configurar teclado e mouse

- **USB:** conecte o adaptador **OTG USB-C** no tablet e plugue teclado/mouse.
  O Android reconhece sozinho; o Winlator repassa pro jogo.
- **Bluetooth:** pareie teclado e mouse em *Configurações → Bluetooth* do Android.
- No Winlator, dentro do container, confira:
  - **Input → Mouse:** ative o modo de **mouse** (cursor) em vez de touch.
  - Se o clique não funcionar, alterne entre **"Capture mouse"** on/off.
- Hotkeys do Tibia (F1..F12, setas, etc.) funcionam pelo teclado físico.

---

## 6️⃣ Abrir e jogar

1. Abra o container → o launcher do Tibia → **Login** com sua conta.
2. Entre no jogo. Ajuste a resolução **dentro do Tibia** (Options → Graphics)
   pra bater com a tela.
3. Bom jogo! 🗡️

---

## 7️⃣ Criar o atalho do Tibia na tela inicial (clicar e abrir direto)

Este é o passo que transforma tudo num **"app de Tibia"**: um ícone na tela
inicial do tablet que, ao tocar, **abre o Tibia direto** — pulando a tela do
Winlator. (Tem ~5–15s de boot do container na primeira tela; é o Wine subindo,
é normal.)

### Passo a passo

1. **Primeiro faça o Tibia abrir pelo menos uma vez** (passos 1 a 6). Só crie o
   atalho depois que você confirmou que o jogo abre no container.
2. Entre no container (**Run**) e abra o **gerenciador de arquivos** do Winlator.
3. Navegue até o executável do Tibia instalado. Normalmente em algo como:
   ```
   C:\Program Files\Tibia\bin\client.exe
   ```
   (o nome/caminho pode variar conforme a versão; procure o `.exe` principal que
   abre o jogo, não o instalador).
4. Faça **clique-direito** no `.exe`:
   - com **mouse**: CTRL + clique esquerdo;
   - com **toque**: toque com **dois dedos**.
5. Escolha **Create Shortcut** (Criar atalho).
6. Saia do container → menu **☰** → **Shortcuts**. O atalho do Tibia estará lá.
7. No atalho, use a opção **Add to Home Screen** (Adicionar à tela inicial).
   Agora tem um ícone do Tibia na home do tablet. ✅

### Deixar com cara de app de Tibia

- **Ícone:** ao criar/editar o atalho, troque o ícone pelo do Tibia.
  Guarde o arquivo do ícone em `client/` (veja `client/ICONE.md`) e selecione-o.
- **Configs por atalho:** cada atalho guarda suas próprias opções (Graphics
  Driver = ExynosTools, resolução, Box64). Ajuste ali as mesmas configs do
  `config/container.md`.

### Se o Tibia não abrir pelo atalho (mas abre pelo container)

Alguns jogos só sobem por um atalho separado, ou usam um launcher intermediário:

- Se o Tibia abre via **launcher** (ex: `launcher.exe`) e não direto pelo
  `client.exe`, crie o atalho apontando para o **launcher**.
- Se mesmo assim travar, edite o atalho e aponte o caminho para o outro `.exe`
  (teste `client.exe` vs `launcher.exe`).
- Garanta que o atalho usa o **mesmo Graphics Driver (ExynosTools)** do container.

> Resultado final: toca no ícone do Tibia na tela inicial → espera o boot →
> cai direto no login do Tibia. É o mais perto de um "executável do Tibia" que
> dá pra fazer sem violar os termos da CipSoft nem recompilar nada.

---

## 🔧 Ajustes se estiver lento ou com problema

Tente nesta ordem (um de cada vez, testando):

1. **Trocar a versão do ExynosTools** (release anterior ou mais nova).
2. No container: **DX Wrapper** → testar *WineD3D* em vez de DXVK
   (o Tibia usa OpenGL; às vezes WineD3D vai melhor).
3. **Baixar a resolução** do container (ex: 1280×800).
4. **Box64 Preset** → testar *Compatibility* se travar ao abrir.
5. Dentro do Tibia: desligar efeitos pesados (luz, partículas), limitar FPS.
6. Se a tela ficar preta/não abre → trocar o **Graphics Driver** ou testar um
   **fork do Winlator** (ver abaixo).

### Alternativas (se o Winlator oficial não cooperar)
- **Winlator Bionic / Cmod / Frost** — forks com drivers e tweaks diferentes,
  às vezes melhores pra Exynos. Mesmo fluxo deste guia.
- Última opção: **streaming do PC** (rodar o Tibia no PC Linux e espelhar pro
  tablet com Moonlight+Sunshine). Me avise que eu monto esse caminho também.

---

## ❓ Dúvidas comuns

- **"Vou ser banido?"** Não — é o cliente oficial, sem bot. Você só o roda em
  outro ambiente. Evite qualquer ferramenta de automação/cavebot (essas sim banem).
- **"Preciso de root?"** Não para o Winlator. O ExynosTools funciona como
  camada Vulkan sem root (confirme na página da release).
- **"Funciona offline?"** Não — Tibia é online, precisa de internet.
- **"Posso usar no S Pen / touch?"** Dá, mas o Tibia foi feito pra teclado+mouse;
  por isso o foco do kit é nesses periféricos.

---

## 📁 O que tem nesta pasta

```
tibia-port/
├── GUIA.md            ← você está aqui
├── client/            ← instalador do Tibia (Windows) vai aqui
├── winlator/README.md ← qual Winlator baixar
├── driver/README.md   ← como importar o ExynosTools
├── config/container.md← parâmetros recomendados do container
├── client/ICONE.md    ← onde pegar o ícone do Tibia p/ o atalho
└── scripts/
    └── baixar-cliente.sh  ← ajuda a baixar o cliente no PC
```

Veja também o [`PLANO.md`](PLANO.md) — as decisões de projeto e por que
escolhemos cada caminho.

---

*Guia montado para o caso específico do Galaxy Tab S10 FE (Exynos 1580 / Xclipse 540).
Links verificados em outubro/2026 — se algum mudar, me avise que eu atualizo.*
