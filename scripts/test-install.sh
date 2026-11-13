#!/bin/zsh
# Testa scripts/install.sh e a política em pasta temporária, com um `codesign` falso no PATH.
# Não toca em /Applications, no chaveiro nem no app instalado.
set -euo pipefail
cd "${0:A:h}/.."
source scripts/install-policy.sh
fail() { echo "FALHOU: $*"; exit 1; }

# Política pura.
for case in "adhoc absent" "local absent" "developer-id:T absent" "adhoc local" "local adhoc" "developer-id:T developer-id:T"; do
  install_allowed ${=case} || fail "esperava permitir: $case"
done
for case in "adhoc developer-id:T" "local developer-id:T" "developer-id:OUTRA developer-id:T"; do
  if install_allowed ${=case}; then fail "esperava recusar: $case"; fi
done

# install.sh de ponta a ponta, em pasta temporária.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/dest"
cat > "$T/bin/codesign" <<'STUB'
#!/bin/sh
# codesign falso: o "tipo" vem de um arquivo .kind dentro do bundle.
app="${@: -1}"; kind="$(cat "$app/.kind" 2>/dev/null || echo local)"
case "$kind" in
  adhoc) echo "Signature=adhoc" >&2 ;;
  developer-id:*) echo "Authority=Developer ID Application: Teste (${kind#developer-id:})" >&2; echo "TeamIdentifier=${kind#developer-id:}" >&2 ;;
  *) echo "Authority=Trincano Local Signing" >&2; echo "TeamIdentifier=not set" >&2 ;;
esac
STUB
chmod +x "$T/bin/codesign"
mk() { mkdir -p "$1/Contents"; echo "$2" > "$1/.kind"; echo "$3" > "$1/Contents/marker"; }
SRCAPP="$T/src/Trincano.app"; mkdir -p "$T/src"
run() { PATH="$T/bin:$PATH" TRINCANO_INSTALL_DIR="$T/dest" TRINCANO_INSTALL_SRC="$SRCAPP" scripts/install.sh >"$T/out" 2>&1; }

# 1) destino ausente: instala build local.
rm -rf "$SRCAPP" "$T/dest/Trincano.app"; mk "$SRCAPP" local novo
run || fail "instalar em destino vazio"; [[ "$(cat "$T/dest/Trincano.app/Contents/marker")" == novo ]] || fail "conteúdo"
# 2) release instalada + build local: RECUSA e mantém a release.
rm -rf "$T/dest/Trincano.app"; mk "$T/dest/Trincano.app" developer-id:TEAM1 release
rm -rf "$SRCAPP"; mk "$SRCAPP" local novo
if run; then fail "deveria recusar build local sobre release"; fi
[[ "$(cat "$T/dest/Trincano.app/Contents/marker")" == release ]] || fail "a release foi alterada"
grep -q RECUSADO "$T/out" || fail "sem mensagem de recusa"
# 3) idem com ad-hoc.
rm -rf "$SRCAPP"; mk "$SRCAPP" adhoc novo
if run; then fail "deveria recusar ad-hoc sobre release"; fi
[[ "$(cat "$T/dest/Trincano.app/Contents/marker")" == release ]] || fail "a release foi alterada (ad-hoc)"
# 4) release da mesma equipe substitui.
rm -rf "$SRCAPP"; mk "$SRCAPP" developer-id:TEAM1 nova-release
run || fail "release da mesma equipe deveria instalar"; [[ "$(cat "$T/dest/Trincano.app/Contents/marker")" == nova-release ]] || fail "troca da release"
# 5) build local sobre build local pode.
rm -rf "$T/dest/Trincano.app"; mk "$T/dest/Trincano.app" local velho
rm -rf "$SRCAPP"; mk "$SRCAPP" local novo
run || fail "local sobre local"; [[ "$(cat "$T/dest/Trincano.app/Contents/marker")" == novo ]] || fail "local sobre local (conteúdo)"
# 6) sem sobras do instalador na pasta.
ls -A "$T/dest" | grep -q '^\.trincano-install' && fail "sobrou pasta temporária"
echo "test-install: OK (política e install.sh, 6 casos)"
