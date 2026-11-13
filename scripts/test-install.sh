#!/bin/zsh
# Testa a política e o scripts/install.sh em pasta temporária, com `codesign`, `mv` e `ditto` falsos no PATH.
# Não toca em /Applications, no chaveiro nem no app instalado.
set -euo pipefail
cd "${0:A:h}/.."
source scripts/install-policy.sh
fail() { echo "FALHOU: $*"; [[ -f "${T:-/nonexistent}/out" ]] && sed "s/^/  | /" "$T/out"; exit 1; }

# --- política pura ----------------------------------------------------------------------------------------
REL="developer-id:$TRINCANO_TEAM_ID"
for c in "adhoc absent" "local absent" "$REL absent" "adhoc local" "local adhoc" "local local" "$REL $REL"; do
  install_allowed ${=c} || fail "esperava permitir: $c"
done
for c in "adhoc $REL" "local $REL" "developer-id:OUTRA $REL" "unknown absent" "unknown local" "local unknown" "$REL unknown" "absent local"; do
  if install_allowed ${=c}; then fail "esperava recusar: $c"; fi
done

# --- install.sh de ponta a ponta ---------------------------------------------------------------------------
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/dest" "$T/src"
cat > "$T/bin/codesign" <<'STUB'
#!/bin/sh
# codesign falso: o "modo" vem do arquivo .sigmode dentro do bundle (último argumento).
for last; do :; done; app="$last"
mode="$(cat "$app/.sigmode" 2>/dev/null || echo error)"
verify=0; req=""
for a in "$@"; do case "$a" in --verify) verify=1 ;; -R=*) req="${a#-R=}" ;; esac; done
if [ "$verify" = 1 ]; then
  case "$mode" in invalid|error) exit 1 ;; fakeauth) [ -z "$req" ] || exit 3 ;; esac
  if [ -n "$req" ]; then
    case "$mode" in release) case "$req" in *'"WU7Z54BRYQ"'*) ;; *) exit 3 ;; esac ;; *) exit 3 ;; esac
  fi
  exit 0
fi
case "$mode" in
  error) echo "code object is not signed at all" >&2; exit 1 ;;
  empty) exit 0 ;;
  malformed) echo "isto não é saída do codesign" >&2; exit 0 ;;
  adhoc) printf 'Identifier=x\nSignature=adhoc\nTeamIdentifier=not set\n' >&2 ;;
  local) printf 'Identifier=x\nAuthority=Trincano Local Signing\nTeamIdentifier=not set\n' >&2 ;;
  teamless) printf 'Identifier=x\nAuthority=Developer ID Application: Teste (X)\nTeamIdentifier=not set\n' >&2 ;;
  multiteam) printf 'Identifier=x\nAuthority=Developer ID Application: Teste (X)\nTeamIdentifier=WU7Z54BRYQ\nTeamIdentifier=OUTRA\n' >&2 ;;
  otherteam) printf 'Identifier=x\nAuthority=Developer ID Application: Teste (OUTRA)\nTeamIdentifier=OUTRA\n' >&2 ;;
  release|fakeauth|invalid) printf 'Identifier=x\nAuthority=Developer ID Application: Teste (WU7Z54BRYQ)\nTeamIdentifier=WU7Z54BRYQ\n' >&2 ;;
esac
exit 0
STUB
cat > "$T/bin/mv" <<'STUB'
#!/bin/sh
# mv falso: falha ao mover PARA o destino (MV_FAIL=new: só o app novo; MV_FAIL=all: o novo e a restauração).
for last; do :; done
if [ "$last" = "${MV_DEST:-}" ]; then
  case "${MV_FAIL:-}" in
    all) exit 1 ;;
    new) case "$1" in *previous.app) ;; *) exit 1 ;; esac ;;
  esac
fi
exec /bin/mv "$@"
STUB
cat > "$T/bin/ditto" <<'STUB'
#!/bin/sh
[ -z "${DITTO_FAIL:-}" ] || exit 1
exec /usr/bin/ditto "$@"
STUB
chmod +x "$T/bin/codesign" "$T/bin/mv" "$T/bin/ditto"

