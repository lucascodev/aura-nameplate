local _, Addon = ...

--- What the player casts, and what their pet casts under their orders.
---
--- This is the source that never goes quiet: the client keeps spellcasts by the
--- player and by units the player controls readable, in every kind of content,
--- which is what the whole addon is built on.
---@class PlayerCasts : CastSource
local PlayerCasts = {}
PlayerCasts.__index = PlayerCasts

---@return PlayerCasts
function PlayerCasts.New()
	return setmetatable({}, PlayerCasts)
end

---@param onCast fun(cast: CastEvent)
function PlayerCasts:Start(onCast)
	local listener = CreateFrame("Frame")

	-- Filtered at registration: the unfiltered event fires for every unit in
	-- sight, and throwing those away in Lua costs more than never getting them.
	listener:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")

	listener:SetScript("OnEvent", function(_, _, _, _, spellID)
		local iconID = Addon.SpellIcon.For(spellID)

		if not iconID then
			return
		end

		onCast({
			slot = Addon.CastHistory.PLAYER_SLOT,
			iconID = iconID,
			spellID = spellID,
			castAt = GetTime(),
		})
	end)
end

Addon.PlayerCasts = PlayerCasts
