local _, Addon = ...

local Keys = Addon.PreferenceKeys

---@class HealthPanel
local HealthPanel = {}

---@param category table
---@param catalog Preference[]
---@param preferences Preferences
---@return table subcategory
function HealthPanel.Register(category, catalog, preferences)
	local page = Addon.OptionsPage.New({
		title = Addon.L.PAGE_HEALTH,
		subtitle = Addon.L.PAGE_HEALTH_HINT,
	})

	page:Mount({
		{
			title = Addon.L.SECTION_HEALTH,
			rows = {
				{
					{ key = Keys.HEALTH_TEXT_ENABLED, span = 2 },
				},
				"divider",
				{
					{ key = Keys.HEALTH_TEXT_FORMAT, span = 2 },
				},
				"divider",
				{
					{ key = Keys.HEALTH_VISIBILITY_MODE, span = 2 },
				},
			},
		},
		{
			title = Addon.L.SECTION_PLACEMENT,
			rows = {
				{
					{ key = Keys.HEALTH_ANCHOR_POINT, span = 2 },
				},
				{
					{ key = Keys.HEALTH_OFFSET_X },
					{ key = Keys.HEALTH_OFFSET_Y },
				},
			},
		},
		{
			title = Addon.L.SECTION_PLATE,
			rows = {
				{
					{ key = Keys.NAME_ABOVE_BAR, span = 2 },
				},
				"divider",
				{
					{ key = Keys.NAME_BACKDROP, span = 2 },
				},
				{
					{ key = Keys.NAME_BACKDROP_OPACITY, suffix = "%" },
					{ key = Keys.NAME_BACKDROP_HEIGHT },
				},
				{
					{ key = Keys.NAME_BACKDROP_COLOR },
				},
			},
		},
		{
			title = Addon.L.SECTION_PORTRAIT,
			rows = {
				{ { key = Keys.PORTRAIT_ON_SELF, span = 2 } },
				"divider",
				{
					{ key = Keys.PORTRAIT_ON_FRIENDLY_PLAYERS },
					{ key = Keys.PORTRAIT_ON_ENEMY_PLAYERS },
				},
				{
					{ key = Keys.PORTRAIT_ON_FRIENDLY_NPCS },
					{ key = Keys.PORTRAIT_ON_ENEMY_NPCS },
				},
				"divider",
				{
					{ key = Keys.PORTRAIT_SIZE },
					{ key = Keys.PORTRAIT_SIDE },
				},
			},
		},
		{
			title = Addon.L.SECTION_TEXT,
			rows = {
				{
					{ key = Keys.HEALTH_FONT_SIZE },
					{ key = Keys.HEALTH_COLOR },
				},
			},
		},
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterUnder(category)
end

Addon.HealthPanel = HealthPanel
