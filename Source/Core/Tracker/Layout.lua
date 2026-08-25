local _, Addon = ...

local PERCENT = 100

--- Turns saved preferences into the measurements a renderer can take.
---
--- Plain maths, no frames: the anchor pair, the opacity fraction and the border
--- colour are all decided here, which is why the placement can be checked
--- without opening the game.
---@class IconLayout
local IconLayout = {}

---@param anchorID string
---@param offsetX number
---@param offsetY number
---@return IconPlacement
function IconLayout.Placement(anchorID, offsetX, offsetY)
	local anchor = Addon.AnchorPoints.Resolve(anchorID)

	return {
		point = anchor.point,
		relativePoint = anchor.relativePoint,
		x = offsetX,
		y = offsetY,
		-- Dentro da barra e' o unico lugar onde faz sentido ocupar a largura
		-- dela. Só o texto usa isto; o icone tem tamanho proprio.
		spansHost = anchorID == "center",
	}
end

---@param hex string
---@return { red: number, green: number, blue: number }
function IconLayout.Color(hex)
	local red, green, blue = Addon.HexColor.ToRGB(hex)

	return { red = red, green = green, blue = blue }
end

---@param settings { width: number, height: number, alphaPercent: number, borderThickness: number, borderHex: string, showSwipe: boolean, showTimerText: boolean }
---@return IconAppearance
function IconLayout.Appearance(settings)
	local red, green, blue = Addon.HexColor.ToRGB(settings.borderHex)

	return {
		width = settings.width,
		height = settings.height,
		alpha = settings.alphaPercent / PERCENT,
		borderThickness = settings.borderThickness,
		borderColor = { red = red, green = green, blue = blue },
		showSwipe = settings.showSwipe == true,
		showTimerText = settings.showTimerText == true,
	}
end

Addon.IconLayout = IconLayout
