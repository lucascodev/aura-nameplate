# Changelog

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o
projeto usa [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [0.1.0] - 2026-08-24

Primeira versão.

### Adicionado

- Ícone da última magia lançada, ancorado no nameplate do alvo, com a varredura
  da recarga global por cima e a contagem regressiva no meio.
- Cinco lados de ancoragem — acima, abaixo, esquerda, direita e centro — com
  deslocamento horizontal e vertical em pixels.
- Largura, altura, opacidade, espessura e cor da borda, ou a cor da classe do
  personagem.
- Fonte, tamanho e contorno da contagem regressiva, escolhidos entre as fontes
  registradas no acervo compartilhado.
- Vida escrita em **todos os nameplates na tela**, mirados ou não, em
  porcentagem, abreviada (330k) ou as duas juntas, com lado de ancoragem,
  deslocamento, tamanho e cor próprios. O jogo não deixa mais os addons lerem o
  número, então ele é mostrado sem nunca ser lido — e por isso a cor é fixa, e
  não muda conforme a vida cai.
- Nome subido para cima da barra de vida e alinhado à esquerda, em todos os
  nameplates, com fundo próprio — sólido até a metade e desvanecendo até sumir
  na borda direita, com cor, opacidade e altura ajustáveis. É a única coisa no addon que move algo desenhado pelo jogo:
  desligá-la de volta precisa de um `/reload` para desfazer.
- Três modos de exibição — sempre, só em combate ou só com alvo — escolhidos
  separadamente para o ícone e para a vida. A vida vem como **sempre**: ela
  interessa assim que você mira algo, tendo luta ou não.
- Tempo de retenção configurável, de 1 a 15 segundos.
- Posição livre e arrastável, para quando não há nameplate segurando o ícone.
- Modo de teste (`/anp teste`), que fixa um ícone de exemplo para alinhamento
  sem precisar de alvo.
- Fonte secundária, desligada por padrão, para magias conjuradas com barra por
  outras unidades. Desenha o que o cliente informa e cala no resto.
- Fileira de auras própria, no lugar da que o jogo desenha no topo da placa,
  com filtro, lado, deslocamento, tamanho, espaçamento e quantidade ajustáveis.
  Os ícones continuam desenhados pelo jogo, via `CustomAuraContainerTemplate`:
  os dados de aura são classificados, então nenhum addon consegue desenhá-los.
- Autoteste (`/anp diag`), que percorre o mesmo caminho do desenho e diz onde
  ele para: API ausente, alvo, nameplate recusado, leitura de vida e o estado de
  cada frame.
- Perfis de configuração, um ativo por personagem, com criar, copiar e apagar.
- Botão de minimapa, via LibDataBroker, e atalhos de teclado para alternar o
  ícone e abrir as opções.
- Painel de opções próprio, com páginas de Aparência, Comportamento e Perfis.
- Interface em inglês, português, espanhol e francês.
