#!/bin/zsh
# Instala o build em /Applications/Trincano.app com ditto e abre.
# NUNCA sobrescreve uma release (Developer ID) com um build local/ad-hoc (ver scripts/install-policy.sh):
# nesse caso recusa e diz como testar o build (open build/.../Trincano.app) sem tocar no app instalado.
# Nunca fecha o Ice: se ele estiver aberto, só avisa (dois gerenciadores brigam pela barra).
# Variáveis (para teste em pasta temporária): TRINCANO_INSTALL_DIR (padrão /Applications; só no padrão o
# script fecha e abre o app) e TRINCANO_INSTALL_SRC (padrão: o build de build/).
set -euo pipefail
cd "${0:A:h}/.."
source scripts/install-policy.sh
CONFIG="${1:-Release}"
SRC="${TRINCANO_INSTALL_SRC:-build/Build/Products/$CONFIG/Trincano.app}"
DEST_DIR="${TRINCANO_INSTALL_DIR:-/Applications}"
DEST="$DEST_DIR/Trincano.app"
REAL=0; [[ "$DEST_DIR" == /Applications ]] && REAL=1
[[ -d "$SRC" ]] || { echo "Build não encontrado: rode scripts/build.sh primeiro"; exit 1; }

new_kind="$(sig_kind "$SRC")"
old_kind="$(sig_kind "$DEST")"
if ! install_allowed "$new_kind" "$old_kind"; then
  echo "RECUSADO: $DEST é uma release ($old_kind) e o build novo é '$new_kind'."
  echo "Sobrescrever misturaria assinaturas (o app não abre mais). Para testar este build sem tocar no app instalado:"
  echo "  open $SRC"
  exit 1
fi

if pgrep -x Ice >/dev/null; then
  echo "AVISO: o Ice está aberto. Feche-o (ou desinstale) antes de usar o Trincano; ele não foi fechado."
fi
(( REAL )) && { pkill -x Trincano 2>/dev/null && sleep 1 || true; }
# Cópia ao lado e troca por rename: se o ditto falhar, o app instalado continua intacto.
mkdir -p "$DEST_DIR"
TMP="$(mktemp -d "$DEST_DIR/.trincano-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ditto "$SRC" "$TMP/Trincano.app"
rm -rf "$DEST"
mv "$TMP/Trincano.app" "$DEST"
echo "Instalado em $DEST"
if (( REAL )); then
  if pgrep -x Ice >/dev/null; then
    echo "Não abri o Trincano porque o Ice está aberto. Quando o Ice for fechado: open $DEST"
  else
    open "$DEST"
  fi
fi
