#!/bin/zsh
# Gera o .dmg do Trincano assinado com Developer ID, notarizado e grampeado (distribuição fora da App Store).
#
# Uso: scripts/release.sh            (compila, assina, notariza, grampeia e verifica)
#      SKIP_BUILD=1 scripts/release.sh   (reaproveita build/Build/Products/Release/Trincano.app)
#      SKIP_NOTARIZE=1 scripts/release.sh (só assina e monta o .dmg; NÃO serve para distribuir)
#
# Variáveis (nenhum segredo fica no repo):
#   DEVELOPER_ID       identidade "Developer ID Application: ... (TEAMID)"; padrão: a única do keychain
#   NOTARY_KEY_ID      Key ID da chave da App Store Connect API
#   NOTARY_ISSUER      Issuer ID da chave
#   NOTARY_OP_REF      referência op:// do .p8 no 1Password (lido na hora; o arquivo temporário
#                      fica com chmod 600 e é apagado ao sair, mesmo em erro)
#   NOTARY_KEY_FILE    alternativa ao 1Password: caminho de um .p8 já existente (não é apagado)
#   SPARKLE_OP_REF     op://... da chave EdDSA do Sparkle (item "Trincano: chave Sparkle (EdDSA)", cofre
#                      Personal; use o ID do item na referência). Lida para arquivo temporário 600, apagado ao sair
#   SPARKLE_KEY_FILE   alternativa: caminho de um arquivo com a chave (não é apagado)
#   SPARKLE_BIN        pasta das ferramentas do Sparkle (padrão: a do SPM em build/SourcePackages)
# Notas da versão (pt-BR, HTML curto, sem script): docs/notas-da-versao/<versão>.html (obrigatório)
# Saída: build/release/Trincano-<versão>.dmg e build/release/appcast.xml (só com notarização;
#        o upload na release do GitHub é manual)
set -euo pipefail
cd "${0:A:h}/.."

APP_NAME="Trincano"
CONFIG="Release"
APP="build/Build/Products/$CONFIG/$APP_NAME.app"
XPC_REL="Contents/XPCServices"
OUT="build/release"
SLOT="${BUILD_SLOT:-$HOME/.maestri-local/build-slot.sh}"

die() { echo "ERRO: $*" >&2; exit 1; }

