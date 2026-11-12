#!/usr/bin/env python3
"""Gera o appcast.xml (um item, a versão nova) para o Sparkle.

Uso: make-appcast.py --dmg X.dmg --notes notas.html --app-info Info.plist \
        --key-file chave --sign-update /caminho/sign_update --out appcast.xml [--repo PiluTech/trincano]

A assinatura EdDSA sai do .dmg FINAL (depois do grampo da notarização): o stapler
muda os bytes do arquivo. A chave privada vem de um arquivo (nunca de argumento).
"""
import argparse
import email.utils
import os
import plistlib
import subprocess
import sys
from xml.sax.saxutils import escape


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dmg", required=True)
    ap.add_argument("--notes", required=True)
    ap.add_argument("--app-info", required=True, help="Info.plist do app já compilado")
    ap.add_argument("--key-file", required=True)
    ap.add_argument("--sign-update", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--repo", default="PiluTech/trincano")
    a = ap.parse_args()

    info = plistlib.load(open(a.app_info, "rb"))
    short = info["CFBundleShortVersionString"]
    build = info["CFBundleVersion"]
    min_os = info.get("LSMinimumSystemVersion", "14.0")
    size = os.path.getsize(a.dmg)
    sig = subprocess.run([a.sign_update, "--ed-key-file", a.key_file, "-p", a.dmg],
                         check=True, capture_output=True, text=True).stdout.strip()
    notes = open(a.notes, encoding="utf-8").read().strip()
    if "]]>" in notes:
        sys.exit("notas não podem conter ']]>'")
    url = f"https://github.com/{a.repo}/releases/download/v{short}/{os.path.basename(a.dmg)}"
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Trincano</title>
    <item>
      <title>Versão {escape(short)}</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(short)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{escape(min_os)}</sparkle:minimumSystemVersion>
      <description><![CDATA[{notes}]]></description>
      <enclosure url="{escape(url)}" length="{size}" type="application/x-apple-diskimage" sparkle:edSignature="{escape(sig)}"/>
    </item>
  </channel>
</rss>
"""
    open(a.out, "w", encoding="utf-8").write(xml)
    print(f"appcast: {a.out} (versão {short}, build {build}, {size} bytes)")


if __name__ == "__main__":
    main()
