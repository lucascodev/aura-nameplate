local _, Addon = ...

local Keys = Addon.PreferenceKeys

local GAP = 4

--- Above whatever the client draws into the bar itself.
local FRAME_LEVEL_LIFT = 10

--- O avatar da unidade, ao lado da placa — de toda placa, não só da pessoal.
---
--- `SetPortraitTexture` devolve o retrato redondo que os quadros do jogo usam,
--- desenhado pelo cliente para qualquer unidade que tenha placa.
---
--- Um distintivo por frame de placa, nunca por unidade: o cliente recicla um
--- conjunto fixo de placas, então a tabela para de crescer sozinha. O retrato é
--- repintado quando a placa troca de dono ou quando o cliente avisa que a foto
--- envelheceu — pintar a cada redesenho renderizaria o modelo em todo evento.
---@class PortraitLayout
---@field private hosts HostSource
---@field private preferences Preferences
---@field private badges table<table, table> Por frame de placa.
local PortraitLayout = {}
PortraitLayout.__index = PortraitLayout

---@param hosts HostSource
---@param preferences Preferences
---@return PortraitLayout
function PortraitLayout.New(hosts, preferences)
	local layout = setmetatable({
		hosts = hosts,
		preferences = preferences,
		badges = setmetatable({}, { __mode = "k" }),
	}, PortraitLayout)

	-- O cliente diz qual unidade envelheceu; só ela é repintada.
	local listener = CreateFrame("Frame")
	listener:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	listener:SetScript("OnEvent", function(_, _, unit)
		layout:Repaint(unit)
	end)

	return layout
end

--- Pinta e guarda o motivo quando não deu: engolir sem registrar deixa "não
--- desenhou" e "estourou" com a mesma cara na tela.
---@private
---@param badge table
function PortraitLayout:Paint(badge)
	if not SetPortraitTexture then
		self.failure = Addon.L.DIAG_MISSING
		return
	end

	local ok, failure = pcall(SetPortraitTexture, badge.texture, badge.unit)

	self.failure = not ok and tostring(failure) or nil
end

---@private
---@param unit string?
function PortraitLayout:Repaint(unit)
	if type(unit) ~= "string" or Addon.Secrets.Is(unit) then
		return
	end

	for _, badge in pairs(self.badges) do
		if badge.isShown then
			local ok, isSame = pcall(UnitIsUnit, badge.unit, unit)

			if ok and not Addon.Secrets.Is(isSame) and isSame == true then
				self:Paint(badge)
			end
		end
	end
end

---@private
---@param owner table O frame da placa.
---@return table
function PortraitLayout:Badge(owner)
	if not self.badges[owner] then
		local frame = CreateFrame("Frame", nil, owner)
		local texture = frame:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()

		self.badges[owner] = { frame = frame, texture = texture }
	end

	return self.badges[owner]
end

--- O interruptor de cada categoria, na chave dela.
local SWITCH_BY_KIND = {
	self = Keys.PORTRAIT_ON_SELF,
	friendlyPlayer = Keys.PORTRAIT_ON_FRIENDLY_PLAYERS,
	enemyPlayer = Keys.PORTRAIT_ON_ENEMY_PLAYERS,
	friendlyNpc = Keys.PORTRAIT_ON_FRIENDLY_NPCS,
	enemyNpc = Keys.PORTRAIT_ON_ENEMY_NPCS,
}

---@private
---@param unit string
---@return boolean
function PortraitLayout:Allows(unit)
	local switch = SWITCH_BY_KIND[Addon.PlateKind.Of(unit)]

	return switch ~= nil and self.preferences:Get(switch) == true
end

--- Uma passada por todas as placas permitidas. O que não foi desenhado nesta
--- rodada é escondido: uma placa que o cliente reciclou carregaria o rosto da
--- unidade anterior.
function PortraitLayout:Refresh()
	local preferences = self.preferences
	local drawn = {}

	local size = preferences:Get(Keys.PORTRAIT_SIZE)
	local isRight = preferences:Get(Keys.PORTRAIT_SIDE) == "right"

	for _, host in ipairs(self.hosts:Nameplates()) do
		if self:Allows(host.unit) then
			local badge = self:Badge(host.frame)
			local frame = badge.frame

			frame:SetSize(size, size)
			frame:SetFrameLevel(host.frame:GetFrameLevel() + FRAME_LEVEL_LIFT)
			frame:ClearAllPoints()

			if isRight then
				frame:SetPoint("LEFT", host.frame, "RIGHT", GAP, 0)
			else
				frame:SetPoint("RIGHT", host.frame, "LEFT", -GAP, 0)
			end

			-- Repintado quando o dono muda ou quando esteve escondido: o mesmo
			-- token pode voltar apontando para outra criatura, e a foto antiga
			-- seria de um rosto que já saiu da tela.
			if badge.unit ~= host.unit or not badge.isShown then
				badge.unit = host.unit
				self:Paint(badge)
			end

			badge.isShown = true
			frame:Show()
			drawn[badge] = true
		end
	end

	local count = 0

	for _ in pairs(drawn) do
		count = count + 1
	end

	self.drawnCount = count

	for _, badge in pairs(self.badges) do
		if not drawn[badge] then
			badge.isShown = false
			badge.frame:Hide()
		end
	end
end

--- Quantos rostos esta passada desenhou, e o que impediu o último quando algo
--- impediu.
---@return { count: number, failure: string? }
function PortraitLayout:Inspect()
	return { count = self.drawnCount or 0, failure = self.failure }
end

Addon.PortraitLayout = PortraitLayout
