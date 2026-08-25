local _, Addon = ...

--- Above whatever the client draws into the bar itself.
local FRAME_LEVEL_LIFT = 10

--- Enough to keep the text off the bar's own border.
local INSET = 3

--- One health line hung off a nameplate, in up to two pieces.
---
--- The string handed to SetText may be one the addon is not allowed to read.
--- That is fine: SetText is one of the calls that takes those. Measuring the
--- result afterwards — GetStringWidth to centre it, say — is not, and neither is
--- measuring the bar. That is why filling the bar is done by anchoring its
--- corners rather than by asking how big it is.
---@class HealthTextFrame : TextRenderer
---@field private frame table
---@field private primary table
---@field private secondary table
local HealthTextFrame = {}
HealthTextFrame.__index = HealthTextFrame

---@param frame table
---@return table
local function NewLabel(frame)
	local label = frame:CreateFontString(nil, "OVERLAY")

	-- Uma fonte qualquer, ja: um FontString sem fonte levanta erro em SetText,
	-- e um erro ali derruba o desenho inteiro antes de chegar ao SetShown. A
	-- escolhida pelo jogador entra logo em seguida, a cada refresh.
	label:SetFontObject(GameFontNormal)

	return label
end

---@return HealthTextFrame
function HealthTextFrame.New()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(1, 1)
	frame:Hide()

	return setmetatable({
		frame = frame,
		primary = NewLabel(frame),
		secondary = NewLabel(frame),
	}, HealthTextFrame)
end

--- The second piece is emptied rather than hidden: an empty string draws
--- nothing, and hiding would leave a region to remember to show again.
---@param reading HealthReading
function HealthTextFrame:SetText(reading)
	self.primary:SetText(reading.primary)
	self.secondary:SetText(reading.secondary or "")
end

---@param appearance TextAppearance
function HealthTextFrame:SetAppearance(appearance)
	local color = appearance.color

	self.primary:SetTextColor(color.red, color.green, color.blue)
	self.secondary:SetTextColor(color.red, color.green, color.blue)
end

---@param label table
---@param path string
---@param size number
---@param flags string
local function ApplyFont(label, path, size, flags)
	if not label:SetFont(path, size, flags) and STANDARD_TEXT_FONT then
		-- Só com um caminho de verdade: passar nil aqui levanta erro, e um erro
		-- neste ponto mata o desenho inteiro para trocar uma fonte.
		label:SetFont(STANDARD_TEXT_FONT, size, flags)
	end

	label:SetShadowColor(0, 0, 0, 1)
	label:SetShadowOffset(1, -1)
end

---@param path string
---@param size number
---@param flags string
function HealthTextFrame:SetFont(path, size, flags)
	ApplyFont(self.primary, path, size, flags)
	ApplyFont(self.secondary, path, size, flags)
end

--- Filling the bar: all four corners anchored to it, so the frame ends up
--- exactly as wide and as tall as the bar without anyone asking what those are.
--- The two pieces then sit against opposite ends, vertically centred in the bar
--- because the frame *is* the bar. Anchoring only the sides left the frame one
--- pixel tall on the bar's midline, which is close enough to look right and
--- wrong enough to drift.
---@private
---@param host table
---@param placement IconPlacement
function HealthTextFrame:Spread(host, placement)
	local frame = self.frame

	frame:SetPoint("TOPLEFT", host, "TOPLEFT", placement.x + INSET, placement.y)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", placement.x - INSET, placement.y)

	self.primary:ClearAllPoints()
	self.secondary:ClearAllPoints()
	self.primary:SetPoint("LEFT")
	self.secondary:SetPoint("RIGHT")
	self.primary:SetJustifyH("LEFT")
	self.secondary:SetJustifyH("RIGHT")
end

--- Off the bar there is no width to fill, so the pieces stack side by side from
--- a single point. The second is anchored to the first rather than placed by
--- measurement, which the client would refuse here anyway.
---@private
---@param host table
---@param placement IconPlacement
function HealthTextFrame:Stack(host, placement)
	local frame = self.frame

	frame:SetPoint(placement.point, host, placement.relativePoint, placement.x, placement.y)

	self.primary:ClearAllPoints()
	self.secondary:ClearAllPoints()
	self.primary:SetPoint("LEFT")
	self.secondary:SetPoint("LEFT", self.primary, "RIGHT", INSET * 2, 0)
	self.primary:SetJustifyH("LEFT")
	self.secondary:SetJustifyH("LEFT")
end

--- Reparented onto the plate, not merely anchored to it.
---
--- Hanging off UIParent and pointing at the plate draws, but leaves the text
--- living in a different hierarchy from the thing it follows: another scale,
--- another draw order, and no reason to disappear when the plate is recycled.
--- Becoming a child of the bar settles all three at once.
---@param host table
---@param placement IconPlacement
function HealthTextFrame:Attach(host, placement)
	local frame = self.frame

	if frame:GetParent() ~= host then
		frame:SetParent(host)

		if frame.SetIgnoreParentScale then
			frame:SetIgnoreParentScale(true)
		end
	end

	frame:SetFrameLevel(host:GetFrameLevel() + FRAME_LEVEL_LIFT)
	frame:ClearAllPoints()

	if placement.spansHost then
		self:Spread(host, placement)
		return
	end

	self:Stack(host, placement)
end

---@param isShown boolean
function HealthTextFrame:SetShown(isShown)
	self.frame:SetShown(isShown)
end

--- Onde este frame acabou, para o autoteste. Um frame marcado como visível mas
--- sem coordenada é um ponto de ancoragem que não pegou — a diferença entre
--- "a regra decidiu esconder" e "a regra mandou desenhar e não apareceu".
---@return { isShown: boolean, isMeasurable: boolean, left: number?, top: number?, width: number }
function HealthTextFrame:Inspect()
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

Addon.HealthTextFrame = HealthTextFrame
