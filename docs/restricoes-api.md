# Restrições da API

Este é o documento que explica por que o addon é o que é. Ler antes de propor
qualquer recurso que dependa de saber o que outra unidade fez.

## Valores secretos

A partir do patch 12.0 o cliente pode devolver **valores secretos** para código
de addon. Um valor secreto pode ser guardado numa variável, colocado numa tabela
e passado adiante. Qualquer outra coisa derruba a execução com erro de Lua:

- aritmética
- comparação ou teste booleano
- operador de comprimento (`#`)
- uso como chave de tabela, ou indexação por ele
- chamada como função

A consequência prática: **não dá para decidir nada** a partir de informação de
combate. É esse o objetivo declarado da mudança. O que a Blizzard manteve
possível foi a apresentação — e é aí que este addon vive.

Perguntar antes é a única saída, e há uma API para isso:

```lua
issecretvalue(valor) -- true se o cliente classificou
```

No addon isso mora em um arquivo só, [`Source/Game/Secrets.lua`](../Source/Game/Secrets.lua).
Nenhuma outra camada pergunta, e o `Core/` nunca chega a ver um valor desses.

## O que quebrou, e o que sobrou

| Recurso | Situação |
|---|---|
| `COMBAT_LOG_EVENT_UNFILTERED` | **Registrar o evento dá erro.** Não existe mais para addons |
| `UNIT_SPELLCAST_SUCCEEDED` de outras unidades | Magia instantânea secreta **não gera mais o evento**, para nenhuma unidade além do jogador |
| `UNIT_SPELLCAST_START` / `CHANNEL_START` | Ainda dispara para qualquer unidade; o `spellID` **pode** vir secreto |
| Lançamentos do jogador e de unidades sob comando dele | **Nunca são secretos**, nem em combate |
| `Texture:SetTexture` | **Não aceita** valor secreto |
| `Cooldown:SetCooldown` e afins | **Aceitam** valor secreto |
| `StatusBar:SetValue`, `SetMinMaxValues` | Aceitam valor secreto |
| `FontString:SetText`, `SetFormattedText` | **Aceitam** valor secreto |
| `UnitHealth`, `UnitHealthPercent` | Devolvem valor secreto |
| `AbbreviateNumbers` | Foi para C++ e **aceita** valor secreto, devolvendo string secreta |
| `string.format` | **Aceita** valor secreto |
| `C_NamePlate.GetNamePlateForUnit` | Continua disponível |
| Medir um nameplate (`GetLeft`, `GetTop`…) | **Proibido**: região restrita, e a restrição contagia quem ancora nele |

As duas linhas que decidem o desenho do addon são as do meio da tabela: o ícone
**não** pode ser desenhado a partir de uma magia classificada, mas a varredura da
recarga **pode** ser animada com números que o addon não tem permissão de ler.

## Como o addon aproveita isso

```lua
-- Game/GlobalCooldown.lua: os dois números saem daqui sem serem tocados.
local info = C_Spell.GetSpellCooldown(GLOBAL_COOLDOWN_SPELL)
return { start = info.startTime, duration = info.duration }

-- UI/SpellIconFrame.lua: e entram direto no widget, que aceita secretos.
self.cooldown:SetCooldown(reading.start, reading.duration)
```

Ninguém no caminho subtrai um do outro para saber quanto falta — fazer isso é
exatamente o que estouraria. A contagem regressiva sobre o ícone também é
desenhada pelo próprio `Cooldown`, com `SetHideCountdownNumbers`, e não por uma
`FontString` que o addon atualize.

## A vida do alvo, pelo mesmo caminho

Escrever a vida parece exigir justamente o que é proibido: `vida / vidaMáxima`
para a porcentagem, `vida / 1000` para o "330k". As duas contas estouram.

A saída é não fazer conta nenhuma. O jogo expõe formatadores que **aceitam**
valores classificados e devolvem resultado igualmente classificado, e o
`FontString:SetText` aceita esse resultado:

