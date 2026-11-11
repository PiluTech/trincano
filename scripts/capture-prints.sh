#!/bin/zsh
# Gera os prints do catálogo (docs/prints/) com a fixture do modo de captura.
# Só o build Debug tem o modo de captura (Ice/Utilities/CaptureFixture.swift).
# O build usa outro bundle id (br.com.pilutech.trincano.capture): não toca nas
# preferências do app instalado, nem o instala em /Applications.
# Uso: scripts/capture-prints.sh [pasta-de-saida]   (padrão: docs/prints)
set -euo pipefail
cd "${0:A:h}/.."
source scripts/signing.sh
resolve_signing
OUT="${1:-docs/prints}"
mkdir -p "$OUT"
OUT="${OUT:A}"

xcodebuild -project Ice.xcodeproj -scheme Ice -configuration Debug -derivedDataPath build \
  PRODUCT_BUNDLE_IDENTIFIER=br.com.pilutech.trincano.capture ENABLE_DEBUG_DYLIB=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" DEVELOPMENT_TEAM="" \
  "${SIGN_FLAGS[@]}" build | tail -1

# O binário direto, para a variável de ambiente chegar. Idioma: PT-BR.
TRINCANO_CAPTURE_DIR="$OUT" build/Build/Products/Debug/Trincano.app/Contents/MacOS/Trincano \
  -AppleLanguages '(pt-BR)' -AppleLocale pt_BR
ls -1 "$OUT"/*.png

# Tira qualquer bloco auxiliar do PNG (o ImageIO grava um eXIf com as dimensões):
# ficam só IHDR, sRGB, IDAT e IEND.
for f in "$OUT"/*.png; do
python3 -I - "$f" <<'PY'
import struct, sys
path = sys.argv[1]
data = open(path, "rb").read()
out, i = [data[:8]], 8
while i < len(data):
    n, = struct.unpack(">I", data[i:i + 4])
    if data[i + 4:i + 8] in (b"IHDR", b"sRGB", b"IDAT", b"IEND"):
        out.append(data[i:i + 12 + n])
    i += 12 + n
open(path, "wb").write(b"".join(out))
PY
done

python3 -I scripts/check-prints.py "$OUT"
