local _, Addon = ...

--- Several of these arrive together when a target changes: the plate is removed,
--- another is added and the target event lands, all in the same frame.
--- Collapsing the burst into one refresh is what keeps the work off the frame
--- budget.
local REFRESH_DELAY = 0.05

local EVENTS = {
	"PLAYER_TARGET_CHANGED",
	"NAME_PLATE_UNIT_ADDED",
	-- The plate a unit was wearing is gone: whatever it had cast has nowhere to
	-- be drawn and no reason to be kept.
	"NAME_PLATE_UNIT_REMOVED",
	-- Uma aura entrando ou saindo faz o cliente remontar a fileira, e remontar
	-- e' quando ele reancora: sem isto os icones voltariam para o topo no
	-- primeiro debuff aplicado depois do nosso reposicionamento.
	"UNIT_AURA",
	-- Both ends of combat matter: the icon can be set to show only inside it.
	"PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_ENTERING_WORLD",
}

--- Turns game events into a single "something changed" signal.
--- Exists so neither the display nor the frames have to know which events
--- matter.
---@class CastEvents
---@field private onChanged fun()
---@field private onUnitGone fun(unit: string)
---@field private isScheduled boolean
local CastEvents = {}
CastEvents.__index = CastEvents

---@param onChanged fun()
---@param onUnitGone fun(unit: string)
---@return CastEvents
function CastEvents.New(onChanged, onUnitGone)
	return setmetatable({
		onChanged = onChanged,
		onUnitGone = onUnitGone,
		isScheduled = false,
	}, CastEvents)
end

---@private
function CastEvents:Schedule()
	if self.isScheduled then
		return
	end

	self.isScheduled = true
	C_Timer.After(REFRESH_DELAY, function()
		self.isScheduled = false
		self.onChanged()
	end)
end

function CastEvents:Start()
	local listener = CreateFrame("Frame")

	for _, event in ipairs(EVENTS) do
		listener:RegisterEvent(event)
	end

	listener:SetScript("OnEvent", function(_, event, unit)
		if event == "NAME_PLATE_UNIT_REMOVED" and type(unit) == "string" then
			self.onUnitGone(unit)
		end

		self:Schedule()
	end)
end

--- A cast that runs out is not an event: nothing in the client fires when the
--- last spell has been on screen long enough. Booking the refresh at the moment
--- it is recorded is what makes the icon leave on its own, without a ticker
--- running all session for the seconds that matter.
---@param seconds number
function CastEvents:ExpireIn(seconds)
	C_Timer.After(seconds, self.onChanged)
end

Addon.CastEvents = CastEvents
