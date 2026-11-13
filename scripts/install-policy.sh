# Política de instalação (usada por scripts/install.sh e testada por scripts/test-install.sh).
# Um app instalado com Developer ID (a release notarizada) NUNCA é sobrescrito por build local ou ad-hoc:
# a mistura de assinaturas (binário local + Sparkle.framework de outra equipe) derruba o app no dyld.

# sig_kind <app>: absent | adhoc | developer-id:<TEAMID> | local   (via codesign, sem seguir nada além do bundle)
sig_kind() {
  local app="$1" info
  [[ -d "$app" ]] || { echo absent; return; }
  info="$(codesign -dv --verbose=2 "$app" 2>&1 || true)"
  if grep -q '^Authority=Developer ID Application' <<<"$info"; then
    echo "developer-id:$(sed -n 's/^TeamIdentifier=//p' <<<"$info" | head -n 1)"
  elif grep -q '^Signature=adhoc' <<<"$info"; then
    echo adhoc
  else
    echo local
  fi
}

# install_allowed <tipo do novo> <tipo do instalado>: sai 0 se pode substituir.
install_allowed() {
  local src="$1" dst="$2"
  case "$dst" in
    developer-id:*) [[ "$src" == "$dst" ]] ;;   # só outra release da mesma equipe substitui uma release
    *) return 0 ;;                               # ausente, local ou ad-hoc: pode trocar
  esac
}