# --- Identidade ---------------------------------------------------------------
if [[ -z "${DEVELOPER_ID:-}" ]]; then
  ids=("${(@f)$(security find-identity -v -p codesigning | grep 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/' | sort -u)}")
  [[ ${#ids[@]} -eq 1 && -n "${ids[1]}" ]] || die "defina DEVELOPER_ID (achei ${#ids[@]} identidades Developer ID Application)"
  DEVELOPER_ID="${ids[1]}"
fi
echo "Assinando com: $DEVELOPER_ID"

# --- Build --------------------------------------------------------------------
if [[ -z "${SKIP_BUILD:-}" ]]; then
  rm -rf "build/Build/Products/$CONFIG"
  runner=()
  [[ -x "$SLOT" ]] && runner=("$SLOT")
  "${runner[@]}" xcodebuild -project Ice.xcodeproj -scheme Ice -configuration "$CONFIG" \
    -derivedDataPath build CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="" build | tail -n 5
fi
[[ -d "$APP" ]] || die "build não encontrado: $APP"

# --- Assinatura de dentro para fora (sem --deep), runtime reforçado, sem entitlements ---
sign() { codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" "$@"; }
# Sparkle aninhado, na ordem da documentação dele (do mais interno para o framework).
SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
[[ -d "$SPK" ]] || die "Sparkle.framework não está dentro do app ($SPK)"
for part in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
  [[ -e "$SPK/$part" ]] || continue
  if [[ "$part" == *Downloader.xpc ]]; then sign --preserve-metadata=entitlements "$SPK/$part"; else sign "$SPK/$part"; fi
done
sign "$APP/Contents/Frameworks/Sparkle.framework"
for xpc in "$APP/$XPC_REL"/*.xpc(N); do sign "$xpc"; done
sign "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
flags="$(codesign -d --verbose=2 "$APP" 2>&1 | grep -E '^CodeDirectory' )"
[[ "$flags" == *runtime* ]] || die "runtime reforçado ausente no app: $flags"
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'get-task-allow'; then
  die "get-task-allow presente (build de debug?); notarização recusaria"
fi
codesign -d -r- "$APP" 2>&1 | grep designated

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$VERSION" == *-dev* ]] && die "versão de release não pode ter -dev (atual: $VERSION); ajuste MARKETING_VERSION"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || die "versão fora do formato X.Y.Z: $VERSION"
[[ -n "${SKIP_NOTARIZE:-}" || -f "docs/notas-da-versao/$VERSION.html" ]] \
  || die "faltam as notas da versão: docs/notas-da-versao/$VERSION.html"
if [[ -n "$(git status --porcelain --untracked-files=no)" && -z "${ALLOW_DIRTY:-}" ]]; then
  die "working tree com mudanças: faça commit antes (o binário precisa corresponder a um commit)"
fi
COMMIT="$(git rev-parse HEAD)"
TAG="v$VERSION"
[[ "$(git rev-parse -q --verify "refs/tags/$TAG^{commit}" || true)" == "$COMMIT" ]] \
  || die "a tag $TAG precisa existir e apontar para o HEAD ($COMMIT); crie a tag antes do release"
SHORT="$(git rev-parse --short HEAD)"
DMG="$OUT/$APP_NAME-$VERSION.dmg"
rm -rf "$OUT"; mkdir -p "$OUT"

# --- Notarização ----------------------------------------------------------------
KEYTMP=""
cleanup() { [[ -n "$KEYTMP" ]] && rm -f "$KEYTMP"; return 0; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

notary_args=()
prepare_notary() {
  [[ -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER:-}" ]] || die "defina NOTARY_KEY_ID e NOTARY_ISSUER"
  local keyfile
  if [[ -n "${NOTARY_KEY_FILE:-}" ]]; then
    keyfile="$NOTARY_KEY_FILE"
  else
    [[ -n "${NOTARY_OP_REF:-}" ]] || die "defina NOTARY_OP_REF (op://...) ou NOTARY_KEY_FILE"
    umask 077
    KEYTMP="$(mktemp -t trincano-notary)"
    chmod 600 "$KEYTMP"
    op read "$NOTARY_OP_REF" > "$KEYTMP" || die "não consegui ler a chave no 1Password"
    keyfile="$KEYTMP"
  fi
  notary_args=(--key "$keyfile" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
}

notarize() {  # $1 = arquivo (.zip ou .dmg)
  local log; log="$(mktemp -t trincano-notary-log)"
  if ! xcrun notarytool submit "$1" "${notary_args[@]}" --wait 2>&1 | tee "$log"; then
    :
  fi
  grep -q 'status: Accepted' "$log" || { local id; id="$(awk '/id:/{print $2; exit}' "$log")"
    [[ -n "$id" ]] && xcrun notarytool log "$id" "${notary_args[@]}" 2>&1 | head -n 60
    rm -f "$log"; die "notarização não aceita para $1"; }
  rm -f "$log"
}

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
  prepare_notary
  ZIP="$OUT/$APP_NAME-notarize.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  notarize "$ZIP"
  rm -f "$ZIP"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

# --- DMG: app + atalho Applications + LICENSE + créditos, janela arrumada ------------------
# Janela 660x460, ícones de 100 pt: app à esquerda, Aplicativos à direita, fundo com a seta
# (Resources/dmg/background*.png, gerado por scripts/make-dmg-background.swift; as posições abaixo
# precisam bater com as do gerador). AppleScript no Finder: sem ferramenta de terceiros.
make_dmg() {  # $1 = pasta com o conteúdo, $2 = .dmg final
  local stage="$1" final="$2" rw="$OUT/rw.dmg" mnt="/Volumes/$APP_NAME" dev
  [[ ! -e "$mnt" ]] || die "já existe um volume montado em $mnt; ejete-o antes"
  mkdir -p "$stage/.background"
  tiffutil -cathidpicheck Resources/dmg/background.png Resources/dmg/background@2x.png \
    -out "$stage/.background/background.tiff" >/dev/null
  hdiutil create -volname "$APP_NAME" -srcfolder "$stage" -ov -format UDRW -fs HFS+ "$rw" >/dev/null
  dev="$(hdiutil attach "$rw" -readwrite -noverify -noautoopen | awk '/Apple_HFS/{print $1; exit}')"
  [[ -n "$dev" ]] || die "não consegui montar o .dmg de trabalho"
  if ! osascript <<OSA
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 640}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 100
    set text size of opts to 12
    set background picture of opts to file ".background:background.tiff"
    set position of item "$APP_NAME.app" of container window to {170, 190}
    set position of item "Applications" of container window to {490, 190}
    set position of item "LICENSE" of container window to {170, 370}
    set position of item "LEIA-ME.txt" of container window to {490, 370}
    close
    open
    update without registering applications
    delay 4
    close
  end tell
end tell
OSA
  then
    hdiutil detach "$dev" -force >/dev/null 2>&1 || true
    die "o Finder recusou o AppleScript do layout (permita Automação > Finder para este terminal)"
  fi
  sync; sleep 3
  [[ -f "$mnt/.DS_Store" ]] || { hdiutil detach "$dev" -force >/dev/null 2>&1 || true; die "layout não gravou o .DS_Store"; }
  chmod -Rf go-w "$mnt" 2>/dev/null || true
  for _ in 1 2 3 4 5; do hdiutil detach "$dev" >/dev/null 2>&1 && break; sleep 2; done
  hdiutil convert "$rw" -format UDZO -imagekey zlib-level=9 -o "$final" >/dev/null
  rm -f "$rw"
}

STAGE="$OUT/stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE"
cat > "$STAGE/LEIA-ME.txt" <<TXT
Trincano $VERSION

Gerenciador da barra de menus do macOS, fork do Ice (https://github.com/jordanbaird/Ice),
de Jordan Baird, licenciado sob a GNU GPL v3 (arquivo LICENSE neste disco).
Trincano: https://github.com/PiluTech/trincano. Código-fonte aberto, mesma licença.

Para instalar, arraste o Trincano para a pasta Applications.
Sem telemetria. O Trincano só acessa a internet para procurar atualizações, e só se você permitir.

Versão $VERSION · código: https://github.com/PiluTech/trincano/tree/$TAG (commit $SHORT)

Permissões: ao instalar o Trincano pela primeira vez (ou trocando a assinatura), conceda
Acessibilidade e Gravação de Tela de novo em Ajustes do Sistema > Privacidade e Segurança.
TXT
make_dmg "$STAGE" "$DMG"
rm -rf "$STAGE"
sign "$DMG"

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
  notarize "$DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "--- spctl (dmg)"
  spctl -a -vv -t open --context context:primary-signature "$DMG"
  echo "--- spctl (app dentro do dmg)"
  MNT="$(mktemp -d)"
  hdiutil attach "$DMG" -mountpoint "$MNT" -nobrowse -readonly >/dev/null
  spctl -a -vv -t exec "$MNT/$APP_NAME.app" || { hdiutil detach "$MNT" >/dev/null; die "spctl recusou o app"; }
  codesign --verify --deep --strict "$MNT/$APP_NAME.app"
  hdiutil detach "$MNT" >/dev/null
else
  echo "AVISO: SKIP_NOTARIZE ativo; este .dmg não está notarizado."
fi
if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
  # Appcast do Sparkle: assina o .dmg FINAL (o stapler mudou os bytes) e confere tudo.
  scripts/appcast.sh "$DMG" "$APP" "$OUT" "$TAG"
else
  echo "AVISO: SKIP_NOTARIZE ativo; sem appcast (o appcast só sai de um .dmg notarizado)."
fi
printf 'Trincano %s\ncommit: %s\n%s\nsha256: %s\n' "$VERSION" "$COMMIT" "tag $TAG" "$(shasum -a 256 "$DMG" | cut -d' ' -f1)" > "$DMG.source.txt"
echo "OK: $DMG"
