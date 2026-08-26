# Desenvolvimento

## Preparar

```sh
git clone <repo>
cd aura-nameplate
```

`Libs/` **não está no repositório**. As cinco bibliotecas são buscadas na origem
declarada em [`.pkgmeta`](../.pkgmeta) na hora do release, então um clone limpo
não roda no jogo até você trazê-las:

```sh
# com o empacotador instalado
release.sh -d -z
```

Ou baixe as cinco manualmente para `Libs/`, uma vez. Depois disso elas ficam em
disco e são ignoradas pelo git.

Para desenvolver com o jogo aberto, crie uma junção (não precisa de
administrador) em `World of Warcraft\_retail_\Interface\AddOns\` chamada
`AuraNameplate`, apontando para a pasta do projeto. O jogo só carrega
`<Pasta>\<Pasta>.toc`, então o nome da junção precisa bater com o manifesto.

## Testar

```sh
lua Tests/Run.lua              # todas as suítes
lua Tests/Run.lua Tracker      # só as de Tests/Core/Tracker/
```

Testes sobre o `Core/`, em Lua puro, sem dependências. O harness carrega
`Locales/`, `Source/Core/` e dois arquivos puros de `Source/Options/Components/`
(Theme e Schematic, que não tocam API do jogo) na mesma ordem do `.toc` e
simula o vararg que o jogo passa para cada arquivo. Retorna código 1 se algum
teste falhar.

`Tests/` espelha o interior de `Source/`: cada suíte fica no caminho equivalente
ao do módulo que exercita. Fakes e construtores compartilhados vivem em
[`Tests/Support.lua`](../Tests/Support.lua); o carregamento e as asserções, em
[`Tests/Harness.lua`](../Tests/Harness.lua).

Cobertura: histórico de magias e expiração, geometria e aparência do ícone,
visibilidade, o ciclo inteiro de desenho contra um renderizador falso, perfis,
preferências, listas de escolha, comandos, e a consistência entre os arquivos de
locale.

Fora de cobertura: tudo que acessa a API do jogo ou cria frames, que só pode ser
verificado no cliente.

Uma suíte não testa uma unidade, e sim a montagem inteira:

- **`Tests/Bootstrap.lua`** carrega todo arquivo do `.toc` contra um cliente
  falso ([`Tests/ClientStub.lua`](../Tests/ClientStub.lua)) e dispara
  `ADDON_LOADED` e `PLAYER_LOGIN`. É o único teste que exercita o composition
  root, e pega a classe de erro que nenhum teste de unidade alcança: uma ordem
  de linhas em que algo redesenha antes de os objetos existirem.

Outras duas não testam código, e sim o projeto:

- **`Tests/Package.lua`** cruza o `.toc` com o disco nos dois sentidos. Roda no
  CI, em Linux, onde o `build.ps1` não roda.
- **`Tests/Options/Pages.lua`** garante que toda preferência com painel aparece
  exatamente na página dela, e em nenhuma outra.

## Analisar

```sh
luacheck .
```

A configuração está em [`.luacheckrc`](../.luacheckrc), com os globais do jogo
declarados como somente leitura e os que o addon escreve separados. Roda no CI a
cada push.

## Empacotar

```powershell
.\build.ps1
```

Gera `dist\AuraNameplate-<versão>.zip` com a pasta `AuraNameplate` na raiz. O
script valida o `.toc` **nos dois sentidos**:

- arquivo listado que não foi empacotado, o que falharia no cliente do jogador
  sem indicar a causa
- arquivo empacotado que não está listado, que nunca carrega e dá a impressão de
  que o recurso não foi implementado

`Ports/`, `Media/source/`, `Tests/` e `docs/` ficam de fora do pacote: o
primeiro contém apenas anotações de tipo, o segundo guarda a arte editável da
logo (SVG e PNG), os outros dois não são carregados pelo jogo.

## Fluxo de trabalho

O repositório segue Git Flow com duas branches permanentes:

- **`main`** — só recebe release. Cada merge nela ganha uma tag `vX.Y.Z`.
- **`develop`** — a integração do dia a dia, e a branch padrão do repositório.

As duas são protegidas: nada de commit direto nem force push, e o CI
(lint + testes) precisa estar verde para qualquer merge.

O caminho de uma mudança:

```sh
git switch develop && git pull
git switch -c feat/minha-mudanca      # ou fix/, docs/, refactor/…
# commits no padrão descrito em Convenções
gh pr create --base develop
```

Feature entra em develop por **squash** — um commit por mudança na história.

O caminho de um release:

```sh
git switch -c release/X.Y.Z develop
# CHANGELOG.md ganha a seção da versão; o ## Version: do .toc acompanha
gh pr create --base main              # merge commit, não squash
git tag vX.Y.Z && git push --tags     # dispara o release.yml
gh pr create --base develop --head main   # a main volta para a develop
```

Correção urgente sai de `hotfix/*` a partir da main e volta para a develop
pelo mesmo caminho.

## Publicar

```sh
git tag v0.1.0
git push --tags
```

A tag dispara [`release.yml`](../.github/workflows/release.yml), que roda o
empacotador padrão da comunidade de addons (a action referenciada no próprio
workflow): busca as bibliotecas, aplica o `.pkgmeta`, monta o zip e publica no
GitHub Releases e nas vitrines configuradas.

Cada vitrine precisa de duas coisas, um identificador no `.toc` e um token nos
secrets do repositório:

| Vitrine | `.toc` | Secret |
| --- | --- | --- |
| CurseForge | `## X-Curse-Project-ID` | `CF_API_KEY` |
| Wago Addons | `## X-Wago-ID` | `WAGO_API_TOKEN` |

O identificador da CurseForge já está no `.toc`; o do Wago ainda não, porque o
projeto precisa ser criado no site primeiro. Faltando qualquer um dos dois, o
packager pula aquela vitrine e segue — o release não falha, e o zip continua
sendo publicado no GitHub.

A imagem do projeto nas vitrines é
[`Media/source/logo-512-curseforge.png`](../Media/source/logo-512-curseforge.png),
com fundo escuro; a versão transparente ao lado serve para o README e para
fundos claros. Dentro do jogo, a lista de addons, o botão de minimapa e os
cabeçalhos das opções usam `Media/Logo.tga`, e o único lugar que conhece esse
caminho é o `## IconTexture:` do `.toc`: o `AddonMetadata` o lê de lá.

## Convenções

**Commits** em [Conventional Commits](https://www.conventionalcommits.org/), em
português: `feat:`, `fix:`, `refactor:`, `test:`, `build:`, `chore:`, `style:`.

**Comentários** explicam a decisão, não o que a linha faz. Um bloco que precisa
de comentário para ser entendido normalmente deveria ser extraído para uma
função com nome descritivo. Código em inglês; textos visíveis ao jogador em
`Locales/`.

**Indentação** com tab, conforme o [`.editorconfig`](../.editorconfig). Finais de
linha normalizados em LF pelo [`.gitattributes`](../.gitattributes).

**Textos** não ficam literais no código. Uma chave nova entra em
`Locales/enUS.lua` **e** nas cinco traduções. Há um teste que falha se uma delas
faltar, ou se a contagem de `%s` divergir.

**Valores do jogo** passam por [`Game/Secrets.lua`](../Source/Game/Secrets.lua)
antes de serem comparados, medidos ou usados como chave. Ler
[restricoes-api.md](restricoes-api.md) antes de escrever qualquer coisa em
`Source/Game/`.

## Versão

A versão é declarada em um único lugar, o `## Version:` do `.toc`. O `build.ps1`
usa esse valor para nomear o zip, e o `AddonMetadata` o lê para exibir nas
opções e no `/anp status`.
