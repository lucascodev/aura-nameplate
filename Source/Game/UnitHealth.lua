local _, Addon = ...

--- Health is predicted from what the client already knows, the same way the
--- default frames do it, so the number moves with the hit rather than after it.
local USE_PREDICTED = true

local PERCENT_FORMAT = "%.0f%%"

--- The target's health, turned into something drawable.
---
--- Nothing here reads a number. `UnitHealthPercent` with the scale curve and
--- `AbbreviateNumbers` are both callable with classified values and hand back
--- classified results; `string.format` accepts them too. The string that comes
--- out is opaque to the addon and perfectly legible on screen — which is the
--- whole trick.
---
--- Dividing health by its maximum to get a percentage, or slicing thousands off
--- to write "330k", is exactly what raises an error. That is why the game's own
--- formatters do both.
---@class UnitHealthReading : HealthSource
local UnitHealthReading = {}

--- Asked of the client, never of a value. Testing the percentage itself — even
--- just `if not percent` — is a boolean test on a classified number, and that
--- raises an error as surely as doing maths on it would.
---@return boolean
local function HasPercentApi()
	return UnitHealthPercent ~= nil and CurveConstants ~= nil
end

---@param unit string
---@return unknown
local function Percent(unit)
	return UnitHealthPercent(unit, USE_PREDICTED, CurveConstants.ScaleTo100)
end

--- Nossa abreviação, e não a do jogo: `AbbreviateNumbers` troca para M em um
--- milhão, e a diferença entre 1,5M e 1,6M some justamente onde ela importa.
---@param unit string
---@return unknown
local function Shortened(unit)
	return Addon.HealthAbbreviation.Of(UnitHealth(unit))
end

--- A client without the percentage API still writes the shortened number, which
--- is better than a blank line where the health should be.
---@param unit string
---@param format string
---@return HealthReading?
function UnitHealthReading.Text(unit, format)
	local formats = Addon.HealthFormats

	if format == formats.ABBREVIATED or not HasPercentApi() then
		return { primary = Shortened(unit) }
	end

	-- Separadas, e nao concatenadas: quem desenha e' que sabe se ha uma barra
	-- inteira para espalhá-las ou um ponto só onde encaixar as duas.
	if format == formats.BOTH then
		return {
			primary = PERCENT_FORMAT:format(Percent(unit)),
			secondary = Shortened(unit),
		}
	end

	return { primary = PERCENT_FORMAT:format(Percent(unit)) }
end

Addon.UnitHealthReading = UnitHealthReading
