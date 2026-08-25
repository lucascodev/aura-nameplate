local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Tira as placas aliadas da frente enquanto a luta durar.
---
--- Num campo de batalha as placas se acumulam, e aliado no meio de inimigo
--- vira uma parede em que não dá para saber onde clicar. O que importa em
--- combate é o inimigo; o aliado volta sozinho quando a luta acaba.
---
--- As preferências não são tocadas: o silêncio é escrito direto no cliente, e
--- o fim do combate reaplica o perfil inteiro — a escolha do jogador continua
--- sendo a fonte da verdade.
---@class CombatPlates
---@field private preferences Preferences
---@field private applyProfile fun()
local CombatPlates = {}
CombatPlates.__index = CombatPlates

---@param preferences Preferences
---@param applyProfile fun() Reaplica as chaves do perfil no cliente.
---@return CombatPlates
function CombatPlates.New(preferences, applyProfile)
	local plates = setmetatable({
		preferences = preferences,
		applyProfile = applyProfile,
	}, CombatPlates)

	local listener = CreateFrame("Frame")

	listener:RegisterEvent("PLAYER_REGEN_DISABLED")
	listener:RegisterEvent("PLAYER_REGEN_ENABLED")
	listener:SetScript("OnEvent", function(_, event)
		-- O estado vem do evento, e não de InCombatLockdown(): no instante em
		-- que PLAYER_REGEN_DISABLED dispara, o lockdown pode ainda responder
		-- false, e decidir por ele mandaria a entrada em combate para o ramo
		-- errado.
		plates.isInCombat = event == "PLAYER_REGEN_DISABLED"
		plates:Refresh()
	end)

	return plates
end

--- Decide pelo estado de agora, e por isso serve tanto para os eventos de
--- combate quanto para o interruptor mudando no meio de um.
function CombatPlates:Refresh()
	local isHiding = self.preferences:Get(Keys.HIDE_FRIENDLY_IN_COMBAT) == true

	-- Fora dos eventos de regeneração — troca de interruptor no meio de uma
	-- luta — o lockdown é a única resposta disponível, e lá ele é confiável.
	local isInCombat = self.isInCombat

	if isInCombat == nil then
		isInCombat = InCombatLockdown()
	end

	if isHiding and isInCombat then
		self.lastAction = "hide"
		Addon.PlateVisibility.HideFriendly(Addon.PlateCVars.Write)
		return
	end

	self.lastAction = "apply"
	self.applyProfile()
end

--- O que a última passada fez, para o autoteste: "hide" escondeu aliados,
--- "apply" devolveu o perfil, "-" nunca rodou.
---@return string
function CombatPlates:LastAction()
	return self.lastAction or "-"
end

Addon.CombatPlates = CombatPlates
