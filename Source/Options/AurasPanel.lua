local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- A fileira de auras que o addon desenha no lugar da do jogo: o que entra
--- nela, onde fica e como cada ícone é.
---@class AurasPanel
local AurasPanel = {}

---@param category table
---@param catalog Preference[]
---@param preferences Preferences
---@return table subcategory
function AurasPanel.Register(category, catalog, preferences)
	local page = Addon.OptionsPage.New({
		title = Addon.L.PAGE_AURAS,
		subtitle = Addon.L.PAGE_AURAS_HINT,
	})

	page:Mount({
		{
			title = Addon.L.SECTION_AURAS,
			rows = {
				{
					{ key = Keys.OWN_AURAS, span = 2 },
				},
				"divider",
				{
					{ key = Keys.AURA_FILTER, span = 2 },
				},
				{
					{ key = Keys.AURA_MAX_COUNT },
				},
			},
		},
		{
			title = Addon.L.SECTION_PLACEMENT,
			rows = {
				{
					{ key = Keys.AURA_ANCHOR_POINT, span = 2 },
				},
				{
					{ key = Keys.AURA_OFFSET_X },
					{ key = Keys.AURA_OFFSET_Y },
				},
			},
		},
		{
			title = Addon.L.SECTION_AURA_ICONS,
			rows = {
				{
					{ key = Keys.AURA_ICON_SIZE },
					{ key = Keys.AURA_ICON_SPACING },
				},
			},
		},
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterUnder(category)
end

Addon.AurasPanel = AurasPanel
