local _, Addon = ...

local WHITE = [[Interface\Buttons\WHITE8X8]]
local STRATA = "HIGH"
local DEFAULT_SIZE = 42
local EDIT_COLOR = { red = 0.95, green = 0.72, blue = 0.25 }

--- Always anchored centre to centre, so what gets saved is a pair of offsets
--- from the middle of the screen and nothing else. Reading the frame's own
--- anchor back would save whatever the drag happened to leave it on, and the
--- next login would place it somewhere else.
local ANCHOR = "CENTER"

--- Where the frame starts before anyone has dragged it: just under the middle
--- of the screen, clear of the character but still where the eyes already are.
local DEFAULT_POSITION = { x = 0, y = -140 }

--- The spot the icon falls back to when no nameplate can hold it.
---
--- It is a frame the player drags, so it saves a point and a pair of offsets,
--- and nothing else. Invisible until there is a reason to grab it: an anchor
--- that eats clicks all session is worse than no anchor.
---@class FloatingAnchor
---@field private frame table
---@field private position table Persisted; the drag writes into it.
local FloatingAnchor = {}
FloatingAnchor.__index = FloatingAnchor

FloatingAnchor.SLOT = "floating"

---@param position table
---@return FloatingAnchor
function FloatingAnchor.New(position)
	local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	frame:SetFrameStrata(STRATA)
	frame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
	frame:SetClampedToScreen(true)

	frame:Show()

	local anchor = setmetatable({ frame = frame, position = position }, FloatingAnchor)

	frame:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		anchor:Remember()
	end)

	anchor:Place()

	return anchor
end

---@private
function FloatingAnchor:Place()
	self.frame:ClearAllPoints()
	self.frame:SetPoint(
		ANCHOR,
		UIParent,
		ANCHOR,
		self.position.x or DEFAULT_POSITION.x,
		self.position.y or DEFAULT_POSITION.y
	)
end

--- Called after a drag, which leaves the frame on whatever anchor the client
--- chose. Measuring the centre and re-placing it puts the frame back on the one
--- anchor this addon saves against.
---@private
function FloatingAnchor:Remember()
	local left, bottom = self.frame:GetLeft(), self.frame:GetBottom()

	if not left or not bottom then
		return
	end

	self.position.x = left + self.frame:GetWidth() / 2 - UIParent:GetWidth() / 2
	self.position.y = bottom + self.frame:GetHeight() / 2 - UIParent:GetHeight() / 2

	self:Place()
end

function FloatingAnchor:ResetPosition()
	self.position.x = DEFAULT_POSITION.x
	self.position.y = DEFAULT_POSITION.y

	self:Place()
end

--- Grabbable and outlined, or inert and invisible. There is no state in
--- between: an anchor you can see but not move is a bug report.
---@param isEditable boolean
function FloatingAnchor:SetEditable(isEditable)
	local frame = self.frame

	frame:EnableMouse(isEditable)
	frame:SetMovable(isEditable)

	-- Nunca escondida: desde que o icone passou a ser filho do que o segura,
	-- esconder esta moldura levaria o icone junto. Sem fundo e sem mouse ela ja
	-- e' invisivel e inerte.
	if not isEditable then
		frame:SetBackdrop(nil)
		return
	end

	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	frame:SetBackdropColor(EDIT_COLOR.red, EDIT_COLOR.green, EDIT_COLOR.blue, 0.15)
	frame:SetBackdropBorderColor(EDIT_COLOR.red, EDIT_COLOR.green, EDIT_COLOR.blue, 0.9)
	frame:Show()
end

--- Sized like the icon it holds, so what the player drags is the area the icon
--- will actually occupy.
---@param width number
---@param height number
function FloatingAnchor:SetSize(width, height)
	self.frame:SetSize(width, height)
end

---@return NameplateHost
function FloatingAnchor:Host()
	return { frame = self.frame, unit = FloatingAnchor.SLOT }
end

Addon.FloatingAnchor = FloatingAnchor
