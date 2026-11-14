# Auditoria de acessibilidade e localização (13/11/2026)

Auditoria inicial do Trincano contra a skill `padroes-produto-pilutech` (decisão do Paulo, 12/11/2026): WCAG 2.2 AA, localização pt-BR/en/es e llms.txt. Base: `main` em `45f246b`+, código lido e medido (contraste calculado, catálogo contado, buscas no código). **Nenhuma correção foi feita**: cada achado vira um PR pequeno, na ordem que o Paulo combinar. Este arquivo é o roteiro; ao corrigir, marque o achado como feito aqui.

Legenda de severidade: **Alta** = descumpre um padrão de forma visível ou bloqueia um idioma; **Média** = descumpre ou arrisca, com correção clara; **Baixa** = a validar ou polimento. Esforço: **P** (até meio dia), **M** (1 a 2 dias), **G** (mais de 2 dias).

Limites desta auditoria: o que depende de olho humano, VoiceOver ao vivo e Accessibility Inspector está marcado "validar ao vivo". Não há site neste repositório (o `PRODUTO.md` alimenta o `pilutech-sites`), então a parte de `llms.txt` não se aplica aqui.

## Resumo
| # | Achado | Severidade | Esforço |
| --- | --- | --- | --- |
| L1 | Sem espanhol (0 de 227 chaves) | Alta | G |
| A1 | Contraste do texto azul da janela de Permissões (1,64 a 1,94:1 no tema claro) — **feito (#46)**: `#0B5CAD` no claro, `#80BFFF` no escuro, `ContrastPolicyTests` | Alta | P |
| L2 | Idioma de origem do catálogo é en (a skill pede pt-BR) | Média | decisão |
| L3 | Textos fixos fora do catálogo (ações do VoiceOver "left click"/"right click", alerta de migração) | Média | P |
| L5 | Notas da versão do appcast só em pt-BR | Média | M |
| A2 | Alvos de clique: 1 abaixo de 24 pt (SectionedList) e 4 entre 24 e 44 | Média | M |
| A3 | Editor de layout sem alternativa por teclado e VoiceOver (só arrastar) | Média | G |
| A4 | Janelas que abrem sozinhas (regra do app de barra de menus) | Média | M |
| A5 | Tamanhos fixos e fontes fixas (zoom, Tamanho do texto do macOS) | Média | M |
| L4 | Fallback de idioma e troca manual | Média | P (decisão) |
| A9 | Contraste dos elementos gráficos com opacidade e do texto sobre o que o usuário escolhe | Média | M |
| L9 | Espaço de ~35% para texto maior (en/es) só testado na sidebar em pt-BR | Baixa | M |
| L6 | Texto público e prints só em pt-BR/en (README, PRODUTO.md) | Baixa | M |
| A7 | Nomes acessíveis: sem hints/values; ícones isolados a conferir | Baixa | M |
| A8 | Reduzir transparência e "diferenciar sem cor": sem uso explícito | Baixa | P |
| A10 | Foco visível e ordem de foco com Full Keyboard Access | Baixa | M |
| A11 | Mensagem de erro genérica (`NSAlert(error:)`) | Baixa | P |
| L7 | `Info.plist` sem textos localizáveis | Baixa | P |
| L8 | Formatação pelo sistema: conferir os poucos números em texto | Baixa | P |

## O que já cumpre
- **Catálogo de textos:** `Localizable.xcstrings` com 227 chaves, todas com `en` e `pt-BR` (223 traduzidas como string simples e 4 plurais por variação); nenhuma chave "stale".
- **Testes do catálogo** (`LocalizationCatalogTests`): en é a origem, toda chave tem pt-BR não vazia, placeholders iguais entre en e pt-BR, o nome do produto nunca é traduzido, "Barra do Trincano" em pt-BR, títulos da sidebar cabem em pt-BR. `scripts/extract-strings.py check` falha se houver chave nova fora do catálogo.
- **Datas, números e unidades pelo sistema:** `DurationText` usa o formatador de medidas com o locale; "Última verificação" usa `date.formatted(date: .abbreviated…)`; o deslocamento de espaçamento usa `.formatted()`. Não há `DateFormatter`/`String(format:)` montando texto à mão.
- **Movimento:** `MotionPolicy`/`Motion` limitam as transições a 150 a 300 ms e vão a **0 ms** com "Reduzir movimento" (testado em `MotionPolicyTests`). Todas as animações encontradas (`DisplayMapView`, `IceBarColorManager`, `LayoutBarContainer` e a entrada da extensão do notch, `NotchExtensionView.appearAnimation`, que vira `nil` com `Motion.reduceMotion`) passam por `Motion`.
- **Nomes acessíveis já presentes:** ícones da barra (`ControlItem`: "Trincano", seção oculta e sempre oculta), itens da Barra do Trincano (rótulo + trait botão + ações), `DisplayMapView` (rótulo e estado selecionado), `HotkeyRecorder`, itens do editor de layout (`LayoutItemAccessibility`, testado), cabeçalhos de seção (`.isHeader`), decorativos escondidos do VoiceOver (8 usos de `accessibilityHidden`), dica de teclado do painel de busca ("setas navegam, Return clica…").
- **Foco:** os controles customizados (slider, seletor de gradiente, `SectionedList`, `HotkeyRecorder`, editor de aparência, busca, `LayoutBar`) declaram `contentShape([.focusEffect, …])`, então o anel de foco do sistema acompanha a forma.
- **Contraste do ícone novo** (medido): itens `#A9E8E3` sobre a barra `#0D3940` = 9,15:1; barra sobre o tile claro = 9,9 a 12,2:1; pingentes `#17939B` sobre o meio do tile = 3,28:1 (gráfico, mínimo 3:1).
- **Ajustes não abrem no lançamento:** `applicationDidFinishLaunching` não abre a janela de Ajustes; ela só abre por menu, atalho ou reabertura (`applicationShouldHandleReopen`). Lembretes de atualização do Sparkle são "gentis" (não roubam o foco).
- **O único `withAnimation` fora de `Motion` respeita "Reduzir movimento":** `NotchExtensionView.appearAnimation` vira `nil` com `Motion.reduceMotion` e usa `Motion.duration(.fade)` (150 a 300 ms).
- **Sem rede nem telemetria**; textos públicos com OK do Paulo (regra mantida).

## Localização

### L1 — Sem espanhol · Alta · G
- **Onde:** `Ice/Resources/Localizable.xcstrings` tem só `en` e `pt-BR`; `knownRegions` do projeto = `en, Base, pt-BR`; `LocalizationCatalogTests` e `extract-strings.py check` só olham pt-BR.
- **Como medir:** `python3` contando `localizations` por idioma (hoje es = 0 de 227).
- **Como corrigir:** (1) traduzir as 227 chaves para es como texto de produto (não literal; "Trincano" e "Barra do Trincano" tratados; plurais es com `one`/`other`); (2) `knownRegions` com `es`; (3) generalizar os testes: chaves iguais nos três idiomas, não vazias, placeholders iguais, `check` do script para es; (4) revisão do Paulo (idioma do produto). Sparkle já traz es.
- **Esforço:** G (tradução e revisão); testes P.

### L2 — Idioma de origem é en (skill: pt-BR) · Média · decisão
- **Onde:** `sourceLanguage: en`, `developmentRegion = en`; a skill pede pt-BR como idioma de desenvolvimento.
- **Impacto:** trocar a origem reescreve as 227 chaves (chaves em inglês são o que o código usa e o que facilita `cherry-pick` do Ice). Também define o fallback quando o idioma do usuário não é nenhum dos três (hoje cai em en; a skill quer pt-BR).
- **Proposta:** manter **en como origem técnica** (chaves em inglês) e registrar a exceção à skill, mas tornar **pt-BR o fallback** (ver L4). Decidir com o Paulo.
- **Esforço:** P para decidir e documentar; G se migrar a origem.

### L3 — Textos fixos fora do catálogo · Média · P · **FEITO**
- **Onde:** `MenuBar/IceBar/IceBar.swift:523-524` (ações do VoiceOver `"left click"` e `"right click"`, em inglês fixo); `Utilities/Migration.swift:249` (alerta de migração, inglês, cita "Ice"; só aparece para quem vem de versões antigas do Ice); `ControlItem.swift:389` (`"|"` é símbolo, ok).
- **Como medir:** busca por literais em `NSAlert`, `accessibilityAction(named:)`, `setAccessibility…` e `.title = "…"`; rodar com VoiceOver em pt-BR e abrir o rotor de ações de um item da Barra.
- **Como corrigir:** `String(localized:)`/`Text("…")` com chave nova e tradução nos três idiomas; teste de que não há literal de interface nessas APIs.
- **Esforço:** P.

### L4 — Fallback de idioma e troca manual · Média · P (decisão)
- **Onde:** o app segue o idioma do sistema; não há seletor próprio.
- **Observação:** no macOS 13+ cada app com mais de um idioma ganha a troca por app em Ajustes do Sistema > Geral > Idioma e região > Apps. Recomendo **não** construir seletor próprio e **documentar** esse caminho em `docs/` e na ajuda; o fallback para pt-BR quando o idioma não é en/es/pt exige `CFBundleDevelopmentRegion`/`developmentRegion` = pt-BR (liga com L2).
- **Esforço:** P (documentar), depende de L2.

### L5 — Notas da versão só em pt-BR · Média · M
- **Onde:** `docs/notas-da-versao/<versão>.html` (uma só) e `scripts/make-appcast.py` (uma `<description>`). O README já avisa "release notes (in Portuguese)".
- **Como corrigir:** notas `<versão>.en.html`/`.es.html`, `<description xml:lang="…">` por idioma (o Sparkle escolhe pelo idioma do sistema), `check-appcast.py` e `test-appcast.sh` cobrindo os três e mantendo "sem script".
- **Esforço:** M.

### L6 — Texto público e prints · Baixa · M
- **Onde:** README em en; `PRODUTO.md` e `docs/` em pt-BR; prints em pt-BR (`docs/prints`).
- **Como corrigir:** README com versões pt-BR e es (ou links), prints também em en/es se o site os usar. **Texto público exige OK do Paulo.**
- **Esforço:** M.

### L7 — `Info.plist` sem textos localizáveis · Baixa · P
- **Onde:** `Ice/Resources/Info.plist` (sem `InfoPlist.xcstrings`); os pedidos de Acessibilidade e Gravação de Tela vêm do próprio macOS.
- **Como medir:** `grep UsageDescription` não encontra chaves; confirmar no diálogo real dos três idiomas.
- **Como corrigir:** só se aparecer chave `NS…UsageDescription` ou se o nome visível precisar variar; o nome do produto não se traduz.
- **Esforço:** P.

### L8 — Números dentro de texto · Baixa · P
- **Onde:** poucos `Text("\(…)")` com contagem (ex.: `%lld items`); plurais já por variação no catálogo (en e pt-BR).
- **Como corrigir:** adicionar a variação es (`one`/`other`) e conferir que nenhum número é montado à mão; incluir no teste de L1.
- **Esforço:** P.

### L9 — Espaço para crescer ~35% · Baixa · M
- **Onde:** só a sidebar tem teste de largura (pt-BR). Janela de Permissões tem largura fixa de 550 pt; alertas e botões do painel de busca não foram medidos em en/es.
- **Como medir:** Xcode, esquema, "Run with Double Length Pseudolanguage" e "Right to Left Pseudolanguage", e percorrer Ajustes, Permissões, Busca e alertas.
- **Como corrigir:** `lineLimit` e `minimumScaleFactor` onde fizer sentido, layouts que quebram linha em vez de cortar; estender o teste de largura aos três idiomas.
- **Esforço:** M.

## Acessibilidade

### A1 — Contraste do texto azul das Permissões · Alta · P · **FEITO (PR #46)**
- **Onde:** `Ice/Permissions/PermissionsView.swift:69`, `.foregroundStyle(Color(red: 0.5, green: 0.75, blue: 1))` (`#80BFFF`) no texto "Absolutely no personal information is collected or stored." (negrito, `title3`).
- **Medido:** `#80BFFF` sobre branco = **1,94:1**; sobre cinza claro `#ECECEC` = **1,64:1** (tema claro); sobre `#1E1E1E` = 8,59:1 e sobre `#323232` = 6,61:1 (tema escuro passa). Mesmo contado como "texto grande" (3:1) o tema claro falha.
- **Como corrigir:** trocar por cor semântica (`.primary`/`.secondary`/`Color.accentColor`) ou por um par claro/escuro: `#0B5CAD` no tema claro dá 6,67:1 sobre branco e 5,64:1 sobre `#ECECEC`; manter o azul claro só no escuro. Teste que mede o par pelas cores resolvidas.
- **Esforço:** P.

### A2 — Alvos pequenos · Média · M
- **Onde (alvos reais, revisão do Crivo):**
  - **Abaixo de 24 pt (falha até o mínimo do WCAG 2.2):** `SectionedList.swift:231` (22×22).
  - **Entre 24 e 44 pt (cumpre o mínimo do WCAG, não os 44 da PiluTech):** `HotkeyRecorder` (132×24), `IceGradientPicker` (200×24), extensão do notch (`NotchExtensionView.swift:174`, 30×28) e os botões da barra inferior do painel de busca (`BottomBarButtonStyle`, `MenuBarSearchPanel.swift:491`: o `frame(height: 22)` é só do rótulo e o padding interno do botão leva o alvo efetivo a ~28×28 pt).
  - **Fora da lista (não são alvos de clique):** `MenuBarSearchPanel.swift:467,604` são as teclas decorativas do rodapé (`ShortcutHint`, sem ação); `GeneralSettingsPane.swift:305` (15×15) é o `ProgressView` de "aplicando", não o botão de reset.
  - **A validar no Accessibility Inspector:** o botão de reset do espaçamento (`GeneralSettingsPane.swift:~310`, borderless com ícone e `.help`) e o botão nativo de `AdvancedSettingsPane.swift:158` (`frame(height: 22)` em controle do sistema; não é falha até medir).
  - **Já cumprem:** botões Sair/Continuar das Permissões (`controlSize(.large)`) e as linhas do Sobre (`minHeight: 44`).
- **Como medir:** Accessibility Inspector (Inspeção, tamanho do frame) em cada painel; script de inventário dos `.frame`.
- **Decisão pedida ao Paulo:** a skill pede 44 pt, mas o app roda com ponteiro em barra de menus densa (24 a 37 pt de altura). Proposta: **mínimo duro de 24 pt (WCAG 2.2, 2.5.8) em tudo**, com a exceção de espaçamento só onde documentada, e **44 pt** nos controles principais e em tudo que for novo.
- **Esforço:** M.

### A3 — Editor de layout sem alternativa ao arrastar · Média · G
- **Onde:** `MenuBar/LayoutBar/*` (mover itens entre Visível, Oculto e Sempre oculto só por arrastar); pendência 5 do `docs/estado-atual.md`.
- **Como medir:** VoiceOver (⌘F5) e Full Keyboard Access: tentar mover um item sem mouse.
- **Como corrigir:** `accessibilityAction(named:)` "Mover para Visível/Oculto/Sempre oculto" em cada item, mais comandos de teclado (setas e Return) no editor; anunciar o resultado (`polite`, só porque a pessoa agiu).
- **Esforço:** G.

### A4 — Janelas que abrem sozinhas · Média · M · **itens 1 e 2 FEITOS (A4a)**; 3 e 4 pendentes (A4b)
Regra do Paulo (12/11): app de barra de menus não abre janela sozinho, só quando a pessoa pede ou no primeiro uso, e nada de `activate(ignoringOtherApps:)` sem ação da pessoa.
- **Onde:**
  1. `AppMover.offerIfNeeded()` no lançamento, com `NSApp.activate(ignoringOtherApps: true)` e modal, a cada abertura fora de `/Applications` até a pessoa dizer "Agora não" (`Main/AppMover.swift:32`).
  2. Janela de Permissões em **todo** lançamento enquanto faltar permissão (`AppState.performSetup(hasPermissions: false)` → `openWindow(.permissions)`), inclusive depois de reinstalar com outra assinatura ou de resetar o TCC (incidente de 12/11).
  3. Alerta de importar configurações do Ice no primeiro lançamento, com `NSApp.activate()` (`Utilities/IceSettingsImporter.swift:32`).
  4. Pergunta de consentimento do Sparkle na segunda abertura.
  5. Alertas modais de migração (`Utilities/Migration.swift`), só para quem vem do Ice antigo.
- **Como medir:** abrir o app do zero e depois com a permissão revogada, e anotar toda janela que aparece sem clique.
- **Como corrigir:** (1) oferecer só no primeiro uso e depois por item de menu "Mover para Aplicativos…", sem ativar o app à força; (2) depois do primeiro uso, trocar a janela por indicador no ícone e notificação opcional, abrindo a janela só pelo clique; (3) sem `activate` forçado, oferta no primeiro uso; (4) consentimento em Ajustes > Atualizações, sem janela solta; (5) manter, é raro.
- **Esforço:** M.

### A5 — Tamanhos e fontes fixos · Média · M
- **Onde:** janela de Permissões `.frame(width: 550).fixedSize()` (`PermissionsView.swift:42`); painel de busca 600×400 (`MenuBarSearchPanel.swift:227`); Ajustes com min/max fixos (`SettingsWindow.swift:21`); 11 usos de `.font(.system(size:))` (sidebar, Sobre, painel de busca, extensão do notch, Permissões).
- **Como medir:** Ajustes do Sistema > Acessibilidade > Tela > Tamanho do texto no máximo; zoom 200% dos textos; Double Length Pseudolanguage (L9).
- **Como corrigir:** estilos de texto do sistema (`.title`, `.callout`, `.caption`), `@ScaledMetric` para ícones e alturas, janelas que crescem com o conteúdo.
- **Esforço:** M.

### A7 — Nomes acessíveis · Baixa · M
- **Onde:** 7 `accessibilityLabel`, 0 `accessibilityHint`/`accessibilityValue`; 10 `Image(systemName:)` a conferir (`GeneralSettingsPane.swift:311` reset com só `.help`; `AdvancedSettingsPane.swift:147`; `CalloutBox`; `PermissionsView.swift:171`).
- **Como medir:** Accessibility Inspector > Auditoria em cada painel (Geral, Barra de menus, Aparência, Atalhos, Avançado, Sobre, Permissões) e um passeio completo com VoiceOver em pt-BR e en.
- **Como corrigir:** rótulo explícito em todo botão só com ícone, `accessibilityValue` nos controles que mostram valor (slider de espaçamento, estado de permissão), hints só quando o rótulo não basta.
- **Esforço:** M.

### A8 — Reduzir transparência e diferenciar sem cor · Baixa · P
- **Onde:** nenhum uso explícito de `accessibilityReduceTransparency`/`accessibilityDifferentiateWithoutColor`. `NSVisualEffectView` e `.material` (painel de busca, `VisualEffectView`) já obedecem a "Reduzir transparência" do sistema.
- **Como medir:** ligar "Reduzir transparência" e "Diferenciar sem cor" e percorrer Busca, Barra, Ajustes e Aparência; conferir que estado (selecionado, concedido, ativo) nunca depende só de cor (`DisplayMapView` já usa checkmark além do acento).
- **Esforço:** P.

### A9 — Contraste dos elementos com opacidade · Média · M
- **Onde:** traços e preenchimentos com opacidade 0,18 a 0,5 (`DisplayMapView.swift:99,111`, `SectionedList.swift:227`, `BetaBadge.swift:25`, `IceSlider.swift:66`, busca `MenuBarSearchPanel.swift:225,498`, `HotkeyRecorder.swift:230`). A aparência personalizada da barra (tint, sombra, forma) e o texto dos itens (do app dono) dependem do que o usuário escolhe e não dá para garantir.
- **Como medir:** captura dos painéis nos dois temas e razão entre o elemento e o fundo (gráficos e bordas de controle ≥ 3:1; texto ≥ 4,5:1). Incluir o contraste dos prints do catálogo (`scripts/capture-prints.sh`).
- **Como corrigir:** subir a opacidade ou usar cores semânticas; documentar que a aparência personalizada é escolha do usuário.
- **Esforço:** M.

### A10 — Foco visível e ordem de foco · Baixa · M
- **Onde:** Ajustes, painel de busca (setas e Return) e `LayoutBar`; só há 1 `onKeyPress` (seletor de gradiente) e 1 `@FocusState` (campo de busca).
- **Como medir:** Full Keyboard Access ligado, Tab/Shift-Tab/setas/Espaço/Esc em cada tela; o foco segue a ordem visual, nada prende o foco, o anel é visível nos dois temas.
- **Esforço:** M (validar ao vivo e corrigir o que sair).

### A11 — Erros genéricos · Baixa · P
- **Onde:** `GeneralSettingsPane.swift:346`, `NSAlert(error:)` mostra a descrição do erro como veio, sem dizer o que fazer.
- **Como corrigir:** mensagem localizada com a causa e o próximo passo, perto da ação (e anunciada).
- **Esforço:** P.

### A12 — llms.txt · Não se aplica
O Trincano não é um site. A página do produto (`pilutech.com.br/apps/trincano`) é do repositório `pilutech-sites`, que deve servir `llms.txt` conforme a skill; o `PRODUTO.md` daqui só alimenta o texto.

## Ordem sugerida (para o Paulo combinar)
1. **A1** (contraste, P, Alta) e **L3** (textos fixos, P): correções rápidas, sem decisão.
2. **L1** (espanhol, G, Alta), com **L2/L4** decididos antes (origem, fallback pt-BR) e **L8/L9** dentro do mesmo trabalho.
3. **A4** (janelas que abrem sozinhas) e **A2** (alvos, depois da decisão 24/44).
4. **A5**, **A7**, **A8**, **A10**, **A11**: lote de acessibilidade com validação ao vivo (VoiceOver, Full Keyboard Access, Tamanho do texto).
5. **A3** (editor de layout acessível, G) e **L5** (notas por idioma).
6. **A9** (medição de contraste das opacidades) e **L6/L7**.

## Como cada correção deve provar o resultado
Cada PR de correção informa a linha "A11y/l10n" com o que foi conferido e como (teste, medição de contraste calculada, VoiceOver, Accessibility Inspector) e não pode piorar nenhum ponto da seção "O que já cumpre".
