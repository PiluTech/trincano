# Validação e release pelo GitHub Actions

O repositório é público, então os runners padrão (`macos-26`, `ubuntu-latest`) são gratuitos. Dois workflows em `.github/workflows/`:

- `ci.yml` (**CI**): em PR e em push na `main`. SwiftLint `--strict` na versão **fixada** (0.65.1, binário portátil conferido por sha256; atualize versão e hash juntos), testes do Xcode (`TrincanoTests`), build Release sem assinatura, catálogo PT-BR, `check-icon-bundle` e `test-appcast`. `concurrency` cancela o run anterior do mesmo PR, `timeout-minutes: 45`, `paths-ignore` para `docs/**`, `**/*.md`, `LICENSE` e os templates de issue. Também é chamado pelo `release.yml` (`workflow_call`), onde o `paths-ignore` não vale.
- `release.yml` (**Release**): só por tag `vX.Y.Z`. Passos: `verify` (sem segredos) → `ci` → `sign` (environment `release`) → `publish` (rascunho).

Todas as actions estão fixadas por SHA (comentário ao lado com a versão): `actions/checkout` v7.0.1, `actions/upload-artifact` v7.0.2, `actions/download-artifact` v8.0.2. Para atualizar, resolva a tag na API (`gh api repos/actions/<nome>/git/ref/tags/<tag>`, desreferenciando tag anotada) e troque o SHA.

## O que o `release.yml` faz
1. **verify** (`macos-26`, `contents: read`, sem segredos): o formato da tag; o commit da tag já está na `main`; `MARKETING_VERSION` do projeto igual à tag; existe `docs/notas-da-versao/<versão>.html`.
2. **ci**: o mesmo `ci.yml`.
3. **sign** (`environment: release`, `contents: read`): só aqui existem os segredos, e cada um fica no menor escopo possível:
   - **Developer ID**: o `.p12` vira um **chaveiro temporário** (senha aleatória, só no shell do passo) e o arquivo é apagado logo após o import. O chaveiro entra na lista de busca para o `codesign` usar; é apagado no fim (`if: always()`).
   - **Notarização**: o `scripts/release.sh` roda em duas fases. Fase 1 (`BUILD_ONLY=1`): build, assinatura e conferências, sem nenhuma chave de notarização. Depois, um passo próprio grava a `.p8` num arquivo `600` (o caminho vai só ao passo seguinte, por saída do passo; não existe variável com a chave em lugar nenhum). Fase 2 (`SKIP_BUILD=1`, `NOTARY_KEY_FILE`): notarização, staple, `.dmg` e `spctl` (`SKIP_APPCAST=1`). Logo em seguida um passo apaga a `.p8`; o `always()` final repete como rede de segurança.
   - **Sparkle**: um passo seguinte e separado grava a chave EdDSA num arquivo `600`, roda `scripts/appcast.sh` com `SPARKLE_KEY_FILE` só nesse comando e a apaga na hora (de novo pelo `always()`, como rede de segurança). Nada disso vai para o `GITHUB_ENV`.
   Depois confere o sha256 contra o `.source.txt`, grava `SHA256SUMS.txt` e sobe os três arquivos como artefato (14 dias). Nenhum segredo vai a `echo`; o que não é segredo (identidade, versão) pode aparecer no log.
4. **publish** (`ubuntu-latest`, `contents: write`, sem segredos de assinatura): baixa o artefato, **confere o sha256** do `.dmg` com o que o job de assinatura calculou e com o `SHA256SUMS.txt`, confere que o appcast aponta para a tag e que o `length` bate com o tamanho do `.dmg`, e cria o release como **rascunho** (`gh release create --draft --verify-tag`) com `.dmg`, `appcast.xml` e `SHA256SUMS.txt`. **Publicar o rascunho é manual** (é ele que liga o feed `releases/latest/download/appcast.xml`).

## Como lançar
1. Subir `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` (o Sparkle compara o build) e criar `docs/notas-da-versao/<versão>.html`; PR e merge na `main`.
2. `git tag vX.Y.Z <commit da main> && git push origin vX.Y.Z`.
3. O job `sign` espera a aprovação do revisor do environment. Aprove em Actions → o run → "Review deployments".
4. Conferir o rascunho (sha256 na descrição) e publicar.

## Configuração única (rodar depois do merge, com o Touch ID do Paulo)
O repo é `PiluTech/trincano`; o revisor é o usuário `PiluVitu` (id `69992923`).

### Environment `release`: revisor obrigatório e política só tags `v*`
```sh
gh api -X PUT repos/PiluTech/trincano/environments/release --input - <<'JSON'
{
  "reviewers": [{ "type": "User", "id": 69992923 }],
  "prevent_self_review": false,
  "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true }
}
JSON
gh api -X POST repos/PiluTech/trincano/environments/release/deployment-branch-policies -f name='v*' -f type=tag
```
`prevent_self_review: false` porque quem sobe a tag e quem aprova é a mesma pessoa; o ganho aqui é a pausa explícita e a restrição às tags `v*`.

