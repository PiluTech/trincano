# Política de instalação (usada por scripts/install.sh e testada por scripts/test-install.sh).
#
# Um app instalado com Developer ID (a release notarizada) NUNCA é sobrescrito por build local ou ad-hoc:
# a mistura de assinaturas (binário local + Sparkle.framework de outra equipe) derruba o app no dyld.
# Estado que não dá para provar é DESCONHECIDO e é recusado, nunca tratado como "pode trocar".

TRINCANO_TEAM_ID="WU7Z54BRYQ"
# Requisito do TN3127: âncora Apple, Developer ID CA (1.2.840.113635.100.6.2.6), certificado folha
# Developer ID Application (1.2.840.113635.100.6.1.13) e o OU da nossa equipe. Não depende de texto de Authority.
TRINCANO_RELEASE_REQUIREMENT='anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] and certificate leaf[field.1.2.840.113635.100.6.1.13] and certificate leaf[subject.OU] = "'"$TRINCANO_TEAM_ID"'"'

# sig_kind <app>: absent | unknown | adhoc | local | developer-id:<TEAMID>
#   absent   não existe nada no caminho;
#   unknown  existe, mas não foi possível provar o estado (codesign falhou, saída vazia/malformada, assinatura
#            inválida, link simbólico, TeamIdentifier ausente/múltiplo, Developer ID sem prova criptográfica);
#   adhoc/local  assinados e válidos (--verify --strict), sem Developer ID;
#   developer-id  Developer ID da nossa equipe, provado por --verify --strict e pelo requisito acima.
sig_kind() {
  local app="$1" info rc teams
  if [[ ! -e "$app" && ! -L "$app" ]]; then echo absent; return; fi
  if [[ -L "$app" || ! -d "$app" ]]; then echo unknown; return; fi
  rc=0
  info="$(codesign -dv --verbose=2 "$app" 2>&1)" || rc=$?   # sem `set -e` engolir o código de saída
  if (( rc != 0 )) || [[ -z "$info" ]]; then echo unknown; return; fi
  if ! grep -q '^Identifier=.\{1,\}' <<<"$info"; then echo unknown; return; fi
  # Toda assinatura aceita precisa passar na verificação estrita do bundle inteiro.
  if ! codesign --verify --strict --verbose=2 "$app" >/dev/null 2>&1; then echo unknown; return; fi
  if grep -q '^Authority=Developer ID Application' <<<"$info"; then
    teams="$(sed -n 's/^TeamIdentifier=//p' <<<"$info")"
    if [[ -z "$teams" || "$teams" == *$'\n'* || "$teams" == "not set" || "$teams" != "$TRINCANO_TEAM_ID" ]]; then
      echo unknown; return
    fi
    if ! codesign --verify -R="$TRINCANO_RELEASE_REQUIREMENT" "$app" >/dev/null 2>&1; then echo unknown; return; fi
    echo "developer-id:$teams"; return
  fi
  if grep -q '^Signature=adhoc' <<<"$info"; then echo adhoc; return; fi
  if grep -q '^Authority=.\{1,\}' <<<"$info"; then echo local; return; fi
  echo unknown
}

# install_allowed <tipo do novo> <tipo do instalado>: sai 0 se pode substituir.
install_allowed() {
  local new="$1" old="$2"
  case "$new" in absent|unknown) return 1 ;; esac      # o que vai ser instalado precisa ser provado
  case "$old" in
    unknown) return 1 ;;                               # destino que não dá para provar: recusa
    developer-id:*) [[ "$new" == "$old" ]] ;;          # só outra release da mesma equipe troca uma release
    *) return 0 ;;                                     # ausente, local ou ad-hoc
  esac
}
