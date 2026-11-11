# Prints do Trincano (catálogo)

Capturas para a página do Trincano no catálogo da PiluTech. Todas usam uma **fixture**: itens fictícios da barra de menus (Rede, Som, Notas, Backup etc., com glifos genéricos do sistema), sem nenhum app, nome, e-mail ou notificação do usuário. As janelas são capturadas uma a uma (nada da tela real aparece) e os PNGs saem sem metadados.

| Arquivo | O que mostra |
|---|---|
| `01-barra-organizada.png` | Ajustes > Organização: as três seções com os itens fictícios |
| `02-ajustes-gerais.png` | Ajustes > Geral |
| `03-barra-no-notch.png` | A Barra do Trincano ancorada no notch (seção Escondida) |
| `04-barra-do-trincano.png` | A Barra do Trincano comum (seção Sempre escondida) |
| `05-menu-do-trincano.png` | O menu do ícone do Trincano |

## Como gerar de novo

```sh
scripts/capture-prints.sh            # grava em docs/prints/
scripts/capture-prints.sh /outra/pasta
```

O script compila o Debug com outro bundle id (`br.com.pilutech.trincano.capture`, então não toca nas preferências do app instalado) e abre o binário com `TRINCANO_CAPTURE_DIR=<pasta>` e idioma PT-BR. O app captura as cenas e fecha sozinho (cerca de 10 s). A tela com notch é usada quando existe.

## Como funciona (e por que é seguro)

- O modo de captura só existe no build **Debug** (`#if DEBUG`); o Release não contém nada disso.
- Com a variável ligada o app **não** roda o setup real: não há control items, event taps, varredura da barra, importação nem migração de preferências. As varreduras de itens e de imagens têm trava (`CaptureFixture.isActive`).
- Os ajustes ficam nos valores padrão (as preferências não são lidas nem gravadas).
- Uma janela de fundo neutra (gradiente) fica atrás das janelas do Trincano, para o vidro do macOS não refletir o que estiver aberto.
- `screencapture` precisa da permissão de Gravação de Tela do terminal de onde o script roda.
- A tela **Sobre** não entra: ela mostra o nome do autor (crédito GPL).

## Conferir antes de publicar

Abra cada PNG: nada de app real, nome, notificação ou barra de menus. Metadados: `scripts/check-prints.py` (roda sozinho no fim do `capture-prints.sh`) confere que cada PNG só tem os chunks IHDR, sRGB, IDAT e IEND; `strings <png> | grep -iE 'xmp|exif|screenshot'` deve vir vazio.

**O 05 (menu) é diferente dos outros.** As outras quatro cenas são capturadas por janela (`screencapture -l`), então só o conteúdo do Trincano entra. O menu em tracking não se isola por janela, então o 05 é capturado por **região da tela** (`screencapture -R`): tudo que estiver nesse retângulo entra na imagem, inclusive um banner de notificação do sistema, um alerta ou outra janela por cima. Ao regerar, **abra o `05-menu-do-trincano.png` e confira a imagem**; se tiver algo estranho, feche o que for e rode de novo. O `check-prints.py` só vê a estrutura do PNG, não o conteúdo.

Código: `Ice/Utilities/CaptureFixture.swift`, catálogo puro em `Ice/Utilities/Pure/CaptureFixtureCatalog.swift`.
