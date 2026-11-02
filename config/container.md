# Configurações recomendadas do container (Winlator)

Ao criar o container no Winlator (botão **+**), use estes valores como ponto de
partida. São as opções com maior chance de o Tibia abrir e rodar bem no
Galaxy Tab S10 FE (Exynos 1580 / Xclipse 540).

## Configuração inicial (comece por aqui)

| Opção | Valor | Por quê |
|---|---|---|
| **Screen size** | 1600×1000 | Boa nitidez sem pesar demais. Pode usar a resolução nativa do tablet. |
| **Graphics Driver** | **ExynosTools** | Único driver que faz a Xclipse 540 funcionar bem. |
| **DX Wrapper** | DXVK | Padrão; funciona com o ExynosTools. |
| **Box64 Preset** | Performance | Prioriza velocidade na tradução x86→ARM. |
| **Windows version** | Windows 10 | O cliente do Tibia pede Win 10+. |
| **CPU cores** | Todos | Deixe o Box64 usar todos os núcleos. |
| **RAM/DGpu** | Padrão | Não precisa mexer no começo. |

## Se der problema, ajuste nesta ordem

1. **Tela preta / não abre** → troque o **Graphics Driver** (outra versão do
   ExynosTools) ou mude **DX Wrapper** para **WineD3D**.
2. **Lento / travando** → baixe **Screen size** para 1280×800 e mantenha
   **Box64 Preset = Performance**.
3. **Fecha ao iniciar o jogo** → **Box64 Preset = Compatibility**.
4. **Mouse/clique estranho** → em **Input**, alterne **"Capture mouse"**.

## Notas sobre o Tibia especificamente

- O cliente atual do Tibia usa **OpenGL**. Às vezes **WineD3D** (que converte via
  OpenGL) vai tão bem ou melhor que DXVK — vale testar os dois.
- Dentro do **jogo** (Options → Graphics), limite o **FPS** e desligue efeitos de
  luz/partículas para ganhar fluidez.
- Deixe a resolução **do Tibia** igual ou menor que a **Screen size** do container.

> Estes são pontos de partida testáveis, não números mágicos. Vá ajustando de um
> em um e testando — anote o que funcionou pro seu aparelho.
