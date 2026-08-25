local _, Addon = ...

--- The stock icon art carries a border baked into the edges. Cropping it is
--- what makes the addon's own border sit flush instead of over a second one.
local ICON_CROP = 0.08
local WHITE = [[Interface\Buttons\WHITE8X8]]

--- Nameplates sit low in the draw order, so an icon meant to read over them
--- has to be lifted out of their strata entirely.
--- Above whatever the client draws into the bar itself.
local FRAME_LEVEL_LIFT = 10

--- De onde o tooltip nasce. À direita do ícone, e não sobre a placa, que é o
--- que se está tentando ler.
local TOOLTIP_ANCHOR = "ANCHOR_RIGHT"

---@class SpellIconFrame : IconRenderer
---@field private frame table
---@field private texture table
---@field private cooldown table
---@field private borderThickness number
---@field private spellID number? De qual magia o tooltip fala.
local SpellIconFrame = {}
SpellIconFrame.__index = SpellIconFrame

---@return SpellIconFrame
function SpellIconFrame.New()
	local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	frame:Hide()

	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	cooldown:SetAllPoints()
	cooldown:SetDrawEdge(false)
	-- The client dims what is under the sweep by default; on an icon this small
	-- that reads as the art having gone missing.
	cooldown:SetSwipeColor(0, 0, 0, 0.7)

	local icon = setmetatable({
		frame = frame,
		texture = texture,
		cooldown = cooldown,
		borderThickness = -1,
	}, SpellIconFrame)

	-- Ver o mouse passar sem interceptar o clique: a placa atrás precisa
	-- continuar selecionável, senão mirar no alvo vira acertar o ícone.
	frame:EnableMouse(true)
	frame:SetMouseClickEnabled(false)
	frame:SetMouseMotionEnabled(true)

	frame:SetScript("OnEnter", function()
		icon:ShowTooltip()
	end)

	frame:SetScript("OnLeave", function()
		icon:HideTooltip()
	end)

	return icon
end

--- Os detalhes da magia, escritos pelo cliente.
---
--- Diferente da aura, aqui a magia é conhecida — fomos nós que rastreamos o
--- conjuro — então basta entregar o id. E ele existe: o adaptador não levanta
--- um conjuro cujo id não tenha passado pela mesma checagem que liberou a arte.
---@private
function SpellIconFrame:ShowTooltip()
	if not self.spellID then
		return
	end

	GameTooltip:SetOwner(self.frame, TOOLTIP_ANCHOR)
	GameTooltip:SetSpellByID(self.spellID)
	GameTooltip:Show()
end

--- Só fecha o que é seu: outro frame pode ter tomado o tooltip enquanto o mouse
--- atravessava, e fechá-lo apagaria a resposta que o jogador está lendo.
---@private
function SpellIconFrame:HideTooltip()
	if GameTooltip:GetOwner() ~= self.frame then
		return
	end

	GameTooltip:Hide()
end

---@param iconID number
---@param spellID number?
function SpellIconFrame:SetIcon(iconID, spellID)
	self.texture:SetTexture(iconID)
	self.spellID = spellID
end

--- The two numbers are handed over exactly as the client gave them. They may be
--- values this addon is not allowed to read, and SetCooldown is one of the few
--- calls that takes those: the sweep runs correctly without anyone here ever
--- learning how much time is left.
---@param reading CooldownReading?
function SpellIconFrame:SetCooldown(reading)
	if not reading then
		self.cooldown:Clear()
		return
	end

	self.cooldown:SetCooldown(reading.start, reading.duration)
end

--- The backdrop is rebuilt only when the thickness actually changed: it is the
--- one call here that reallocates, and the appearance is reapplied on every
--- refresh.
---@private
---@param thickness number
function SpellIconFrame:FitBorder(thickness)
	if thickness == self.borderThickness then
		return
	end

	self.borderThickness = thickness

	if thickness <= 0 then
		self.frame:SetBackdrop(nil)
		return
	end

	self.frame:SetBackdrop({ edgeFile = WHITE, edgeSize = thickness })
end

---@param appearance IconAppearance
function SpellIconFrame:SetAppearance(appearance)
	self.frame:SetSize(appearance.width, appearance.height)
	self.frame:SetAlpha(appearance.alpha)

	self:FitBorder(appearance.borderThickness)

	if appearance.borderThickness > 0 then
		self.frame:SetBackdropBorderColor(
			appearance.borderColor.red,
			appearance.borderColor.green,
			appearance.borderColor.blue,
			1
		)
	end

	self.cooldown:SetDrawSwipe(appearance.showSwipe)
	self.cooldown:SetHideCountdownNumbers(not appearance.showTimerText)
end

---@param path string
---@param size number
---@param flags string
function SpellIconFrame:SetFont(path, size, flags)
	Addon.FontStyler.ApplyCountdown(self.cooldown, path, size, flags)
end

--- Reparented onto the plate, not merely anchored to it.
---
--- Hanging off UIParent and pointing at the plate draws, but leaves the icon
--- living in a different hierarchy from the thing it follows: another scale,
--- another draw order, and no reason to disappear when the plate is recycled.
--- Becoming a child of the bar settles all three at once. The scale is then
--- pinned to the screen instead of inherited, so a size in pixels stays that
--- size wherever the plate happens to be.
---@param host table
---@param placement IconPlacement
function SpellIconFrame:Attach(host, placement)
	local frame = self.frame

	if frame:GetParent() ~= host then
		frame:SetParent(host)

		if frame.SetIgnoreParentScale then
			frame:SetIgnoreParentScale(true)
		end
	end

	frame:SetFrameLevel(host:GetFrameLevel() + FRAME_LEVEL_LIFT)
	frame:ClearAllPoints()
	frame:SetPoint(placement.point, host, placement.relativePoint, placement.x, placement.y)
end

---@param isShown boolean
function SpellIconFrame:SetShown(isShown)
	-- Um ícone que some sob o cursor deixaria o tooltip aberto falando de uma
	-- magia que não está mais na tela.
	if not isShown then
		self:HideTooltip()
	end

	self.frame:SetShown(isShown)
end

--- Onde este frame acabou, para o autoteste. Um frame marcado como visível mas
--- sem coordenada é um ponto de ancoragem que não pegou — a diferença entre
--- "a regra decidiu esconder" e "a regra mandou desenhar e não apareceu".
---@return { isShown: boolean, isMeasurable: boolean, left: number?, top: number?, width: number }
function SpellIconFrame:Inspect()
	-- Um frame ancorado num nameplate herda a restricao dele: medir levanta erro
	-- em vez de responder. O autoteste precisa da resposta, nao do erro.
	local canMeasure, left = pcall(self.frame.GetLeft, self.frame)
	local _, top = pcall(self.frame.GetTop, self.frame)
	local _, width = pcall(self.frame.GetWidth, self.frame)

	return {
		isShown = self.frame:IsShown() == true,
		isMeasurable = canMeasure == true,
		left = canMeasure and left or nil,
		top = canMeasure and top or nil,
		width = canMeasure and width or 0,
	}
end

Addon.SpellIconFrame = SpellIconFrame
