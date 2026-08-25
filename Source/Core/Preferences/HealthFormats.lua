local _, Addon = ...

local L = Addon.L

--- How the target's health is written out.
---
--- The ids live here, next to the labels, because the adapter that reads the
--- client has to name the same three. Splitting them would let the list and the
--- reader drift apart in silence.
---@class HealthFormats
local HealthFormats = {}

HealthFormats.PERCENT = "percent"
HealthFormats.ABBREVIATED = "abbreviated"
HealthFormats.BOTH = "both"

---@type PreferenceChoice[]
HealthFormats.Choices = {
	{ id = HealthFormats.PERCENT, label = L.HEALTH_FORMAT_PERCENT },
	{ id = HealthFormats.ABBREVIATED, label = L.HEALTH_FORMAT_ABBREVIATED },
	{ id = HealthFormats.BOTH, label = L.HEALTH_FORMAT_BOTH },
}

Addon.HealthFormats = HealthFormats
