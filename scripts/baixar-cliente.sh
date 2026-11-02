#!/usr/bin/env bash
#
# baixar-cliente.sh — ajuda a obter o instalador OFICIAL do Tibia (Windows)
# e guarda em ../client/ para você copiar pro tablet.
#
# Observação: a CipSoft distribui o cliente pela página da conta, que pode exigir
# login e usa um launcher. Por isso o script abre a página oficial pra você baixar
# o instalador do Windows, e depois valida o arquivo que você salvar em client/.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/client"
URL_OFICIAL="https://www.tibia.com/account/?subtopic=downloadclient"

mkdir -p "$CLIENT_DIR"

echo "=============================================="
echo " Tibia Portátil — download do cliente (Windows)"
echo "=============================================="
echo
echo "1) Vou abrir a página OFICIAL de download do Tibia."
echo "   Baixe o cliente para WINDOWS (não o Linux/Mac)."
echo "   Salve o instalador dentro desta pasta:"
echo "     $CLIENT_DIR"
echo
echo "   Página: $URL_OFICIAL"
echo

# Tenta abrir no navegador padrão do PC Linux
if command -v xdg-open >/dev/null 2>&1; then
  read -rp "Abrir a página agora no navegador? [S/n] " resp
  case "${resp:-S}" in
    [Nn]*) echo "Ok, abra manualmente o link acima." ;;
    *) xdg-open "$URL_OFICIAL" >/dev/null 2>&1 || echo "Não consegui abrir; use o link acima." ;;
  esac
else
  echo "Abra o link acima no seu navegador."
fi

echo
echo "2) Depois de baixar, salve o instalador em: $CLIENT_DIR"
read -rp "Pressione ENTER quando o arquivo estiver em client/ ... " _

echo
echo "Arquivos encontrados em client/:"
if ls -lh "$CLIENT_DIR"/* >/dev/null 2>&1; then
  ls -lh "$CLIENT_DIR"
  echo
  echo "✅ Pronto. Agora copie a pasta 'client/' (ou só o instalador) pro tablet"
  echo "   e siga o GUIA.md a partir do passo 4."
else
  echo "⚠️  Nenhum arquivo em client/ ainda. Baixe o instalador do Windows e salve lá."
fi
