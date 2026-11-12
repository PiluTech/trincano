#!/bin/zsh
# Gera e confere o appcast.xml de um .dmg já final (depois do grampo da notarização).
# Uso: scripts/appcast.sh <dmg> <app compilado> <pasta de saída> <tag vX.Y.Z>
# Chave EdDSA: SPARKLE_OP_REF (op://..., lida para arquivo temporário 600 e apagada ao sair) ou SPARKLE_KEY_FILE.
# Notas: docs/notas-da-versao/<versão>.html. Ferramentas: SPARKLE_BIN (padrão: build/SourcePackages).
set -euo pipefail
cd "${0:A:h}/.."
DMG="$1"; APP="$2"; OUT="$3"; TAG="$4"
die() { echo "ERRO: $*" >&2; exit 1; }

VERSION="${TAG#v}"
NOTES="docs/notas-da-versao/$VERSION.html"
[[ -f "$NOTES" ]] || die "faltam as notas da versão: $NOTES"
SPARKLE_BIN="${SPARKLE_BIN:-build/SourcePackages/artifacts/sparkle/Sparkle/bin}"
[[ -x "$SPARKLE_BIN/sign_update" ]] || die "sign_update não encontrado em $SPARKLE_BIN"

SPARKLE_KEYTMP=""
trap '[[ -n "$SPARKLE_KEYTMP" ]] && rm -f "$SPARKLE_KEYTMP"; true' EXIT
trap '[[ -n "$SPARKLE_KEYTMP" ]] && rm -f "$SPARKLE_KEYTMP"; exit 130' INT TERM
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
  spk_key="$SPARKLE_KEY_FILE"
else
  [[ -n "${SPARKLE_OP_REF:-}" ]] || die "defina SPARKLE_OP_REF (op://...) ou SPARKLE_KEY_FILE"
  umask 077
  SPARKLE_KEYTMP="$(mktemp -t trincano-sparkle)"
  chmod 600 "$SPARKLE_KEYTMP"
  op read "$SPARKLE_OP_REF" > "$SPARKLE_KEYTMP" || die "não consegui ler a chave do Sparkle no 1Password"
  spk_key="$SPARKLE_KEYTMP"
fi

python3 -I scripts/make-appcast.py --dmg "$DMG" --notes "$NOTES" --app-info "$APP/Contents/Info.plist" \
  --key-file "$spk_key" --sign-update "$SPARKLE_BIN/sign_update" --out "$OUT/appcast.xml"

# Assina o próprio feed (a assinatura vai embutida no XML; qualquer edição depois invalida) e confere.
"$SPARKLE_BIN/sign_update" --ed-key-file "$spk_key" "$OUT/appcast.xml" >/dev/null
"$SPARKLE_BIN/sign_update" --verify --ed-key-file "$spk_key" "$OUT/appcast.xml" >/dev/null \
  || die "a assinatura do feed não confere"

PUBKEY="$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$APP/Contents/Info.plist")"
BUILD_NUM="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")"
PREV_TAG="$(git tag --list 'v[0-9]*' --sort=-v:refname | grep -vx "$TAG" | head -n 1 || true)"
PREV_BUILD=0
[[ -n "$PREV_TAG" ]] && PREV_BUILD="$(git show "$PREV_TAG:Ice.xcodeproj/project.pbxproj" | grep CURRENT_PROJECT_VERSION | tr -dc '0-9\n' | sort -n | tail -n 1)"
echo "build anterior ($PREV_TAG): $PREV_BUILD; novo: $BUILD_NUM"
swiftc -o "$OUT/ed25519" scripts/ed25519.swift
trap_rm() { rm -f "$OUT/ed25519"; }
python3 -I scripts/check-appcast.py --appcast "$OUT/appcast.xml" --dmg "$DMG" --public-key "$PUBKEY" \
  --previous-build "$PREV_BUILD" --ed25519 "$OUT/ed25519" \
  --sign-update "$SPARKLE_BIN/sign_update" --key-file "$spk_key" || { trap_rm; exit 1; }
trap_rm
