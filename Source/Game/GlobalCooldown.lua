local _, Addon = ...

--- The spell the client files the global cooldown under. Reading any other
--- would give that spell's own cooldown instead.
local GLOBAL_COOLDOWN_SPELL = 61304

--- The global cooldown, handed on without ever being read.
---
--- start and duration may come back classified, and that is fine: they go
--- straight into Cooldown:SetCooldown, which takes secret values. Comparing
--- them, or doing maths on them to find out how much is left, is what would
--- raise an error — so nothing here does.
---@class GlobalCooldown : CooldownSource
local GlobalCooldown = {}

---@return CooldownReading?
function GlobalCooldown.Read()
	local info = C_Spell.GetSpellCooldown(GLOBAL_COOLDOWN_SPELL)

	if not info then
		return nil
	end

	return { start = info.startTime, duration = info.duration }
end

Addon.GlobalCooldown = GlobalCooldown
