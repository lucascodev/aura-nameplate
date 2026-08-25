local _, Addon = ...

--- Whether the icon belongs on screen right now.
---
--- One function with every reason in front of it, instead of the same three
--- checks spread across the frames that would each have to remember them.
---@class IconVisibility
local IconVisibility = {}

--- Test mode is asked for by typing a command, so it answers before anything
--- else: someone lining the icon up is not helped by being told the addon is
--- switched off, or that they are not in combat.
---@param state { isEnabled: boolean, mode: string, hasCast: boolean, hasHost: boolean, hasTarget: boolean, isInCombat: boolean, isTesting: boolean }
---@return boolean
function IconVisibility.IsShown(state)
	if state.isTesting then
		return state.hasHost
	end

	if not state.isEnabled or not state.hasCast or not state.hasHost then
		return false
	end

	local modes = Addon.VisibilityModes

	if state.mode == modes.TARGET then
		return state.hasTarget
	end

	if state.mode == modes.COMBAT then
		return state.isInCombat
	end

	return true
end

Addon.IconVisibility = IconVisibility
