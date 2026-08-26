<p align="center">
  <img src="Media/source/logo-512-transparente.png" alt="Logo do Aura Nameplate" width="128">
</p>

# Aura Nameplate: GCD Tracker

A magia que você acabou de lançar, desenhada no nameplate de quem recebeu, com
a varredura da recarga global por cima e o tempo restante no meio — e a vida do
alvo escrita ao lado, em porcentagem ou abreviada. Em inglês, português,
espanhol e francês.

O olho fica no centro da tela, onde a luta acontece, em vez de descer até a
barra de ação para conferir se o GCD já correu.

## Recursos

- Ícone da última magia no nameplate do alvo, com varredura de recarga e
  contagem regressiva
- Vida escrita em todos os nameplates na tela, mirados ou não: porcentagem
  (85%), abreviada (330k) ou as duas, com posição, tamanho e cor próprios
- Nome levantado para cima da barra e alinhado à esquerda, com fundo que
  desvanece da metade para a direita
- Cinco lados de ancoragem, com deslocamento fino em pixels
- Tamanho, opacidade, espessura e cor da borda, ou a cor da sua classe
- Fonte, tamanho e contorno do tempo, escolhidos entre as fontes que os seus
  addons registram
- Mostrar sempre, só em combate ou só com alvo, escolhido em separado para o
  ícone e para a vida
- Posição livre e arrastável para quando não há nameplate para segurar o ícone
- Modo de teste, para alinhar sem precisar de alvo, e autoteste (`/anp diag`)
  que explica por que algo não está aparecendo
- Perfis de configuração, um ativo por personagem
- Botão de minimapa e atalhos de teclado

## O que o addon mostra, e por quê

O núcleo é **o que você lança**. Desde o patch 12.0 o jogo deixou de entregar aos
addons o registro de combate, e o 12.0.5 fechou o que sobrava: uma magia
instantânea lançada por qualquer unidade que não seja você não gera mais evento
nenhum. Os lançamentos do próprio jogador — e das unidades sob o comando dele,
como o pet — continuam legíveis em todo tipo de conteúdo, e é sobre isso que o
addon é construído.

Há ainda uma fonte secundária, desligada por padrão, para **magias que outras
unidades conjuram com barra**. Ela desenha o que o cliente estiver disposto a
informar e fica em silêncio no resto, sem erro. À medida que a Blizzard amplia a
lista de magias visíveis a cada patch, ela alcança mais coisas sozinha.

O detalhe completo está em [docs/restricoes-api.md](docs/restricoes-api.md).

## Instalação

Extraia o zip em `World of Warcraft\_retail_\Interface\AddOns\`.

Dentro do jogo, `/anp` abre as opções, `/anp teste` fixa um ícone de exemplo
para você alinhar e `/anp ajuda` lista os comandos.

## Desenvolvimento

O código segue Clean Architecture, com a regra de dependência apontando para
dentro:

| Pasta | Responsabilidade |
|---|---|
| `Locales/` | textos, `enUS.lua` como padrão e as traduções por cima |
| `Media/` | fontes e a logo; `source/` guarda a arte editável (SVG e PNG) e fica fora do pacote |
| `Source/Core/` | regras em Lua puro: `Preferences/`, `Tracker/`, `Commands/`. **Nenhuma API do WoW** |
| `Source/Ports/` | contratos de tipo, lidos pelo language server e fora do pacote |
| `Source/Game/` | lê a API do jogo e não desenha nada, incluindo o único lugar que consulta valores secretos |
| `Source/UI/` | frames: o ícone, a âncora do nameplate e a posição livre |
| `Source/Options/` | páginas de opções e o kit `Components/` |
| `Source/System/` | chat, comandos, atalhos, acervo de fontes e o funil de eventos |
| `Source/Bootstrap.lua` | composition root, o único lugar que conhece as implementações |

```sh
lua Tests/Run.lua     # os testes do Core, sem abrir o jogo
luacheck .            # análise estática
.\build.ps1           # gera dist\AuraNameplate-<versão>.zip
```

`Libs/` não está no repositório: o empacotador busca as bibliotecas na origem
declarada em `.pkgmeta`. Um clone limpo não roda no jogo antes de trazê-las.

A documentação completa está em **[docs/](docs/)**:

| | |
|---|---|
| [Arquitetura](docs/arquitetura.md) | as camadas e a regra de dependência |
| [Fluxo de execução](docs/fluxo.md) | inicialização, gravação de uma magia e desenho |
| [Restrições da API](docs/restricoes-api.md) | valores secretos, o que dá para desenhar e o que não dá |
| [Desenvolvimento](docs/desenvolvimento.md) | ambiente, testes, empacotamento e publicação |

## Licença

MIT. As bibliotecas em `Libs/` pertencem a seus autores e mantêm as licenças
próprias.
