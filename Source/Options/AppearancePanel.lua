local _, Addon = ...

local Keys = Addon.PreferenceKeys

---@class AppearancePanel
local AppearancePanel = {}

---@param category table
---@param catalog Preference[]
---@param preferences Preferences
---@return table subcategory
function AppearancePanel.Register(category, catalog, preferences)
	local page = Addon.OptionsPage.New({
		title = Addon.L.PAGE_APPEARANCE,
		subtitle = Addon.L.PAGE_APPEARANCE_HINT,
	})

	page:Mount({
		{
			title = Addon.L.SECTION_ICON,
			rows = {
				{
					{ key = Keys.ICON_WIDTH },
					{ key = Keys.ICON_HEIGHT },
				},
				{
					{ key = Keys.ICON_ALPHA, suffix = "%" },
				},
			},
		},
		{
			title = Addon.L.SECTION_PLACEMENT,
			rows = {
				{
					{ key = Keys.ANCHOR_POINT, span = 2 },
				},
				{
					{ key = Keys.OFFSET_X },
					{ key = Keys.OFFSET_Y },
				},
			},
		},
		{
			title = Addon.L.SECTION_TIMER,
			rows = {
				{
					{ key = Keys.SHOW_SWIPE, span = 2 },
				},
				"divider",
				{
					{ key = Keys.SHOW_TIMER_TEXT, span = 2 },
				},
			},
		},
		{
			title = Addon.L.SECTION_BORDER,
			rows = {
				{
					{ key = Keys.BORDER_THICKNESS },
					{ key = Keys.BORDER_COLOR },
				},
			},
		},
		{
			title = Addon.L.SECTION_TEXT,
			rows = {
				{
					{ key = Keys.FONT_NAME, choices = Addon.MediaLibrary.FontChoices },
					{ key = Keys.FONT_SIZE },
				},
				{
					{ key = Keys.FONT_FLAG },
				},
			},
		},
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterUnder(category)
end

Addon.AppearancePanel = AppearancePanel
