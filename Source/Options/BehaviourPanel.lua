local _, Addon = ...

local Keys = Addon.PreferenceKeys

---@class BehaviourPanel
local BehaviourPanel = {}

---@param category table
---@param catalog Preference[]
---@param preferences Preferences
---@return table subcategory
function BehaviourPanel.Register(category, catalog, preferences)
	local page = Addon.OptionsPage.New({
		title = Addon.L.PAGE_BEHAVIOUR,
		subtitle = Addon.L.PAGE_BEHAVIOUR_HINT,
	})

	page:Mount({
		{
			title = Addon.L.SECTION_WHEN,
			rows = {
				{
					{ key = Keys.VISIBILITY_MODE },
					{ key = Keys.HOLD_DURATION, suffix = "s" },
				},
				"divider",
				{
					{ key = Keys.FLOATING_FALLBACK, span = 2 },
				},
			},
		},
		{
			title = Addon.L.SECTION_SOURCES,
			rows = {
				{
					{ key = Keys.SHOW_ON_FRIENDLY, span = 2 },
				},
				"divider",
				{
					{ key = Keys.TRACK_OTHER_UNITS, span = 2 },
				},
			},
		},
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterUnder(category)
end

Addon.BehaviourPanel = BehaviourPanel
