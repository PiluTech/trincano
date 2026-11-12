#!/usr/bin/env python3
"""Remove os chunks de metadados (eXIf, tEXt, iTXt, zTXt) de PNGs, no lugar.

Reescreve só a lista de chunks: os dados de imagem (IDAT) e os demais chunks
seguem byte a byte, sem decodificar nem reamostrar pixels.
Uso: strip-png-metadata.py arquivo.png [...]
"""
import struct
import sys

SIGNATURE = b"\x89PNG\r\n\x1a\n"
DROP = {b"eXIf", b"tEXt", b"iTXt", b"zTXt"}


def strip(path):
    data = open(path, "rb").read()
    if not data.startswith(SIGNATURE):
        raise SystemExit(f"{path}: não é PNG")
    out = [SIGNATURE]
    pos = len(SIGNATURE)
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        end = pos + 12 + length
        if data[pos + 4:pos + 8] not in DROP:
            out.append(data[pos:end])
        pos = end
    if pos != len(data):
        raise SystemExit(f"{path}: chunks truncados")
    open(path, "wb").write(b"".join(out))


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        strip(arg)
