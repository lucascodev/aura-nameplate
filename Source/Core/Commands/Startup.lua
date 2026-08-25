local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Announces that the addon finished loading, when the player wants it, and
--- that the layout was put back to a new factory arrangement, whether they want
--- it or not: settings written over on the player's behalf are news even to
--- someone who muted the greeting.
--- Depends on the Logger port, never on the chat frame itself.
---@class Startup
---@field private logger Logger
---@field private addonInfo AddonInfo
---@field private preferences Preferences
---@field private hasNewLayout boolean
local Startup = {}
Startup.__index = Startup

---@param logger Logger
---@param addonInfo AddonInfo
---@param preferences Preferences
---@param hasNewLayout boolean?
---@return Startup
function Startup.New(logger, addonInfo, preferences, hasNewLayout)
	return setmetatable({
		logger = logger,
		addonInfo = addonInfo,
		preferences = preferences,
		hasNewLayout = hasNewLayout == true,
	}, Startup)
end

function Startup:Run()
	if self.hasNewLayout then
		self.logger:Info(Addon.L.LAYOUT_REFRESHED)
	end

	if not self.preferences:Get(Keys.ANNOUNCE_ON_LOAD) then
		return
	end

	self.logger:Info((Addon.L.STARTUP_LOADED):format(
		self.addonInfo.title,
		self.addonInfo.version
	))
end

Addon.Startup = Startup
