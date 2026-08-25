local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Esconde o quadro do jogador da Blizzard enquanto a placa pessoal faz o
--- papel dele.
---
--- Por alfa, e não por Hide, pela mesma razão da fileira nativa de auras: o
--- quadro do jogador é protegido, e mostrar ou esconder um frame protegido em
--- combate é bloqueado — com o erro saindo em nome do addon. Alfa não é
--- operação protegida: funciona em combate e não contamina nada.
---
--- O mouse é a metade que precisa esperar: um quadro invisível que ainda pega
--- clique é uma armadilha no canto da tela, mas desligar o mouse de frame
--- protegido em combate é bloqueado. Fora de combate desliga na hora; dentro,
--- fica devendo e paga no fim da luta.
---@class PlayerFrameVeil
---@field private preferences Preferences
---@field private isVeiled boolean
---@field private isHooked boolean
---@field private waiter table?
local PlayerFrameVeil = {}
PlayerFrameVeil.__index = PlayerFrameVeil

---@param preferences Preferences
---@return PlayerFrameVeil
function PlayerFrameVeil.New(preferences)
	return setmetatable({
		preferences = preferences,
		isVeiled = false,
		isHooked = false,
	}, PlayerFrameVeil)
end

---@return table?
local function Frame()
	local frame = PlayerFrame

	if type(frame) ~= "table" then
		return nil
	end

	return frame
end

---@private
---@param isEnabled boolean
function PlayerFrameVeil:SetMouse(isEnabled)
	local frame = Frame()

	if not frame then
		return
	end

	if InCombatLockdown() then
		self.pendingMouse = isEnabled
		self:WaitForPeace()

		return
	end

	pcall(frame.EnableMouse, frame, isEnabled)
end

--- Um ouvinte só, vivo apenas enquanto há dívida: registrado o tempo todo,
--- acordaria a cada luta encerrada para não fazer nada.
---@private
function PlayerFrameVeil:WaitForPeace()
	self.waiter = self.waiter or CreateFrame("Frame")

	self.waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.waiter:SetScript("OnEvent", function(waiter)
		waiter:UnregisterEvent("PLAYER_REGEN_ENABLED")

		local owed = self.pendingMouse

		self.pendingMouse = nil

		if owed ~= nil then
			self:SetMouse(owed)
		end
	end)
end

--- O cliente pode mostrar o quadro de novo nas próprias atualizações; o gancho
--- reaplica o alfa, como o OnShow da fileira nativa de auras. Instalado uma
--- vez e guiado pelo estado, porque gancho não tem como ser removido.
---@private
---@param frame table
function PlayerFrameVeil:HookOnce(frame)
	if self.isHooked then
		return
	end

	self.isHooked = true

	pcall(frame.HookScript, frame, "OnShow", function()
		if self.isVeiled then
			pcall(frame.SetAlpha, frame, 0)
		end
	end)
end

--- Escondido quando a placa pessoal está ligada e o jogador pediu a troca:
--- as duas juntas, porque sumir com o quadro sem nada no lugar deixaria a
--- tela sem vida nenhuma do próprio jogador.
function PlayerFrameVeil:Refresh()
	local wanted = self.preferences:Get(Keys.PLATES_SELF) == true
		and self.preferences:Get(Keys.HIDE_PLAYER_FRAME) == true

	if wanted == self.isVeiled then
		return
	end

	local frame = Frame()

	if not frame then
		return
	end

	self.isVeiled = wanted

	if wanted then
		self:HookOnce(frame)
	end

	pcall(frame.SetAlpha, frame, wanted and 0 or 1)
	self:SetMouse(not wanted)
end

Addon.PlayerFrameVeil = PlayerFrameVeil
