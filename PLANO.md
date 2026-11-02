# 📐 PLANO — Tibia Portátil no Tablet

Decisões de projeto e o raciocínio por trás delas. Serve de referência pra não
reabrir discussões já resolvidas e pra retomar o projeto depois.

---

## Objetivo

Jogar o **Tibia original (cliente oficial)** de forma **nativa** no tablet
**Galaxy Tab S10 FE**, usando **teclado e mouse**, com a experiência de
**"clicar num ícone e abrir o Tibia direto"**.

## Hardware alvo (fixo)

- **Tablet:** Samsung Galaxy Tab S10 FE
- **Chip:** Exynos 1580 (ARM, 4nm)
- **GPU:** Xclipse 540 (AMD RDNA 3) — **não é Adreno nem Mali**

---

## Decisões tomadas

### 1. Abordagem geral: nativo via Winlator (Abordagem A)
- **Escolhido:** Winlator (Wine + Box64) rodando o **cliente Windows** do Tibia.
- **Rejeitado — Streaming do PC:** funciona bem, mas exige PC ligado + rede boa;
  o usuário quer jogar no tablet de forma independente. Fica como **plano B**.
- **Rejeitado — Container Linux (Termux/proot/Box64 + cliente Linux):** muito
  mais frágil (servidor X, OpenGL→Vulkan manual) pra pouca vantagem.

### 2. Driver de vídeo: ExynosTools
- **Escolhido:** ExynosTools (driver Vulkan p/ GPUs Xclipse, RDNA-based).
  Confirmado que suporta a **Xclipse 540**.
- **Rejeitado — Turnip:** é exclusivo de GPUs **Adreno** (Snapdragon); não roda
  na Xclipse.
- Fonte: https://github.com/WearyConcern1165/ExynosTools

### 3. "Executável só do Tibia": Nível 1 (atalho na tela inicial)
Três níveis avaliados:

| Nível | O que é | Veredito |
|---|---|---|
| **1 — Atalho na home** | Winlator cria ícone do Tibia na tela inicial; toca e abre direto | ✅ **ESCOLHIDO** — entrega 95% da sensação de app, ~2 min, zero problema legal |
| 2 — APK wrapper | APK/Tasker que chama o atalho do Winlator por intent | ❌ ganho cosmético, não compensa |
| 3 — APK único autocontido | Forkar Winlator e embutir container + cliente num `Tibia.apk` | ❌ pesado, quebra a cada update do Tibia, e **redistribuir o cliente viola os termos da CipSoft** |

- O **Nível 1** é o foco atual do kit.
- O **Nível 3** fica documentado só como referência de "por que não".

---

## Restrições / regras

- **Legalidade:** usar o cliente **oficial** sem bot/automação é permitido. O
  usuário baixa o cliente ele mesmo (não redistribuímos). Nada de cavebot/macro.
- **Limite do ambiente:** este kit é montado num **PC Linux sem acesso ao
  tablet** — não é possível testar a execução no aparelho daqui. Entregamos um
  kit + guia testável; a validação final é no tablet, com suporte passo a passo.
- **Versões voláteis:** Winlator e ExynosTools mudam de release com frequência;
  o guia aponta os repositórios oficiais em vez de fixar um binário.

---

## Estado atual

- [x] Estrutura do kit criada
- [x] Guia passo a passo (`GUIA.md`) — Winlator, driver, container, cliente, input
- [x] **Nível 1 — atalho na tela inicial** documentado no `GUIA.md`
- [x] Config do container (`config/container.md`)
- [x] Script de download do cliente (`scripts/baixar-cliente.sh`)
- [ ] Baixar o instalador do Tibia para `client/` (quando o usuário quiser)
- [x] Testado no tablet — **não funcionou** (2026-11-01). Projeto migrou para o APK próprio, ver `PLANO-APK.md`
- [ ] (Opcional) Plano B de streaming, se o nativo não cooperar

---

## Próximos passos possíveis

1. Rodar `scripts/baixar-cliente.sh` para deixar o instalador em `client/`.
2. Executar o `GUIA.md` no tablet e me chamar nos pontos de travamento.
3. Se o Winlator oficial não for bem no Exynos, testar um fork (Bionic/Cmod/Frost).
4. Se nada do nativo funcionar, montar o **plano B (streaming Moonlight+Sunshine)**.
