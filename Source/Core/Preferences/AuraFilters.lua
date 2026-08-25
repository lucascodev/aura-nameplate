local _, Addon = ...

local L = Addon.L

--- Quais auras a nossa fileira aceita.
---
--- Uma escolha pode pedir mais de um filtro — negativos e positivos lado a lado
--- são duas consultas para o cliente, e uma fileira só para quem olha. Por isso
--- o id é resolvido numa lista, e nunca repassado direto: as quatro escolhas
--- antigas continuam guardando a própria string de filtro porque perfis salvos
--- não podem virar lixo, mas quem monta a fileira pergunta aqui.
---@class AuraFilters
local AuraFilters = {}

AuraFilters.OWN_DEBUFFS = "HARMFUL|PLAYER"
AuraFilters.ALL_DEBUFFS = "HARMFUL"
AuraFilters.OWN_BUFFS = "HELPFUL|PLAYER"
AuraFilters.ALL_BUFFS = "HELPFUL"
AuraFilters.OWN_AURAS = "own"
AuraFilters.ALL_AURAS = "all"

--- Negativos antes de positivos: o que ameaça vem primeiro na leitura.
local FILTERS = {
	[AuraFilters.OWN_DEBUFFS] = { "HARMFUL|PLAYER" },
	[AuraFilters.ALL_DEBUFFS] = { "HARMFUL" },
	[AuraFilters.OWN_BUFFS] = { "HELPFUL|PLAYER" },
	[AuraFilters.ALL_BUFFS] = { "HELPFUL" },
	[AuraFilters.OWN_AURAS] = { "HARMFUL|PLAYER", "HELPFUL|PLAYER" },
	[AuraFilters.ALL_AURAS] = { "HARMFUL", "HELPFUL" },
}

local FALLBACK = FILTERS[AuraFilters.OWN_DEBUFFS]

---@type PreferenceChoice[]
AuraFilters.Choices = {
	{ id = AuraFilters.OWN_DEBUFFS, label = L.AURA_FILTER_OWN_DEBUFFS },
	{ id = AuraFilters.ALL_DEBUFFS, label = L.AURA_FILTER_ALL_DEBUFFS },
	{ id = AuraFilters.OWN_BUFFS, label = L.AURA_FILTER_OWN_BUFFS },
	{ id = AuraFilters.ALL_BUFFS, label = L.AURA_FILTER_ALL_BUFFS },
	{ id = AuraFilters.OWN_AURAS, label = L.AURA_FILTER_OWN_AURAS },
	{ id = AuraFilters.ALL_AURAS, label = L.AURA_FILTER_ALL_AURAS },
}

--- Um id salvo por uma versão que oferecia uma escolha que esta não tem
--- devolveria nil e derrubaria a fileira junto.
---@param id string
---@return string[]
function AuraFilters.Resolve(id)
	return FILTERS[id] or FALLBACK
end

Addon.AuraFilters = AuraFilters
