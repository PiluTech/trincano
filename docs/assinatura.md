# Assinatura e XPC

## Por que um certificado local

Sem Developer ID o app seria assinado ad hoc, e o cdhash muda a cada build: o macOS (TCC) esquece Acessibilidade e Gravação de Tela a cada instalação. Com o certificado autoassinado **Trincano Local Signing** o requisito designado fica
`identifier "br.com.pilutech.trincano" and certificate leaf = H"<hash>"`, que não muda entre builds.

- `scripts/signing.sh` cria o certificado na primeira build, num keychain próprio sem senha em `~/.trincano/signing/trincano-signing.keychain-db` (adicionado à lista de busca do usuário). Nada vai para o login keychain.
- Recriar o certificado muda o hash e **pede as permissões de novo**; não apague o keychain sem necessidade.
- O certificado não é confiável para o sistema (não passa no Gatekeeper para outros Macs). Serve só para uso local.

## Distribuição: Developer ID + notarização (`scripts/release.sh`)

O Trincano é distribuído **fora da Mac App Store** (GPL-3 e Acessibilidade/XPC não cabem na loja), como `.dmg` assinado com Developer ID e notarizado, para download em pilutech.com.br. Publicar no site é um passo à parte (exige OK do Paulo); o script só gera o arquivo.

```sh
NOTARY_KEY_ID=<key id> NOTARY_ISSUER=<issuer id> NOTARY_OP_REF='op://<cofre>/<item>/.../p8' scripts/release.sh
```

O que o script faz, em ordem:
1. Compila Release (via `~/.maestri-local/build-slot.sh` se existir) e assina de **dentro para fora**, sem `--deep`: `MenuBarItemService.xpc`, depois o app, com `--timestamp --options runtime`. **Sem entitlements** (Acessibilidade e Gravação de Tela são TCC, não entitlement). Confere o runtime reforçado e a ausência de `get-task-allow`.
2. Notariza o app (`notarytool submit --wait`) e grampeia (`stapler staple`).
3. Monta o `.dmg` (Trincano.app, atalho Applications, `LICENSE` GPL-3 e `LEIA-ME.txt` com o crédito ao Ice/Jordan Baird), assina, notariza, grampeia e valida.
4. Verifica com `spctl -a -vv` (dmg e app montado) e `codesign --verify --deep --strict`.

Saída: `build/release/Trincano-<versão>.dmg`. O crédito ao Ice também está na tela Sobre.

- O script recusa versão com `-dev` ou fora de `X.Y.Z` (`MARKETING_VERSION`), recusa working tree sujo e exige a tag `v<versão>` apontando para o HEAD (crie-a antes) e grava versão, link da tag e commit curto no `LEIA-ME.txt` do .dmg e em `<dmg>.source.txt` ao lado dele (GPL). Ctrl-C/TERM apaga a chave temporária e aborta (exit 130).
- A leitura do Team ID que falha (erro de API) NÃO cai para `signing-identifier`: a política falha fechada em "mesmo time" (`XPCPeerPolicy.TeamLookup.failed`).
- `DEVELOPER_ID` escolhe a identidade (padrão: a única "Developer ID Application" do keychain). `SKIP_BUILD=1` reaproveita o build; `SKIP_NOTARIZE=1` só assina (não serve para distribuir).
- **Segredos:** nada no repo. A chave `.p8` da App Store Connect API é lida do 1Password na hora (`op read`) para um arquivo temporário `chmod 600`, apagado ao sair (`trap`, inclusive em erro); `NOTARY_KEY_FILE` aceita um `.p8` existente. Key ID e Issuer vêm do ambiente.
- Com Team ID a checagem do XPC volta sozinha para "mesmo time e signing identifier" (ver abaixo); o build local continua com o certificado "Trincano Local Signing".
- O build notarizado compartilha o bundle id com o instalado: não abrir um por cima do outro sem avisar o Paulo. Validar em runtime o Menu Bar Layout com a política "mesmo time" ainda é pendência de teste ao vivo.

## Checagem do canal XPC (app ↔ MenuBarItemService)

`.isFromSameTeam()` nunca passa sem Team ID. Em vez de desligar a checagem (como fazem os PRs #950/#982/#1027 do upstream), o Trincano escolhe por `XPCPeerPolicy` (`Shared/Utilities/XPCPeerPolicy.swift`, com testes):

| Build | Requisito do peer |
|---|---|
| Com Team ID (Developer ID / Apple Development) | mesmo time **e** signing identifier esperado |
| Sem Team ID (certificado local ou ad hoc) | signing identifier exato (requisito leve `signing-identifier`) |

**Limite conhecido (MÉDIO, em aberto):** o `signing-identifier` sozinho **não prova que o peer foi assinado com o nosso certificado**. Verificado offline: copiar o `.xpc`, reassinar ad hoc (`codesign -f -s -`) mantém `identifier "…MenuBarItemService"` satisfeito, mas **falha** em `identifier "…" and certificate leaf = H"…"`. A API Swift `XPCPeerRequirement` do SDK 26 não aceita string de requisito nem certificado (só entitlement, mesmo time, plataforma e requisitos leves), e `XPCSession`/`XPCListener` não expõem o handle C para `xpc_*_set_peer_code_signing_requirement`. Prender o certificado exigiria trocar o transporte XPC por conexão C ou usar `cdhash`; fica como tarefa própria.
Mitigação atual: o helper é um XPC service embutido no app, visível só ao app que o contém, e a checagem continua ativa (melhor que os PRs do upstream, que a removem). Com Developer ID o requisito volta a ser "mesmo time" e o limite some.

**Pendente de validação em runtime** (precisa do Paulo, pois o Ice ainda está aberto e as permissões pedem confirmação): confirmar no Tahoe que o Menu Bar Layout carrega os itens com o requisito `signing-identifier`.

## Chave de assinatura

O keychain `~/.trincano/signing` não tem senha nem bloqueio automático e está na lista de busca: qualquer processo rodando como o usuário pode assinar como "Trincano Local Signing". Aceito para um certificado local sem valor fora deste Mac; o Developer ID **não** deve seguir esse modelo (usar o login keychain/Secure Enclave).

## Ferramentas (versões)

SwiftLint 0.65.1 (MIT, Homebrew); gem `xcodeproj` 1.28.1 (MIT) e dependências instaladas com ela (nanaimo, colored2, claide, atomos, base64, nkf, CFPropertyList), só em `~/.gem` do usuário, usadas apenas por `scripts/add-test-target.rb` (dev, nunca embutidas no app).
