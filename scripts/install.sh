#!/bin/zsh
# Instala o build em /Applications/Trincano.app.
# NUNCA sobrescreve uma release (Developer ID) com build local/ad-hoc, e recusa tudo que não consegue provar
# (ver scripts/install-policy.sh). A troca é por rename com backup e restauração: restaura em falha tratada;
# há uma janela entre os dois renames e uma interrupção abrupta (queda de energia, kill) pode exigir recuperar
# o backup em /Applications/.trincano-install.*/previous.app. Nunca fecha o Ice, só avisa.
# Variáveis (teste em pasta temporária): TRINCANO_INSTALL_DIR (padrão /Applications; só no padrão o script
# fecha e abre o app) e TRINCANO_INSTALL_SRC (padrão: o build de build/).
set -euo pipefail
cd "${0:A:h}/.."
source scripts/install-policy.sh
CONFIG="${1:-Release}"
SRC="${TRINCANO_INSTALL_SRC:-build/Build/Products/$CONFIG/Trincano.app}"
DEST_DIR="${TRINCANO_INSTALL_DIR:-/Applications}"
DEST="$DEST_DIR/Trincano.app"
REAL=0; [[ "$DEST_DIR" == /Applications ]] && REAL=1
[[ -d "$SRC" ]] || { echo "Build não encontrado: rode scripts/build.sh primeiro"; exit 1; }

refuse() {
  echo "RECUSADO: $1"
  echo "Para testar este build sem tocar no app instalado: open $SRC"
  exit 1
}

new_kind="$(sig_kind "$SRC")"
old_kind="$(sig_kind "$DEST")"
install_allowed "$new_kind" "$old_kind" \
  || refuse "build novo '$new_kind' sobre o instalado '$old_kind' em $DEST (só release da mesma equipe troca release; o que não se prova é recusado)"

if pgrep -x Ice >/dev/null; then
  echo "AVISO: o Ice está aberto. Feche-o (ou desinstale) antes de usar o Trincano; ele não foi fechado."
fi

mkdir -p "$DEST_DIR"
WORK="$(mktemp -d "$DEST_DIR/.trincano-install.XXXXXX")"
KEEP_WORK=0
trap '(( KEEP_WORK )) || rm -rf "$WORK"' EXIT
NEW="$WORK/Trincano.app"
BAK="$WORK/previous.app"

ditto "$SRC" "$NEW" || { echo "ERRO: ditto falhou; o app instalado não foi alterado."; exit 1; }
# A mesma verificação, agora na cópia pronta, e de novo no destino logo antes de trocar.
copy_kind="$(sig_kind "$NEW")"
[[ "$copy_kind" == "$new_kind" ]] || refuse "a cópia pronta ('$copy_kind') não bate com o build verificado ('$new_kind')"
old_now="$(sig_kind "$DEST")"
[[ "$old_now" == "$old_kind" ]] || refuse "o app instalado mudou durante a instalação ('$old_kind' -> '$old_now')"

(( REAL )) && { pkill -x Trincano 2>/dev/null && sleep 1 || true; }

# Troca: antigo para o backup, novo para o lugar; se o segundo passo falhar, restaura o backup.
if [[ -e "$DEST" || -L "$DEST" ]]; then
  mv "$DEST" "$BAK" || { echo "ERRO: não consegui guardar o app instalado; nada foi alterado."; exit 1; }
fi
if ! mv "$NEW" "$DEST"; then
  if [[ -e "$BAK" ]]; then
    if mv "$BAK" "$DEST"; then
      echo "ERRO: a troca falhou; o app anterior foi restaurado em $DEST."
    else
      KEEP_WORK=1
      echo "ERRO GRAVE: a troca e a restauração falharam; o app anterior está em $BAK (não apague)."
    fi
  else
    echo "ERRO: a troca falhou e não havia app anterior."
  fi
  exit 1
fi
rm -rf "$BAK"
echo "Instalado em $DEST"
if (( REAL )); then
  if pgrep -x Ice >/dev/null; then
    echo "Não abri o Trincano porque o Ice está aberto. Quando o Ice for fechado: open $DEST"
  else
    open "$DEST"
  fi
fi
