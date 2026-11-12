#!/usr/bin/env python3
"""Confere um appcast.xml do Trincano. Sai com erro se qualquer checagem falhar.

Uso: check-appcast.py --appcast A.xml --dmg X.dmg --public-key <base64> --previous-build N \
        [--repo PiluTech/trincano] [--ed25519 /caminho/do/binario]

Checa: XML válido; um item com https do repo na tag da versão; length = tamanho do .dmg;
assinatura EdDSA confere com a chave pública do Info.plist sobre os bytes do .dmg;
build novo > build anterior; versão curta coerente; notas sem script/atributos de evento.
"""
import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

NS = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
SP = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--appcast", required=True)
    ap.add_argument("--dmg", required=True)
    ap.add_argument("--public-key", required=True)
    ap.add_argument("--previous-build", type=int, required=True)
    ap.add_argument("--repo", default="PiluTech/trincano")
    ap.add_argument("--ed25519", required=True, help="binário compilado de scripts/ed25519.swift")
    ap.add_argument("--sign-update", required=True, help="sign_update do Sparkle (verifica a assinatura do feed)")
    ap.add_argument("--key-file", required=True, help="chave privada (só para o sign_update derivar a pública)")
    a = ap.parse_args()
    errors = []

    def check(cond, msg):
        if not cond:
            errors.append(msg)

    try:
        root = ET.parse(a.appcast).getroot()
    except ET.ParseError as e:
        sys.exit(f"appcast inválido (XML): {e}")
    raw = open(a.appcast, encoding="utf-8").read()
    check("sparkle-signatures" in raw, "feed sem assinatura embutida (sparkle-signatures)")
    feed_ok = subprocess.run([a.sign_update, "--verify", "--ed-key-file", a.key_file, a.appcast],
                             capture_output=True).returncode == 0
    check(feed_ok, "assinatura do FEED não confere (feed editado depois de assinado?)")
    items = root.findall("./channel/item")
    check(len(items) == 1, f"esperava 1 item, achei {len(items)}")
    if items:
        item = items[0]
        short = (item.findtext("sparkle:shortVersionString", namespaces=NS) or "").strip()
        build = (item.findtext("sparkle:version", namespaces=NS) or "").strip()
        enc = item.find("enclosure")
        check(enc is not None, "sem <enclosure>")
        check(bool(re.fullmatch(r"\d+\.\d+\.\d+", short)), f"versão curta fora de X.Y.Z: {short!r}")
        check(build.isdigit() and int(build) > a.previous_build,
              f"build {build!r} não é maior que o anterior ({a.previous_build})")
        if enc is not None:
            url = enc.get("url", "")
            check(url == f"https://github.com/{a.repo}/releases/download/v{short}/{os.path.basename(a.dmg)}",
                  f"URL do binário inesperada: {url}")
            check(url.startswith("https://"), "URL do binário não é https")
            check(enc.get("length") == str(os.path.getsize(a.dmg)), "length não bate com o tamanho do .dmg")
            sig = enc.get(SP + "edSignature", "")
            check(bool(sig), "sem sparkle:edSignature")
            if sig:
                ok = subprocess.run([a.ed25519, "verify", a.public_key, sig, a.dmg]).returncode == 0
                check(ok, "assinatura EdDSA NÃO confere com a chave pública")
        notes = item.findtext("description") or ""
        check(bool(notes.strip()), "notas da versão vazias")
        check(not re.search(r"<\s*script", notes, re.I), "notas com <script")
        check(not re.search(r"\son\w+\s*=", notes, re.I), "notas com atributo de evento (on*=)")
        check(not re.search(r"javascript:", notes, re.I), "notas com javascript:")
        check(not re.search(r"(src|href)\s*=\s*[\"']http://", notes, re.I), "notas com recurso http (sem TLS)")
    if errors:
        for e in errors:
            print("FALHA:", e, file=sys.stderr)
        sys.exit(1)
    print("appcast OK")


if __name__ == "__main__":
    main()
