# Atualização pelo Sparkle e instalação (0.13.0)

O Trincano volta a usar o **Sparkle 2.10.1** (SPM, versão exata fixada em `Ice.xcodeproj` e em `Package.resolved`; licença MIT, a mesma lista do `Acknowledgements`), mas de forma própria: feed, chave e consentimento são do Trincano, nada herdado do Ice. O `MenuBarItemService` não linka o Sparkle.

## O que a pessoa vê
- Janela padrão do Sparkle com as notas da versão em pt-BR (HTML curto, sem script), botões **Instalar**, **Lembrar depois** e **Pular esta versão**.
- **Consentimento**: `SUEnableAutomaticChecks` **não existe** no `Info.plist`; assim o Sparkle pergunta na 2ª abertura e só liga a checagem diária se a pessoa aceitar. Até lá o app não acessa a internet. Nunca grave `true`/`false` nessa chave no `Info.plist` (`UpdateConfigurationTests` falha). O toggle fica em Ajustes > Sobre > Atualizações.
- **Procurar atualizações…** no menu do ícone e em Ajustes > Sobre (checagem manual, iniciada pela pessoa).
- Janela agendada à vista: como o Trincano é um app accessory, o `UpdatesManager` implementa os "lembretes gentis" do Sparkle e traz o app para a frente quando acha uma versão sozinho; volta a accessory ao fechar a janela.
- Feed assinado: `SURequireSignedFeed` + `SUVerifyUpdateBeforeExtraction` no `Info.plist`; o `appcast.sh` assina o `appcast.xml` com `sign_update` (assinatura embutida) e confere; editar o feed depois invalida.
- Sem perfil do sistema (`SUEnableSystemProfiling = false`) e sem "instalar sozinho" (`SUAllowsAutomaticUpdates = false`): a pessoa sempre vê a janela.
- Debug nunca inicia o updater (nem o modo de captura): só o build Release toca a rede.
- A importação das configurações do Ice nunca copia chaves `SU*` (lista de permissão; teste `neverImportsTheUpdateConsentFromIce`).

## Segurança
- `SUFeedURL` = `https://github.com/PiluTech/trincano/releases/latest/download/appcast.xml` (https; o appcast do último release é o único item).
- Atualizações assinadas com **EdDSA**: `SUPublicEDKey` no `Info.plist`; a chave privada fica **só** no 1Password, cofre **Personal**, item **"Trincano: chave Sparkle (EdDSA)"** (não está no Keychain nem no repo). **Perder a chave = nenhum app instalado atualiza mais**; não rode `generate_keys` sem `-p`, ele criaria outro par.
- O Sparkle é assinado de dentro para fora pelo `release.sh` (Installer.xpc, Downloader.xpc, Autoupdate, Updater.app, framework) com Developer ID e runtime reforçado; a notarização cobre o conjunto.
- A assinatura EdDSA e o `length` saem do `.dmg` **final** (depois do `stapler`, que muda os bytes).

## Fazer um release
1. Subir `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` (o Sparkle compara o **build**, não a versão curta) e criar `docs/notas-da-versao/<versão>.html` (pt-BR, curto, sem `<script>`, sem `on*=`).
2. Criar a tag `v<versão>` no commit e rodar `scripts/release.sh` com `NOTARY_*` e `SPARKLE_OP_REF=op://Personal/<id do item>/password` (o título tem `:`, use o ID do item: `op item get "Trincano: chave Sparkle (EdDSA)" --vault Personal --format json`).
3. Saída em `build/release/`: `Trincano-<versão>.dmg` e `appcast.xml` (`scripts/appcast.sh` gera, assina o feed e **confere**: XML, assinatura do feed, https do repo na tag, `length`, assinatura contra a chave do `Info.plist`, build maior que o da tag anterior, notas sem script).
4. Publicar (precisa do OK do Paulo): criar o release `v<versão>` no GitHub com o `.dmg` **e** o `appcast.xml` como assets. O upload é manual.

Testes: `scripts/test-appcast.sh` (par de chaves descartável; 10 casos, incluindo `.dmg` adulterado, feed editado, feed sem assinatura, outra chave, build não maior, script nas notas) roda dentro do `scripts/check.sh`.

## Instalação (padrão de app de Mac)
- **.dmg arrumado**: janela 660x460, app à esquerda, Aplicativos à direita, fundo com a seta "Arraste o Trincano para Aplicativos" (`Resources/dmg/background.png` e `@2x`, gerados por `scripts/make-dmg-background.swift`; cinza-azulado de luminância média: o rótulo branco ou preto do Finder passa de 4,5:1 nos dois temas). O layout é feito por AppleScript no Finder dentro do `release.sh` (sem ferramenta de terceiros); o terminal precisa de Automação > Finder.
- **Mover para Aplicativos** (`AppMover`, decisão em `MoveToApplicationsPlan`, testada): ao abrir fora de `/Applications` e `~/Applications` (Downloads, dentro do .dmg, translocado), um alerta nativo oferece mover. Copia para `/Applications/Trincano.app` (pede senha só se precisar; só substitui uma cópia do mesmo bundle id e nunca um symlink, conferido por `lstat` na decisão `ReplacementTargetPlan` e de novo logo antes do `rm -rf` do fallback com senha de administrador), tira a quarentena da cópia (o app em execução já passou pelo Gatekeeper) e reabre de lá; apaga a cópia antiga quando dá (não apaga de dentro do .dmg nem translocada). "Agora não" grava `MoveToApplicationsDeclined`. Builds de desenvolvimento (`DerivedData`, `build/Build/Products`) ficam como estão. Isso também garante que o Sparkle consiga se atualizar.

## Homebrew
O cask (repo `PiluTech/homebrew-tap`, ainda por criar) deve usar `auto_updates true`, já que o app se atualiza sozinho.

## Texto público (propor antes de editar; precisa do OK do Paulo)
`PRODUTO.md` e a política de privacidade do site dizem "sem acesso à rede". Texto sugerido:
- PRODUTO.md: "Sem telemetria. O Trincano só acessa a internet para procurar atualizações, e só depois que você permite."
- Política de privacidade: "O Trincano não coleta dados. Se você permitir, ele consulta uma vez por dia o arquivo de atualizações em github.com/PiluTech/trincano (a mesma consulta que o seu navegador faria) para saber se há versão nova; nenhuma informação sobre você ou sobre o seu Mac é enviada além do que toda requisição HTTPS carrega: o endereço IP e o cabeçalho com o nome e a versão do app e do Sparkle (por exemplo, `Trincano/0.13.0 Sparkle/2.10.1`). Sem a sua permissão, o app não acessa a internet."