SRCAPP="$T/src/Trincano.app"; DESTAPP="$T/dest/Trincano.app"
mk() { rm -rf "$1"; mkdir -p "$1/Contents"; echo "$2" > "$1/.sigmode"; echo "$3" > "$1/Contents/marker"; }
marker() { cat "$DESTAPP/Contents/marker" 2>/dev/null || echo AUSENTE; }
run() { PATH="$T/bin:$PATH" TRINCANO_INSTALL_DIR="$T/dest" TRINCANO_INSTALL_SRC="$SRCAPP" MV_DEST="$DESTAPP" scripts/install.sh >"$T/out" 2>&1; }
no_leftovers() { ls -A "$T/dest" | grep -q '^\.trincano-install' && fail "sobrou pasta temporária ($1)"; return 0; }
expect_refused() {  # descrição, marcador esperado no destino depois
  if run; then fail "deveria recusar: $1"; fi
  [[ "$(marker)" == "$2" ]] || fail "destino alterado ($1): $(marker)"
  grep -q 'RECUSADO' "$T/out" || fail "sem mensagem RECUSADO ($1)"
  no_leftovers "$1"
}

# 1) destino ausente: instala build local.
rm -rf "$DESTAPP"; mk "$SRCAPP" local novo
run || fail "instalar em destino vazio"; [[ "$(marker)" == novo ]] || fail "conteúdo"; no_leftovers vazio
# 2) release + build local/ad-hoc: recusa e mantém a release.
mk "$DESTAPP" release release; mk "$SRCAPP" local novo; expect_refused "local sobre release" release
mk "$SRCAPP" adhoc novo; expect_refused "ad-hoc sobre release" release
# 3) release da mesma equipe substitui.
mk "$SRCAPP" release nova-release
run || fail "release sobre release"; [[ "$(marker)" == nova-release ]] || fail "troca da release"; no_leftovers release
# 4) local sobre local e sobre ad-hoc.
mk "$DESTAPP" local velho; mk "$SRCAPP" local novo; run || fail "local sobre local"; [[ "$(marker)" == novo ]] || fail "local sobre local (conteúdo)"
mk "$DESTAPP" adhoc velho; mk "$SRCAPP" local novo; run || fail "local sobre ad-hoc"; [[ "$(marker)" == novo ]] || fail "local sobre ad-hoc (conteúdo)"
# 5) destino com estado desconhecido: erro do codesign, saída vazia, malformada, assinatura inválida,
#    Developer ID sem prova (requisito falha), sem TeamIdentifier, vários TeamIdentifier, outra equipe.
mk "$SRCAPP" local novo
for bad in error empty malformed invalid fakeauth teamless multiteam otherteam; do
  mk "$DESTAPP" "$bad" velho; expect_refused "destino $bad" velho
done
# destino que é link simbólico (mesmo apontando para uma release).
rm -rf "$DESTAPP"; mk "$T/real.app" release release; ln -s "$T/real.app" "$DESTAPP"
if run; then fail "deveria recusar destino que é symlink"; fi
[[ -L "$DESTAPP" && "$(cat "$T/real.app/Contents/marker")" == release ]] || fail "symlink/real alterados"
rm -f "$DESTAPP"
# 6) build novo que não se prova: erro, saída malformada, inválido.
mk "$DESTAPP" local velho
for bad in error empty malformed invalid fakeauth; do
  mk "$SRCAPP" "$bad" novo; expect_refused "origem $bad" velho
done
# 7) ditto falha: o instalado fica intacto.
mk "$SRCAPP" local novo; mk "$DESTAPP" local velho
if DITTO_FAIL=1 run; then fail "ditto falho deveria falhar"; fi
[[ "$(marker)" == velho ]] || fail "ditto falho alterou o instalado"; no_leftovers ditto
# 8) falha na etapa final (mv do novo para o lugar): restaura o anterior.
mk "$DESTAPP" local velho; mk "$SRCAPP" local novo
if MV_FAIL=new run; then fail "etapa final falha deveria falhar"; fi
[[ "$(marker)" == velho ]] || fail "não restaurou o anterior ($(marker))"
grep -q 'restaurado' "$T/out" || fail "sem aviso de restauração"; no_leftovers final
# 9) falha na etapa final E na restauração: o backup é preservado e avisado.
mk "$DESTAPP" local velho; mk "$SRCAPP" local novo
if MV_FAIL=all run; then fail "falha total deveria falhar"; fi
grep -q 'ERRO GRAVE' "$T/out" || fail "sem ERRO GRAVE"
bak="$(ls -d "$T"/dest/.trincano-install.*/previous.app 2>/dev/null | head -n 1)"
[[ -n "$bak" && "$(cat "$bak/Contents/marker")" == velho ]] || fail "backup não foi preservado"
rm -rf "$T"/dest/.trincano-install.*
echo "test-install: OK (política e install.sh: erro do codesign, saída malformada, assinatura inválida, requisito, falha final com restauração)"