### Segredos do environment (nunca em log; o Touch ID libera o 1Password)
```sh
R=PiluTech/trincano
# Developer ID (.p12 e senha), do item "Apple: certificados de assinatura (Developer ID + Apple Development)"
op read "op://Personal/q7irfce5b323ya7nrpezmbem5u/p12" | base64 | gh secret set DEVELOPER_ID_P12_BASE64 --env release -R $R
op read "op://Personal/q7irfce5b323ya7nrpezmbem5u/senha_p12" | gh secret set DEVELOPER_ID_P12_PASSWORD --env release -R $R
# Notarização (chave da App Store Connect API, item "App Store Connect API (PiluTech)")
op read "op://Personal/y5gellouprro6hlt7fvkx7zpgu/p8" | base64 | gh secret set NOTARY_P8_BASE64 --env release -R $R
printf '%s' '3BB5BHQUAC' | gh secret set NOTARY_KEY_ID --env release -R $R
printf '%s' 'a29689f0-ca49-4ee5-b324-03c9dfa8f5e4' | gh secret set NOTARY_ISSUER --env release -R $R
# Chave EdDSA do Sparkle (item "Trincano: chave Sparkle (EdDSA)")
op read "op://Personal/mt7n4qxm6q5plnahpdtx3xxiti/password" | gh secret set SPARKLE_ED_PRIVATE_KEY --env release -R $R
gh secret list --env release -R $R
```
`NOTARY_KEY_ID` e `NOTARY_ISSUER` não são segredos de fato, mas ficam no environment para a configuração ficar num lugar só. O `.p12` de `q7irfce5…` é o backup do chaveiro de login: o workflow escolhe a única identidade "Developer ID Application" dele e falha se houver zero ou mais de uma. **Perder a chave do Sparkle = nenhum app instalado atualiza**: o 1Password continua sendo a origem; o secret é só uma cópia (rotacionar = rodar o comando de novo).

## Pontos a validar na primeira tag
- **Import do `.p12` com `-A` (mantido de propósito)**: o workflow importa com `-A` e depois restringe com `set-key-partition-list`. Trocar por `-x` (chave não extraível) foi sugerido, mas um teste rápido e incompleto não mostrou que `-x` impeça o `security export` e o `codesign` falhou com `errSecInternalComponent` onde o `-A` funcionou. Decisão: manter `-A` até validar na primeira tag, **sem novos testes de chaveiro**; o chaveiro é temporário (apagado no `always()`) e o runner é efêmero. Se a primeira tag assinar bem, avaliar `-x` ali, com HOME temporário e sem tocar na lista de busca do usuário.
- **Finder no runner**: o `.dmg` arrumado usa AppleScript no Finder (`release.sh`). O passo "Finder aceita AppleScript" falha cedo, antes da notarização, se o runner não permitir. Se falhar, o caminho é um layout do `.dmg` sem Finder (por exemplo `.DS_Store` pré-gerado), a decidir.
- **`macos-26`**: arm64, Xcode 26 da imagem do runner; o Xcode exato aparece no passo "Versões" do `ci.yml`. A primeira rodada do CI no PR dirá se o SwiftLint da imagem concorda com a versão local (0.65.1).
- **Primeira execução do CI**: o `scripts/check.sh` local continua valendo (inclui o build assinado com o certificado local); o CI roda a mesma validação sem assinatura.
- **Checks obrigatórios**: com `paths-ignore`, um PR só de docs não dispara o `CI`; se a branch protection exigir o check `Lint, testes e build Release`, esses PRs ficam pendentes. Não exija o check, ou troque o `paths-ignore` por um job que decide dentro do workflow.

## Quem pode mexer no caminho de release
- **CODEOWNERS** (`.github/CODEOWNERS`): `.github/workflows/`, `release.sh`, `appcast.sh` e este doc pertencem a `@PiluVitu`. O arquivo só vira exigência se a proteção da `main` tiver "Require review from Code Owners" (ruleset ou branch protection): ligue quando o Paulo quiser.
- **Ruleset que restringe criar tags `v*` (proposta, NÃO criado):** só quem tem bypass cria, atualiza ou apaga essas tags. A API de rulesets aceita como bypass papéis, times e integrações (não um usuário avulso); com o Paulo como único administrador do repo, o papel `admin` equivale a "só o Paulo".
```sh
gh api -X POST repos/PiluTech/trincano/rulesets --input - <<'JSON'
{
  "name": "tags de release (v*)",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [{ "type": "creation" }, { "type": "update" }, { "type": "deletion" }],
  "bypass_actors": [{ "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }]
}
JSON
```
Confira o resultado em Settings → Rules. Sem esse ruleset, quem tem acesso de escrita ao repo pode empurrar uma tag `v*` e iniciar o workflow; mesmo assim o job `sign` só roda depois do revisor do environment aprovar.

## Proposta (não criada): bump do cask no `PiluTech/homebrew-tap`
Depois do release publicado, um job extra poderia abrir um PR no tap com a versão e o sha256 novos. Precisa de um **token fine-grained** limitado ao repo `PiluTech/homebrew-tap` (`Contents: write` e `Pull requests: write`), guardado como `HOMEBREW_TAP_TOKEN` no environment `release` (ou num environment próprio). Esboço: `on: release: types: [published]`, baixar o `.dmg` do release, calcular o sha256, editar `Casks/trincano.rb` (`version` e `sha256`, mantendo `auto_updates true`) e abrir o PR com `gh pr create`. Fica de fora até o Paulo decidir criar o token.
