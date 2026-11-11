#!/usr/bin/env python3
"""Confere os PNGs do catálogo (docs/prints/ por padrão): assinatura PNG válida,
só os chunks IHDR, sRGB, IDAT e IEND (nada de eXIf, tEXt, iCCP etc.), IHDR
primeiro e IEND por último. Não confere o CONTEÚDO da imagem: o 05 (menu) é
capturado por região da tela e a imagem precisa ser aberta e conferida à mão.
Uso: python3 -I scripts/check-prints.py [pasta-ou-png ...]"""
import struct
import sys
import zlib
from pathlib import Path

PNG_SIG = b"\x89PNG\r\n\x1a\n"
ALLOWED = {b"IHDR", b"sRGB", b"IDAT", b"IEND"}


def chunks(path):
    data = path.read_bytes()
    if data[:8] != PNG_SIG:
        raise ValueError("assinatura PNG inválida")
    i, out = 8, []
    while i < len(data):
        if i + 12 > len(data):
            raise ValueError("chunk truncado")
        n, = struct.unpack(">I", data[i:i + 4])
        kind = data[i + 4:i + 8]
        body = data[i + 8:i + 8 + n]
        crc, = struct.unpack(">I", data[i + 8 + n:i + 12 + n])
        if zlib.crc32(kind + body) != crc:
            raise ValueError(f"CRC inválido em {kind.decode('latin1')}")
        out.append(kind)
        i += 12 + n
    return out


def check(path):
    kinds = chunks(path)
    extra = sorted({k.decode("latin1") for k in kinds if k not in ALLOWED})
    problems = []
    if extra:
        problems.append("chunks fora da lista: " + ", ".join(extra))
    if not kinds or kinds[0] != b"IHDR":
        problems.append("IHDR não é o primeiro chunk")
    if not kinds or kinds[-1] != b"IEND":
        problems.append("IEND não é o último chunk")
    return problems


def main(args):
    targets = []
    for a in args or ["docs/prints"]:
        p = Path(a)
        targets += sorted(p.glob("*.png")) if p.is_dir() else [p]
    if not targets:
        print("nenhum PNG encontrado")
        return 1
    failed = False
    for t in targets:
        try:
            problems = check(t)
        except (OSError, ValueError, struct.error) as e:
            problems = [str(e)]
        print(("FALHOU " if problems else "ok     ") + t.name + (": " + "; ".join(problems) if problems else ""))
        failed = failed or bool(problems)
    return 1 if failed else 0


sys.exit(main(sys.argv[1:]))
