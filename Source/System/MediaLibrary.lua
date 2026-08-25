local _, Addon = ...

local FONT_MEDIA = "font"

--- The shared media pool, where every addon that registers a font puts it.
---@class MediaLibrary
local MediaLibrary = {}

---@return table
local function Media()
	return LibStub("LibSharedMedia-3.0")
end

MediaLibrary.GAME_FONT_NAME = "Game Default"

local BUNDLED_LATIN_FONTS = {
	["Inter"] = true,
	["Inter SemiBold"] = true,
	["JetBrains Mono"] = true,
}

--- The bundled fonts have no CJK glyphs, so on those clients they stay out of
--- the shared pool and the picker never offers a font that draws boxes.
---@param name string
---@return boolean
function MediaLibrary.IsBundledLatinFont(name)
	return BUNDLED_LATIN_FONTS[name] == true
end

--- Called once at startup, before anything reads a list.
function MediaLibrary.RegisterOwnMedia()
	Media():Register(FONT_MEDIA, MediaLibrary.GAME_FONT_NAME, Addon.ClientFont.GamePath())

	if Addon.ClientFont.PrefersGameFont() then
		return
	end

	Media():Register(FONT_MEDIA, "Inter", [[Interface\AddOns\AuraNameplate\Media\Fonts\Inter-Regular.ttf]])
	Media():Register(FONT_MEDIA, "Inter SemiBold", [[Interface\AddOns\AuraNameplate\Media\Fonts\Inter-SemiBold.ttf]])
	Media():Register(FONT_MEDIA, "JetBrains Mono", [[Interface\AddOns\AuraNameplate\Media\Fonts\JetBrainsMono-Regular.ttf]])
end

---@return PreferenceChoice[]
function MediaLibrary.FontChoices()
	local choices = {}

	for _, name in ipairs(Media():List(FONT_MEDIA)) do
		table.insert(choices, { id = name, label = name })
	end

	return choices
end

--- A font the player picked from an addon they have since removed would come
--- back empty, so the pool's own default stands in.
---@param name string
---@return string
function MediaLibrary.FontPath(name)
	local media = Media()

	return media:Fetch(FONT_MEDIA, name) or media:Fetch(FONT_MEDIA, media:GetDefault(FONT_MEDIA))
end

Addon.MediaLibrary = MediaLibrary
