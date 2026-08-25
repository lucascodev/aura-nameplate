local _, Addon = ...

--- Uma leitura de vida de mentira, para prévias.
---
--- Nada é perguntado ao jogo: a prévia precisa desenhar antes de existir alvo, e
--- perguntar a vida de ninguém devolveria valor classificado que ela não pode
--- ler. Os números são fixos e do caso mais largo de propósito — quem alinha a
--- linha de vida precisa ver quanto espaço ela vai ocupar, não o texto mais
--- curto que ela pode escrever.
---@class SampleReading
local SampleReading = {}

local PERCENT = "85%"
local ABBREVIATED = "330K"

---@param format string
---@return HealthReading
function SampleReading.Health(format)
	local formats = Addon.HealthFormats

	if format == formats.ABBREVIATED then
		return { primary = ABBREVIATED }
	end

	if format == formats.BOTH then
		return { primary = PERCENT, secondary = ABBREVIATED }
	end

	return { primary = PERCENT }
end

Addon.SampleReading = SampleReading