```lua
-- Game/UnitHealth.lua: a porcentagem sai pronta da curva de escala...
UnitHealthPercent(unit, USE_PREDICTED, CurveConstants.ScaleTo100)

-- ...e o numero curto sai pronto do formatador do proprio jogo.
AbbreviateNumbers(UnitHealth(unit))

-- string.format aceita os dois, e o resultado vai direto para a tela.
("%s  %.0f%%"):format(shortened, percent)
```

Nenhuma dessas linhas lê um número. O addon **mostra** a vida sem nunca **saber**
a vida — e é por isso que uma coisa continua fora de alcance: pintar o texto de
vermelho abaixo de 20%, por exemplo, exigiria comparar, o que estoura. Por isso a
cor do texto de vida é fixa.

`UnitHealthPercent` é recente; um cliente sem ela cai no número curto em vez de
deixar a linha vazia.

### As faixas podem ser suas, a conta nunca

`AbbreviateNumbers(valor)` troca para "M" em um milhão, e "1,5M" apaga a
diferença entre 1,5M e 1,6M — que é justamente o que se lê numa barra de vida.
Corrigir isso parece pedir `valor / 1000`, e aí está a mesma parede de antes.

O caminho que **não** funciona, e por um motivo que só o erro revela:

```lua
-- C_StringUtil.CreateNumericRuleFormatter() existe, o método é FormatNumber,
-- e ele faz exatamente a conta que queremos. Mas:
--   "Secret values are only allowed during untainted execution for this argument."
formatter:FormatNumber(UnitHealth(unit))
```

Ou seja: o formatador de regras aceita valor classificado **só quando quem chama
é o próprio jogo**. Vindo de um addon, nunca. É por isso que todo addon que o usa
apenas o *entrega* ao cliente — `SetDurationText`, `SetFormatter` — e jamais o
chama. Não é estilo, é a única forma possível.

O caminho que funciona é outra função, com um segundo argumento:

```lua
-- Game/HealthAbbreviation.lua
local config = CreateAbbreviateConfig({
	{ breakpoint = 1e8, abbreviation = "M", significandDivisor = 1e6, fractionDivisor = 1 },
	{ breakpoint = 1e3, abbreviation = "K", significandDivisor = 1e3, fractionDivisor = 1 },
})

AbbreviateNumbers(UnitHealth(unit), config)
```

`AbbreviateNumbers` é a exceção: aceita classificado de qualquer origem, e aceita
uma configuração de faixas junto. As faixas são nossas, a conta continua sendo
dele, e ninguém aqui lê o número. `fractionDivisor = 1` é o que tira as casas
decimais — `1500K`, e não `1,5K`.

**Prove a configuração com um número comum.** Um cliente que a aceitasse e a
ignorasse em silêncio devolveria o formato antigo, e a chamada teria "funcionado".
Por isso o módulo formata `1500000` na primeira leitura e exige `1500K` de volta
antes de confiar na configuração.

## O ícone

O ícone, por outro lado, precisa de um id de textura legível. Por isso
[`Game/SpellIcon.lua`](../Source/Game/SpellIcon.lua) confere **duas vezes**: o id
da magia e o id do ícone que ele resolve. Uma magia pode ser legível e o ícone
dela não.

## Duas armadilhas que só aparecem rodando

As duas custaram um ciclo de depuração cada, e nenhuma das duas dá erro visível
por padrão — o cliente vem com `scriptErrors` desligado, então o addon
simplesmente para de desenhar.

### Nunca teste um valor classificado, nem contra `nil`

Formatar, concatenar e passar adiante é permitido. **Comparar não é** — e isso
inclui `valor ~= nil`, `not valor` e `#valor`. A função morre na linha, antes de
qualquer coisa ser desenhada.

O jeito de continuar podendo perguntar "veio alguma coisa?" é o valor viajar
dentro de uma tabela comum:

```lua
-- Game/UnitHealth.lua devolve o envelope, nunca a string solta.
return { text = PERCENT_FORMAT:format(Percent(unit)) }

-- Core/Tracker/HealthDisplay.lua compara o envelope, que e' uma tabela normal.
hasCast = reading ~= nil,
self.renderer:SetText(reading.text)
```

