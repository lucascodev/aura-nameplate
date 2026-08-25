local _, Addon = ...

local NAMEPLATE_TOKEN = "^nameplate%d+$"

--- What everyone else casts, as far as the client is willing to say.
---
--- Only casts with a bar reach here at all: a spell fired off the global
--- cooldown by another unit no longer raises an event for addons. Of those that
--- do arrive, the ones the client has classified are dropped without a word,
--- because there is nothing to draw and no way to ask what they were. That is
--- the deal, and it is why this source is off by default.
---@class UnitCasts : CastSource
local UnitCasts = {}
UnitCasts.__index = UnitCasts

local EVENTS = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_CHANNEL_START",
}

---@return UnitCasts
function UnitCasts.New()
	return setmetatable({}, UnitCasts)
end

---@param onCast fun(cast: CastEvent)
function UnitCasts:Start(onCast)
	local listener = CreateFrame("Frame")

	for _, event in ipairs(EVENTS) do
		listener:RegisterEvent(event)
	end

	listener:SetScript("OnEvent", function(_, _, unit, _, spellID)
		-- Every unit in sight raises these. Only the ones with a nameplate have
		-- somewhere to draw, and the token is a plain string, never classified.
		if type(unit) ~= "string" or not unit:match(NAMEPLATE_TOKEN) then
			return
		end

		local iconID = Addon.SpellIcon.For(spellID)

		if not iconID then
			return
		end

		onCast({ slot = unit, iconID = iconID, spellID = spellID, castAt = GetTime() })
	end)
end

Addon.UnitCasts = UnitCasts
