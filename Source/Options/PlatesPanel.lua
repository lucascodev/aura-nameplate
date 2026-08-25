local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Quais placas o jogo desenha, e não como o addon as decora.
---
--- Elas moram aqui, e não em Comportamento, porque a diferença importa quando
--- algo não aparece: uma chave desta página faz a placa deixar de existir, e
--- nenhuma decoração alcança o que não existe.
---@class PlatesPanel
local PlatesPanel = {}

---@param category table
---@param catalog Preference[]
---@param preferences Preferences
---@return table subcategory
function PlatesPanel.Register(category, catalog, preferences)
	local page = Addon.OptionsPage.New({
		title = Addon.L.PAGE_PLATES,
		subtitle = Addon.L.PAGE_PLATES_HINT,
	})

	page:Mount({
		{
			title = Addon.L.SECTION_PLATES_FRIENDLY,
			rows = {
				{ { key = Keys.PLATES_FRIENDLY_PLAYERS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_FRIENDLY_NPCS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_FRIENDLY_PETS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_FRIENDLY_TOTEMS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_FRIENDLY_GUARDIANS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_FRIENDLY_NAMES_ONLY, span = 2 } },
			},
		},
		{
			title = Addon.L.SECTION_PLATES_ENEMY,
			rows = {
				{ { key = Keys.PLATES_ENEMIES, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_ENEMY_MINIONS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_ENEMY_MINUS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_ENEMY_PETS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_ENEMY_TOTEMS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_ENEMY_GUARDIANS, span = 2 } },
			},
		},
		{
			title = Addon.L.SECTION_PLATES_GENERAL,
			rows = {
				{ { key = Keys.PLATES_ALWAYS, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_STACKED, span = 2 } },
				"divider",
				{ { key = Keys.HIDE_FRIENDLY_IN_COMBAT, span = 2 } },
				"divider",
				{ { key = Keys.PLATES_SELF, span = 2 } },
				"divider",
				{ { key = Keys.HIDE_PLAYER_FRAME, span = 2 } },
			},
		},
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterUnder(category)
end

Addon.PlatesPanel = PlatesPanel
