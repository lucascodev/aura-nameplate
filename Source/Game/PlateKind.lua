local _, Addon = ...

local PLAYER = "player"

--- Qual das cinco placas uma unidade veste.
---
--- Cinco categorias — a própria, jogador aliado, jogador inimigo, NPC aliado,
--- NPC inimigo — porque são as divisões que os jogadores já esperam poder
--- ligar e desligar em separado.
---
--- Toda resposta do cliente pode vir classificada. Quando vem, a unidade cai
--- na categoria de inimigo, que é a mais comum em combate: errar para o lado
--- que o jogador provavelmente quer ver é melhor que sumir com o desenho.
---@class PlateKind
local PlateKind = {}

PlateKind.SELF = "self"
PlateKind.FRIENDLY_PLAYER = "friendlyPlayer"
PlateKind.ENEMY_PLAYER = "enemyPlayer"
PlateKind.FRIENDLY_NPC = "friendlyNpc"
PlateKind.ENEMY_NPC = "enemyNpc"

---@param value any
---@return boolean
local function IsTrue(value)
	return not Addon.Secrets.Is(value) and value == true
end

---@param unit string
---@return string
function PlateKind.Of(unit)
	local okSelf, isSelf = pcall(UnitIsUnit, unit, PLAYER)

	if okSelf and IsTrue(isSelf) then
		return PlateKind.SELF
	end

	local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
	local okFriend, isFriend = pcall(UnitIsFriend, PLAYER, unit)

	local isPerson = okPlayer and IsTrue(isPlayer)
	local isAlly = okFriend and IsTrue(isFriend)

	if isAlly then
		return isPerson and PlateKind.FRIENDLY_PLAYER or PlateKind.FRIENDLY_NPC
	end

	return isPerson and PlateKind.ENEMY_PLAYER or PlateKind.ENEMY_NPC
end

Addon.PlateKind = PlateKind
