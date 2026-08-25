# Documentação

Documentação técnica do Aura Nameplate, para quem vai modificar o código.

| Documento | Assunto |
|---|---|
| [Arquitetura](arquitetura.md) | as camadas e a regra de dependência |
| [Fluxo de execução](fluxo.md) | inicialização, gravação de uma magia e desenho |
| [Restrições da API](restricoes-api.md) | valores secretos, o que dá para desenhar e o que não dá |
| [Desenvolvimento](desenvolvimento.md) | ambiente, testes, empacotamento e publicação |

## Resumo

O addon escuta os lançamentos do jogador, guarda o último de cada origem em Lua
puro e desenha um ícone ancorado no nameplate do alvo, com a vida dele escrita ao
lado. Tanto a varredura da recarga quanto o texto de vida são alimentados com
valores que o addon nunca lê — o cliente aceita valores classificados nessas
chamadas, e é isso que faz os dois recursos sobreviverem às restrições
introduzidas na 12.0.

## O projeto em números

| | |
|---|---|
| Arquivos Lua carregados pelo jogo | 66, sendo 61 nossos e 5 de bibliotecas |
| Linhas no `Core/`, sem uma única API do jogo | ~1.200 |
| Contratos em `Source/Ports/` | 15 |
| Eventos do jogo escutados | 13 |
| Preferências | 44 |
| Testes rodando fora do cliente | 157 |
