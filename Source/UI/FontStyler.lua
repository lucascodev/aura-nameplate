local _, Addon = ...

--- The countdown a Cooldown draws is the client's own font string, and the only
--- supported way in is to hand it the name of a font object. One is created
--- here and rewritten in place, so every icon that asks follows the same
--- choice without a font object per frame.
local COUNTDOWN_FONT_NAME = "AuraNameplateCountdownFont"
local countdownFont = CreateFont(COUNTDOWN_FONT_NAME)

---@class FontStyler
local FontStyler = {}

--- A font removed with the addon that registered it leaves a path the client
--- refuses, and SetFont says so instead of erroring. Falling back keeps the
--- number readable rather than invisible.
---@param cooldown table
---@param path string
---@param size number
---@param flags string
function FontStyler.ApplyCountdown(cooldown, path, size, flags)
	if not countdownFont:SetFont(path, size, flags) and STANDARD_TEXT_FONT then
		-- Só com um caminho de verdade: passar nil aqui levanta erro.
		countdownFont:SetFont(STANDARD_TEXT_FONT, size, flags)
	end

	cooldown:SetCountdownFont(COUNTDOWN_FONT_NAME)
end

Addon.FontStyler = FontStyler