A mesma regra vale dentro de `Source/Game/`: perguntar `if not percent` sobre o
retorno de `UnitHealthPercent` estoura igual. Pergunte pela **API**
(`UnitHealthPercent ~= nil`), nunca pelo valor.

Há um teste que trava isso: em `Tests/Core/Tracker/HealthDisplay.lua`, o valor
da vida chega ao Core como um objeto que levanta erro se for comparado ou
medido. Se alguém reintroduzir a comparação, a suíte quebra antes do jogo.

### Vista o FontString antes de escrever nele

`FontString:SetText` levanta **"Font not set"** se nenhuma fonte foi definida
ainda. Numa função de desenho que define a fonte depois do texto, o erro cai
sempre no mesmo ponto: o desenho morre antes do `SetShown`, e a linha que
consertaria a fonte nunca é alcançada. O resultado é um frame que fica
escondido para sempre, sem nada na tela explicando por quê.

Duas defesas, porque uma só não basta:

- o rótulo nasce com uma fonte qualquer (`SetFontObject(GameFontNormal)`), então
  escrever nele nunca estoura;
- a ordem em `HealthDisplay:Refresh` é vestir e depois escrever, travada por
  um teste que confere a sequência das chamadas.

### O cliente reancora: observe o frame, não corra com ele

Mover algo que a Blizzard desenhou — o nome, a fileira de auras — não se sustenta
por reaplicação em evento. O cliente remonta o layout na própria passada, que
roda **depois** do nosso redesenho, e desfaz o movimento. A ordem não é nossa,
então a corrida está perdida antes de começar.

O que funciona é reagir ao instante certo, e o próprio frame o anuncia:

```lua
container:HookScript("OnShow", Reapply)
container:HookScript("OnSizeChanged", Reapply)
```

Mudar de tamanho é exatamente quando ele acabou de remontar e reancorar. Um
gancho por contêiner, em tabela de chaves fracas porque as placas são
recicladas, e um guarda de reentrância — `SetPoint` não altera tamanho, mas o
frame é de outra pessoa e "em tese não reentra" não é garantia.

**Isso deixou de bastar com as auras**, e o addon parou de disputar: silencia a
fileira nativa e desenha a própria.

Uma nuance importante: "desenhar a própria" **não** significa desenhar os ícones.
Os dados de aura são classificados, então nenhum addon consegue ler o ícone de
uma aura para chamar `SetTexture`. `CustomAuraContainerTemplate` existe para
essa fronteira — o addon escolhe filtro, tamanho, espaçamento, ordem e posição;
o cliente preenche:

```lua
local container = CreateFrame("AuraContainer", nil, bar, "CustomAuraContainerTemplate")
container:AddAuraGroup("auras", "HARMFUL|PLAYER", options)
container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
container:SetUnit(unit)
```

A fileira nativa some por **alfa zero, não por `Hide`**: o cliente a mostra de
novo nas próprias atualizações, e brigar por visibilidade seria a mesma corrida
já perdida por posição. Alfa sobrevive a um `Show`, e o gancho de `OnShow`
reaplica.

O template é recente. Num cliente que não o traga (`C_XMLUtil.GetTemplateInfo`
responde nada), o addon não desenha fileira nenhuma e deixa a nativa em paz —
melhor que meia solução.

### Descubra o campo, não adivinhe o nome

Os campos que a placa publica mudam entre versões. O contêiner de auras não é
`BuffFrame` nem `AuraContainer` nesta: é `UnitFrame.AurasFrame`, entre 35 frames.
O token da unidade deixou de sair em `namePlateUnitToken`.

Conferir uma lista de nomes só sabe responder "não achei" — nunca onde procurar.
O addon tenta a lista conhecida primeiro, por ser barata, e cai numa varredura
por nome quando ela falha, **lembrando** o nome que funcionou: varrer ~35 campos
é barato uma vez e caro a dez redesenhos por segundo com uma dezena de placas.

### Nameplates são regiões restritas: ancore, não meça

Dá para ancorar um frame num nameplate, e o desenho funciona. **Medir é
proibido**, e a restrição é contagiosa: um frame preso a um nameplate também
não pode mais ser medido.

```
Action[FrameMeasurement] failed because[Can't measure restricted regions]
```

