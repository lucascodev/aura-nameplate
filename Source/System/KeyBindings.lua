local _, Addon = ...

--- Names the game reads out of the global namespace to build its key binding
--- screen. There is no other way in: the binding system predates anything
--- scoped, so the header, the labels and the actions all have to be globals.
BINDING_HEADER_AURANAMEPLATE = Addon.L.BINDING_HEADER
BINDING_NAME_AURANAMEPLATE_TOGGLE = Addon.L.BINDING_TOGGLE
BINDING_NAME_AURANAMEPLATE_OPTIONS = Addon.L.BINDING_OPTIONS

--- Bridges the game's key bindings to the addon.
---
--- Confining the globals to this one file is the point: everything else keeps
--- receiving what it needs instead of reaching for a name in the open.
---@class KeyBindings
local KeyBindings = {}

---@param toggle fun()
---@param openOptions fun()
function KeyBindings.Install(toggle, openOptions)
	AuraNameplate_Toggle = toggle
	AuraNameplate_OpenOptions = openOptions
end

Addon.KeyBindings = KeyBindings
