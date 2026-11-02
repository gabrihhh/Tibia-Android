# ExynosTools — driver de vídeo para a Xclipse 540

Este é o passo que faz a GPU do seu tablet (Xclipse 540, AMD RDNA 3) funcionar
dentro do Winlator. **Sem ele, provavelmente não roda.**

## Por que ExynosTools (e não Turnip)

- **Turnip** = driver Vulkan só para GPUs **Adreno** (Snapdragon). Não serve pra você.
- **ExynosTools** = driver Vulkan feito para GPUs **Xclipse** (Exynos).
  A release do projeto lista explicitamente a **Xclipse 540** como suportada. ✅

## Download oficial

- GitHub (releases): **https://github.com/WearyConcern1165/ExynosTools/releases**

Pegue a **release mais recente** que mencione a **Xclipse 540 / Exynos 1580**.
O arquivo costuma ser um `.wcp` (pacote de driver do Winlator) ou `.zip`.

## Como importar no Winlator

1. Baixe o arquivo do ExynosTools (deixe-o acessível no tablet).
2. Abra o **Winlator** → menu **☰** → **Settings** (ou **Contents / Drivers**,
   depende da versão).
3. Toque em **Import** e selecione o arquivo do ExynosTools.
4. Ao criar/editar o **container**, escolha o ExynosTools no campo
   **Graphics Driver** (veja `config/container.md`).

## Se não funcionar

- Teste **outra versão** do ExynosTools (release anterior ou mais nova).
- Teste em **outro fork** do Winlator (veja `winlator/README.md`).
- Alguns drivers precisam que a opção **DX Wrapper = DXVK** esteja ligada;
  outros vão melhor com **WineD3D**. Teste os dois.

> Observação: ExynosTools é um projeto da comunidade e **experimental**.
> Funciona sem root na maioria dos casos — confirme na página da release que
> você baixar.
