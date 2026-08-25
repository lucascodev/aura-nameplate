local _, Addon = ...

--- A primeira vez que o addon roda nesta instalação.
---
--- A decisão mora fora dos perfis, na raiz do banco. Trocar de perfil, ou criar
--- um para raide, não é instalar o addon de novo — e quem já viu a apresentação
--- não deveria revê-la por isso.
---
--- Não fala com o jogo: recebe a tabela salva e devolve uma resposta, o que
--- deixa a regra testável sem abrir o cliente.
---@class FirstRun
---@field private state table
local FirstRun = {}
FirstRun.__index = FirstRun

---@param database table A raiz do SavedVariables.
---@return FirstRun
function FirstRun.New(database)
	database.welcome = database.welcome or {}

	return setmetatable({ state = database.welcome }, FirstRun)
end

--- Aberta enquanto o jogador não tiver dispensado. Instalação nova chega com a
--- tabela vazia, e é isso que faz a apresentação aparecer uma vez.
---@return boolean
function FirstRun:ShouldGreet()
	return self.state.isDismissed ~= true
end

--- O que a caixa de seleção dizia quando a janela fechou.
---@return boolean
function FirstRun:IsDismissed()
	return self.state.isDismissed == true
end

--- Desmarcar é pedir para rever no próximo login, e é tão válido quanto marcar:
--- a decisão é do jogador, não uma porta que só fecha.
---@param isDismissed boolean
function FirstRun:Remember(isDismissed)
	self.state.isDismissed = isDismissed == true
end

Addon.FirstRun = FirstRun
