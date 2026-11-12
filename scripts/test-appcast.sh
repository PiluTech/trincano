#!/bin/zsh
# Testa a geração e a checagem do appcast com um par de chaves descartável e um .dmg falso.
# Não usa a chave real nem rede. Casos: válido; .dmg adulterado; build não maior; script nas notas;
# assinatura de outra chave; XML quebrado.
set -euo pipefail
cd "${0:A:h}/.."
SPARKLE_BIN="${SPARKLE_BIN:-build/SourcePackages/artifacts/sparkle/Sparkle/bin}"
[[ -x "$SPARKLE_BIN/sign_update" ]] || SPARKLE_BIN="$(ls -d ~/Library/Developer/Xcode/DerivedData/Ice-*/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -n 1)"
[[ -x "$SPARKLE_BIN/sign_update" ]] || { echo "sign_update não encontrado (compile uma vez para o SPM baixar o Sparkle)"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
swiftc -o "$T/ed25519" scripts/ed25519.swift
head -c 4096 /dev/urandom > "$T/Trincano-9.9.9.dmg"
head -c 32 /dev/urandom | base64 > "$T/key"; chmod 600 "$T/key"
head -c 32 /dev/urandom | base64 > "$T/other-key"; chmod 600 "$T/other-key"
PUB="$("$T/ed25519" pub "$(cat "$T/key")")"
cat > "$T/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleShortVersionString</key><string>9.9.9</string>
<key>CFBundleVersion</key><string>9999</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PL
echo '<h2>Novidades</h2><ul><li>Teste</li></ul>' > "$T/notes.html"

gen() {  # chave notas saída
  python3 -I scripts/make-appcast.py --dmg "$T/Trincano-9.9.9.dmg" --notes "$2" --app-info "$T/Info.plist" \
    --key-file "$1" --sign-update "$SPARKLE_BIN/sign_update" --out "$3" >/dev/null
  "$SPARKLE_BIN/sign_update" --ed-key-file "$1" "$3" >/dev/null   # assina o feed, como o appcast.sh
}
check() {  # appcast build-anterior
  python3 -I scripts/check-appcast.py --appcast "$1" --dmg "$T/Trincano-9.9.9.dmg" --public-key "$PUB" \
    --previous-build "$2" --ed25519 "$T/ed25519" --sign-update "$SPARKLE_BIN/sign_update" --key-file "$T/key" >/dev/null 2>&1
}
expect_fail() { if "$@"; then echo "FALHOU: esperava recusa: $*"; exit 1; fi; }

gen "$T/key" "$T/notes.html" "$T/ok.xml"
check "$T/ok.xml" 9000 || { echo "FALHOU: appcast válido foi recusado"; exit 1; }
expect_fail check "$T/ok.xml" 9999          # build igual ao anterior
expect_fail check "$T/ok.xml" 10000         # build menor
gen "$T/other-key" "$T/notes.html" "$T/other.xml"
expect_fail check "$T/other.xml" 9000       # assinado por outra chave
echo '<p onclick="x()">oi</p>' > "$T/bad1.html"; gen "$T/key" "$T/bad1.html" "$T/bad1.xml"
expect_fail check "$T/bad1.xml" 9000
echo '<script>alert(1)</script>' > "$T/bad2.html"; gen "$T/key" "$T/bad2.html" "$T/bad2.xml"
expect_fail check "$T/bad2.xml" 9000
echo 'xx' > "$T/broken.xml"
expect_fail check "$T/broken.xml" 9000
cp "$T/Trincano-9.9.9.dmg" "$T/orig.dmg"; printf 'x' >> "$T/Trincano-9.9.9.dmg"
expect_fail check "$T/ok.xml" 9000          # .dmg alterado depois da assinatura
# Feed editado depois de assinado (mesmo com o .dmg e a assinatura do binário intactos).
cp "$T/orig.dmg" "$T/Trincano-9.9.9.dmg"
gen "$T/key" "$T/notes.html" "$T/edited.xml"
check "$T/edited.xml" 9000 || { echo "FALHOU: feed válido recusado"; exit 1; }
sed -i '' 's/Versão 9.9.9/Versão 9.9.8/' "$T/edited.xml"
expect_fail check "$T/edited.xml" 9000
# Feed sem assinatura embutida.
python3 -I scripts/make-appcast.py --dmg "$T/Trincano-9.9.9.dmg" --notes "$T/notes.html" --app-info "$T/Info.plist" \
  --key-file "$T/key" --sign-update "$SPARKLE_BIN/sign_update" --out "$T/unsigned.xml" >/dev/null
expect_fail check "$T/unsigned.xml" 9000
echo "test-appcast: OK (10 casos)"
