# Rodada de design (Fable 5.2, escolhas do Paulo em 09/11/2026)

Canvas: https://claude.ai/artifact/BZG18TuyNFaJoXbjiK6mLi. Escolhas: Barra **B**, Organização **A**, Geral **B**, Busca **A**, Sobre **B**. Só UI, sem mudar regra de negócio. Três PRs em sequência (todos tocam o `Localizable.xcstrings`: mergear na ordem, senão há conflito de catálogo).

## PR 1: Sobre B, Busca A, Organização A, títulos curtos
- **Barra lateral**: pt-BR "Organização" e "Aparência" (eram 29 e 27 caracteres). A chave também é o título da janela, então ele encurta junto. Teste: `sidebarTitlesFitTheSidebarInPortuguese` (≤ 16 caracteres; falhou antes da correção).
- **Sobre**: ficha de procedência (origem, licença, modificado por, código-fonte, outros créditos, privacidade). Valores longos quebram na linha; a barra de 6 botões virou 2 (Relatar um problema, Sair). Em janela baixa a ficha rola.
- **Busca**: contagem no rodapé (`MenuBarSearchSummary`, testada), atalhos ↑↓ ↩ esc sempre visíveis, ação (Clicar/Mostrar item ↩) na linha selecionada, nome longo truncado com tooltip, estado "sem resultados" citando a busca. Nenhuma animação.
- **Organização**: contagem por seção (plural no catálogo), estado vazio ("Arraste itens para cá") e nota de itens atrás do notch na seção Visível (`SectionCountSummary`, testada; só aparece em tela com notch).
- **Não feito (fica para depois)**: marcar cada item atrás do notch dentro do trilho (só há a contagem e a nota).

## Roteiro ao vivo para o Paulo (PR 1)
1. Ajustes em pt-BR: a barra lateral não corta "Organização"/"Aparência".
2. Sobre: os 5 botões de ação abrem o link certo (Ice original, licença, código, créditos).
3. Organização no Air M4: a nota "N itens ficam atrás do notch" aparece só quando há item preso; esvazie uma seção (ou use "Sempre escondida") e veja o convite.
4. Busca (atalho configurado): contagem, filtro sem resultado, setas e Return.

## Prints
`prints/` (tema escuro, app em inglês; o tema claro exige trocar a aparência do sistema, não feito). A Busca depende de atalho configurado e não foi capturada.

## PR 2: Geral B (mapa de telas)
- Com 2 ou mais telas, os pickers por tela viram um **mapa** (`DisplayMapView`, modelo puro `DisplayMapModel`, testado): as telas na proporção e no arranjo do sistema, notch desenhado, seleção por clique/VoiceOver (radio com "selecionado"), detalhe com crossfade (`MotionPolicy`, sem movimento com Reduzir movimento). Com 1 tela nada aparece (igual a hoje).
- **Só o que já é persistido por tela**: `DisplayBarMode` (seguir o geral / Barra / expandir). Os dois toggles de notch do canvas (por tela) **não existem por tela** hoje (são globais) e ficaram como estão, em "Notch": omitidos do mapa, sem campo novo.
- **Identidade (pendência 8, só na UI)**: a lista usa o `displayID` de runtime. Tela sem UUID, ou com UUID repetido, não ganha perfil (o picker some e aparece o texto "sem identificador estável"; segue o geral). O restante da pendência 8 (topologia que exclui tela sem UUID) continua aberto.
- **Homônimas**: nome repetido ganha " · 1", " · 2" e "N de M com este nome"; nome vazio vira "Tela N". Nome longo trunca no meio com tooltip e aparece inteiro (2 linhas) no detalhe.
- Testes: `DisplayMapModelTests` (13 casos: ordem, encaixe, arranjo, tela acima, homônimas, nome vazio, UUID nil/repetido). Vermelho: stub vazio derrubou a suíte; depois a implementação.

### Roteiro ao vivo (precisa de monitor externo)
1. Conectar um monitor: o mapa aparece com 2 telas na ordem do Ajustes do Sistema; o notch só no Air.
2. Trocar o modo de cada tela e confirmar que cada uma guarda o seu (reabrir os Ajustes, desconectar/reconectar).
3. Dois monitores de mesmo modelo: nomes com " · 1"/" · 2".
4. Desconectar a tela selecionada: a seleção volta para a primeira.
5. VoiceOver: cada tela é lida com nome, resolução, "com notch" e "selecionado".
Sem monitor externo não há print do mapa (não foi possível capturar).
