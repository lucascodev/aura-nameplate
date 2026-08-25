local _, Addon = ...

local L = Addon.L

--- When the icon is allowed on screen at all.
---@class VisibilityModes
local VisibilityModes = {}

VisibilityModes.ALWAYS = "always"
VisibilityModes.COMBAT = "combat"
VisibilityModes.TARGET = "target"

---@type PreferenceChoice[]
VisibilityModes.Choices = {
	{ id = VisibilityModes.ALWAYS, label = L.VISIBILITY_ALWAYS },
	{ id = VisibilityModes.COMBAT, label = L.VISIBILITY_COMBAT },
	{ id = VisibilityModes.TARGET, label = L.VISIBILITY_TARGET },
}

Addon.VisibilityModes = VisibilityModes
