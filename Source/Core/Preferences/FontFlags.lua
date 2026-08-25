local _, Addon = ...

local L = Addon.L

--- The flag string the font API takes, offered as a list the player can read.
---@class FontFlags
local FontFlags = {}

---@type PreferenceChoice[]
FontFlags.Choices = {
	{ id = "none", label = L.FONT_FLAG_NONE },
	{ id = "OUTLINE", label = L.FONT_FLAG_OUTLINE },
	{ id = "THICKOUTLINE", label = L.FONT_FLAG_THICK_OUTLINE },
	{ id = "MONOCHROME", label = L.FONT_FLAG_MONOCHROME },
	{ id = "MONOCHROME,OUTLINE", label = L.FONT_FLAG_MONOCHROME_OUTLINE },
}

--- "none" is the readable id for what the API wants as an empty string.
---@param id string
---@return string
function FontFlags.Resolve(id)
	if id == "none" then
		return ""
	end

	return id
end

Addon.FontFlags = FontFlags
