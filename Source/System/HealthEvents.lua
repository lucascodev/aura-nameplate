local _, Addon = ...

--- Health moves on its own events, far more often than anything that moves the
--- icon. Keeping them in their own funnel means a hit landing on a unit does not
--- drag the whole icon refresh along with it.
---
--- A pull of forty mobs raises these constantly, so a burst collapses into one
--- redraw instead of one per hit.
local REFRESH_DELAY = 0.1

local EVENTS = {
	"UNIT_HEALTH",
	"UNIT_MAXHEALTH",
}

---@class HealthEvents
---@field private onChanged fun()
---@field private isScheduled boolean
local HealthEvents = {}
HealthEvents.__index = HealthEvents

---@param onChanged fun()
---@return HealthEvents
function HealthEvents.New(onChanged)
	return setmetatable({ onChanged = onChanged, isScheduled = false }, HealthEvents)
end

---@private
function HealthEvents:Schedule()
	if self.isScheduled then
		return
	end

	self.isScheduled = true
	C_Timer.After(REFRESH_DELAY, function()
		self.isScheduled = false
		self.onChanged()
	end)
end

function HealthEvents:Start()
	local listener = CreateFrame("Frame")

	-- Unfiltered on purpose: every plate on screen carries a health line now, so
	-- every unit's health is worth a redraw. The throttle below is what keeps
	-- that affordable in a room full of them.
	for _, event in ipairs(EVENTS) do
		listener:RegisterEvent(event)
	end

	listener:SetScript("OnEvent", function()
		self:Schedule()
	end)
end

Addon.HealthEvents = HealthEvents