Ou seja, `GetLeft`, `GetTop` e `GetWidth` deixam de responder para o nosso
próprio ícone. Nada no desenho depende disso, mas qualquer código que queira se
posicionar lendo a posição atual precisa de outro caminho — e o autoteste
embrulha essas chamadas em `pcall` justamente por isso.

## Placa que não existe não tem conserto

Três rodadas de depuração terminaram no mesmo lugar: **nenhum addon faz uma
nameplate aparecer**. Todo addon de nameplate escuta `NAME_PLATE_UNIT_ADDED` e
veste a placa que o jogo criou; quem decide quais placas existem são os CVars, e
só eles. Quando "o addon não mostra a vida", a primeira pergunta é sempre se o
jogo criou a placa — `/anp diag`, linha "Nameplate".

Três lições específicas, todas pagas:

- **Os nomes dos CVars mudam entre versões.** `nameplateShowFriends` virou
  `nameplateShowFriendlyPlayers`, e a leitura do nome antigo devolve `nil` — o
  interruptor vira enfeite em silêncio. Por isso cada ligação em
  [`PlateVisibility`](../Source/Core/Preferences/PlateVisibility.lua) carrega uma
  lista de nomes, e o adaptador resolve o primeiro que o cliente conhece. A
  lista de nomes reais sai de `ConsoleGetAllCommands`, enumerada pelo diag.

- **"Aliados só com o nome" remove a barra, não a placa.** Com
  `nameplateShowOnlyNameForFriendlyPlayerUnits` ligado, o aliado tem só o nome —
  e a linha de vida desenhada por cima cai no vazio.

- **Há uma categoria de jogador sem chave nenhuma.** Um jogador da facção
  oposta num santuário (`facção=Alliance`, `reação=2`, não atacável, mesma
  fase) não é "aliado" nem "inimigo atacável" — e o cliente não cria placa para
  ele, nem oferece CVar que mude isso. O `(*)` depois do nome marca esses. Não é
  defeito do addon; é o vão entre as duas categorias que o jogo desenha.

## Onde pendurar, e como

A placa base **deixou de publicar** o token da unidade em `namePlateUnitToken`.
Ele agora costuma viver no frame que o cliente monta em cima dela, e vale
procurar em ordem: `plate.namePlateUnitToken`, depois `plate.UnitFrame.unit` e
`.displayedUnit`, e o mesmo em `plate.unitFrame`.

O alvo certo de ancoragem também não é a placa: é a barra dentro dela
(`HealthBarsContainer`, `healthBarsContainer`, `healthBar`, `HealthBar`, nessa
ordem). A placa é um contêiner cujo tamanho tem pouco a ver com o que está na
tela, e ancorar nela faz um deslocamento em pixels significar quase nada.

E o frame é **filho** dessa barra, não apenas ancorado nela. Pendurado em
`UIParent` apontando para a placa, ele desenha — mas vive numa hierarquia
diferente da coisa que segue: outra escala, outra ordem de desenho e nenhum
motivo para sumir quando a placa é reciclada. Virar filho resolve os três de uma
vez, com `SetIgnoreParentScale(true)` para o tamanho ficar em pixels de tela em
vez de herdar a escala da interface.

## Regras ao mexer em frame

- **Checar `IsForbidden()` antes de tocar em frame do cliente.** Chamar qualquer
  coisa em um frame proibido dá erro.
- **Não escrever em frame seguro durante combate.** `SetPoint` e `SetAttribute`
  em frame protegido com `InCombatLockdown()` geram taint.
- Alterações puramente visuais — `SetVertexColor`, `SetAlpha`, `SetScale`,
  `SetFont`, troca de textura — são sempre seguras.

## Como isso deve envelhecer

A lista de magias que o cliente aceita revelar **cresce a cada patch**. A fonte
secundária de `Game/UnitCasts.lua` já está escrita para aproveitar isso sem
mudança: ela desenha o que puder ler e cala no resto.

Ao revisar depois de um patch, os dois lugares para conferir são as notas de API
da versão no Warcraft Wiki e a lista de magias liberadas. Se algo passou a ser
legível, o addon já vai estar mostrando.
