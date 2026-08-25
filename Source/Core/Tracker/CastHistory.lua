local _, Addon = ...

--- The last spell recorded for each slot, and for how long it still counts.
---
--- A slot is whoever cast: "player", or the token of the unit a nameplate
--- belongs to. Keeping them apart is what lets the display prefer the freshest
--- one without either source knowing the other exists.
---
--- Time arrives as a parameter. Nothing here calls the client, so the whole
--- expiry rule is testable by handing it a number.
---@class CastHistory
---@field private casts table<string, CastEvent>
---@field private holdDuration fun(): number
local CastHistory = {}
CastHistory.__index = CastHistory

CastHistory.PLAYER_SLOT = "player"

---@param holdDuration fun(): number Seconds a cast stays on screen, read when asked.
---@return CastHistory
function CastHistory.New(holdDuration)
	return setmetatable({ casts = {}, holdDuration = holdDuration }, CastHistory)
end

---@param cast CastEvent
function CastHistory:Record(cast)
	self.casts[cast.slot] = cast
end

--- The freshest cast among the slots given, ignoring anything already past its
--- hold. Expired entries are dropped as they are found: a nameplate that comes
--- and goes would otherwise leave one behind for the rest of the session.
---@param slots string[]
---@param now number
---@return CastEvent?
function CastHistory:Newest(slots, now)
	local hold = self.holdDuration()
	local newest

	for _, slot in ipairs(slots) do
		local cast = self.casts[slot]

		if cast then
			if now - cast.castAt >= hold then
				self.casts[slot] = nil
			elseif not newest or cast.castAt > newest.castAt then
				newest = cast
			end
		end
	end

	return newest
end

---@param slot string
function CastHistory:Forget(slot)
	self.casts[slot] = nil
end

function CastHistory:Wipe()
	self.casts = {}
end

Addon.CastHistory = CastHistory
