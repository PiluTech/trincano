# Identidade visual do Trincano

**Origem do nome:** "trincando" no sentido de *gelado* (cerveja trincando) e a origem no Ice. O ícone parte dessa ideia, sem copiar o cubo do Ice.

## Escolhida: "Barra congelada"
- **Ícone do app** (`icone/app-barra-congelada.svg`, prévia `icone/app-barra-congelada-previa.png`): versão redesenhada da "Barra congelada" (escolhida pelo Paulo em 12/11/2026, rodada do Farol): squircle do macOS com a barra de menus escura e o notch recortado no topo, itens claros dentro dela, três pingentes de gelo em teal e uma gota. Tile claro gelado em menta/teal (#F6FEFD→#C6ECE8), longe do azul-marinho do Ice. Fonte do desenho: SVG de `~/PILUTECH/Personal/.icones-rodada/trincano/`.
- **Glifos da barra de menus** (18 pt, template monocromático): *escondido* = barra sólida com a mordida do notch (bloco congelado); *visível* = contorno da barra com a mesma mordida e 3 pontos dentro. Os estados diferem pela **silhueta** (massa cheia x anel com pontos), não pela cor.
- Assets: `AppIcon.appiconset` (10 tamanhos) e `ControlItemImages/FrostBar/FrostBarFill|FrostBarStroke` (@1x/@2x/@3x, template). Padrão do ícone do Trincano na barra de menus (`ControlItemImageSet.defaultIceIcon`); o conjunto "Barra congelada" é o primeiro da lista em Ajustes → Geral. Quem já tinha escolhido outro ícone mantém a escolha.

## Por que esta (critério: leitura a 18 pt, distinção do Ice, amarra com o nome)
Ranking do designer (1 = melhor): leitura a 18 pt: opção 2 em 1º; distinção do Ice: 2º; amarra com "trincando/gelado": 2º. Empatou na soma com a opção 3 (trinca + gota), mas o ícone do app da opção 3 ainda lia as trincas como raios e o da opção 2 é literal ao produto (barra de menus com notch) e tem o par de glifos mais legível (folha a 36 px em `propostas-icone-2/folha-glifos-36px.png`).

## Propostas
`propostas-icone-2/`: opção 1 *Cristal com recorte do notch*, opção 2 *Barra congelada* (escolhida), opção 3 *Trinca luminosa e gota*. SVG de cada app e dos glifos, prévias PNG e a folha de glifos a 36 px (claro e escuro).

## Créditos
O desenho é original do Trincano (proposta do subagente `designer`, 2026), sob a mesma licença do projeto (GPL-3.0). O ícone do Ice não é usado nos assets novos; o imageset `IceCube` permanece só para decodificar preferências antigas.

## Geração e verificação
- `scripts/generate-icons.sh` renderiza o SVG do app (`icone/app-barra-congelada.svg`) nos 10 PNGs do `AppIcon.appiconset` (via `qlmanage`, **cada tamanho direto do SVG**, sem reamostrar PNG); depois `scripts/strip-png-metadata.py` tira eXIf/tEXt/iTXt/zTXt de todos os PNGs reescrevendo só os chunks (os pixels não são tocados) e o `IconAssetsTests` confere que não voltam e nos glifos `FrostBar*` (via `scripts/render-glyph.swift`, AppKit, fundo transparente; o `qlmanage` não serve para o glifo: sai opaco e sem o desenho) e grava `icone/SHA256SUMS`.
- Verificações (todas em `scripts/check.sh`): `IconAssetsTests` (tamanhos/alfa, **cor média do ícone** clara e menta, não o azul-marinho do Ice, **hashes** dos PNGs iguais ao registro, nenhum arquivo órfão no `.appiconset`, todos os arquivos do `Contents.json` existem), `ControlItemIconMigrationTests` (só `iceCube` vira `frostBar`) e `scripts/check-icon-bundle.swift` (no app compilado, `NSImage.isTemplate == true` e 18x18 pt).
- Histórico: numa primeira versão o gerador gravou o ícone num arquivo `.png` órfão e o `Contents.json` continuou apontando para a arte do Ice; os testes de proveniência acima existem para isso não se repetir.
