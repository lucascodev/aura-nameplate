# Changelog

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o
projeto usa [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [0.3.0] - 2026-08-26

### Alterado

- As auras ganharam página própria nas opções, **Auras**, logo abaixo de Vida —
  antes moravam no fim da página de Vida.

### Corrigido

- O tamanho do ícone das auras passa a valer na hora, em combate inclusive.
  Antes só os botões criados depois da mudança nasciam no tamanho novo; os que
  o jogo já tinha ficavam do tamanho antigo até um `/reload`. Em combate o
  cliente proíbe mexer num botão que está mostrando aura, então a fileira é
  recriada com o tamanho novo assim que o controle para de mexer.

## [0.2.0] - 2026-08-25

### Adicionado

- Logo própria no lugar do ícone emprestado do jogo: na lista de addons, no
  botão de minimapa e no cabeçalho da página principal e da apresentação.
- Publicação na CurseForge, pelo mesmo empacotador que monta o zip do GitHub.

## [0.1.0] - 2026-08-25

Primeira versão.

### Adicionado

- Ícone da última magia conjurada, ancorado na placa do alvo, com a varredura
  da recarga global por cima e a contagem regressiva no meio. Cinco lados de
  ancoragem com deslocamentos em pixels; largura, altura, opacidade, borda com
  cor própria; fonte, tamanho e contorno escolhidos entre as fontes
  registradas no acervo compartilhado. Passar o mouse abre o tooltip da magia
  sem roubar o clique da placa.
- Vida escrita em todas as placas na tela, em porcentagem, abreviada (330K)
  ou as duas juntas — e em K até 100 milhões (1500K), com regras próprias de
  abreviação. O jogo não deixa mais os addons lerem o número, então ele é
  mostrado sem nunca ser lido; por isso a cor é fixa.
- Nome subido para cima da barra e alinhado à esquerda, com fundo próprio de
  cor, opacidade e altura ajustáveis. É a única coisa que move algo desenhado
  pelo jogo: desligar de volta precisa de um `/reload`.
- Fileira de auras própria, no lugar da que o jogo desenha, com filtro
  (incluindo positivos e negativos juntos), lado, tamanho, espaçamento e
  quantidade. Os ícones continuam desenhados pelo jogo, com tooltip ao passar
  o mouse: os dados de aura são fechados para addons.
- Página **Placas**: os interruptores do próprio jogo, por categoria —
  jogadores, NPCs, mascotes, totens e guardiões, de cada lado — semeados da
  sua configuração atual na primeira execução e escritos pelo nome que cada
  versão do cliente conhece. Placas empilhadas na multidão e aliados que saem
  da frente em combate e voltam quando a luta acaba.
- Avatares nas placas, por categoria e desligados por padrão, com tamanho e
  lado ajustáveis.
- **Quadros** próprios de jogador, alvo, foco e alvo do alvo: barras de vida e
  recurso, avatar, nome com reticências, cor de classe ou fixa por quadro,
  clique para mirar, modo de edição para posicionar (`/anp mover`) e a opção
  de esconder os quadros equivalentes da Blizzard.
- Três modos de exibição — sempre, só em combate ou só com alvo — separados
  para o ícone e para a vida; tempo de retenção configurável; posição livre e
  arrastável quando não há placa; modo de teste (`/anp teste`).
- Assistente de boas-vindas em seis etapas temáticas, com prévia que responde
  às escolhas na hora; abre uma vez e pode ser reaberto pelas opções ou por
  `/anp boas-vindas`.
- Autoteste (`/anp diag`) que percorre o mesmo caminho do desenho e diz onde
  ele parou: API ausente, quem é o alvo, chaves reais do cliente, estado dos
  véus, avatares e cada etapa do redesenho.
- Perfis de configuração, um ativo por personagem, com criar, copiar e
  excluir; botão de minimapa e atalhos de teclado.
- Interface em seis idiomas: inglês, português, espanhol, francês, chinês
  simplificado e chinês tradicional.
