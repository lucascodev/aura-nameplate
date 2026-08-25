local _, Addon = ...

--- An addon only shows up under Options → AddOns if it registers a category.
--- Every page is a canvas drawn by the addon; the Settings API only provides
--- the tree. The price, accepted on purpose: no native search and no Defaults
--- button, in exchange for full control of label, hint and value.
---@class OptionsPanel
---@field private addonInfo AddonInfo
---@field private catalog Preference[]
---@field private preferences Preferences
---@field private category table?
local OptionsPanel = {}
OptionsPanel.__index = OptionsPanel

--- The pages, in the order the tree shows them.
local PANELS = {
	{
		name = "appearance",
		register = function(category, catalog, preferences)
			return Addon.AppearancePanel.Register(category, catalog, preferences)
		end,
	},
	{
		name = "health",
		register = function(category, catalog, preferences)
			return Addon.HealthPanel.Register(category, catalog, preferences)
		end,
	},
	{
		name = "plates",
		register = function(category, catalog, preferences)
			return Addon.PlatesPanel.Register(category, catalog, preferences)
		end,
	},
	{
		name = "windows",
		register = function(category, catalog, preferences, panelCommands)
			return Addon.WindowsPanel.Register(category, catalog, preferences, panelCommands)
		end,
	},
	{
		name = "behaviour",
		register = function(category, catalog, preferences)
			return Addon.BehaviourPanel.Register(category, catalog, preferences)
		end,
	},
}

---@param addonInfo AddonInfo
---@param catalog Preference[]
---@param preferences Preferences
---@param info { label: string, value: string }[] Read-only facts for the root page.
---@param profileCommands table Everything the profile page can do.
---@param logger Logger
---@return OptionsPanel
function OptionsPanel.New(addonInfo, catalog, preferences, info, profileCommands, logger, panelCommands)
	return setmetatable({
		addonInfo = addonInfo,
		catalog = catalog,
		preferences = preferences,
		info = info,
		profileCommands = profileCommands,
		logger = logger,
		panelCommands = panelCommands,
	}, OptionsPanel)
end

function OptionsPanel:Register()
	local category = Addon.MainPanel.Register(
		self.addonInfo,
		self.catalog,
		self.preferences,
		self.info,
		self.panelCommands
	)

	for _, panel in ipairs(PANELS) do
		panel.register(category, self.catalog, self.preferences, self.panelCommands)
	end

	Addon.ProfilePanel.Register(category, self.profileCommands)

	Settings.RegisterAddOnCategory(category)
	self.category = category
end

--- Every page is hand drawn, so writing goes straight to the store; the pages
--- re-read their values on show.
---@param key string
---@param value boolean|number|string
function OptionsPanel:SelectValue(key, value)
	self.preferences:Set(key, value)
end

--- A Blizzard protege a abertura do painel em combate; tentar mesmo assim
--- raises a blocked action in the addon's name, so the click becomes a warning.
function OptionsPanel:Open()
	if InCombatLockdown() then
		self.logger:Warn(Addon.L.OPTIONS_IN_COMBAT)
		return
	end

	Settings.OpenToCategory(self.category:GetID())
end

Addon.OptionsPanel = OptionsPanel
