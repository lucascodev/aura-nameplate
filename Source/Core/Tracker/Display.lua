local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Everything that decides what the icon shows, in one place.
---
--- Talks to ports only: a history it can ask, a host it can hang from, a
--- cooldown it can read and a renderer it can drive. None of them is a frame as
--- far as this file is concerned, which is what lets the whole rule be tested
--- against tables that just record what they were told.
---@class IconDisplay
---@field private history CastHistory
---@field private renderer IconRenderer
---@field private preferences Preferences
---@field private hosts HostSource
---@field private cooldowns CooldownSource
---@field private appearance AppearanceSources
---@field private gameState { HasTarget: fun(): boolean, IsInCombat: fun(): boolean, Now: fun(): number }
---@field private testCast CastEvent?
---@field private testReading CooldownReading?
local IconDisplay = {}
IconDisplay.__index = IconDisplay

---@param dependencies { history: CastHistory, renderer: IconRenderer, preferences: Preferences, hosts: HostSource, cooldowns: CooldownSource, appearance: AppearanceSources, gameState: table }
---@return IconDisplay
function IconDisplay.New(dependencies)
	return setmetatable({
		history = dependencies.history,
		renderer = dependencies.renderer,
		preferences = dependencies.preferences,
		hosts = dependencies.hosts,
		cooldowns = dependencies.cooldowns,
		appearance = dependencies.appearance,
		gameState = dependencies.gameState,
	}, IconDisplay)
end

--- A cast to pin on screen while the player lines the icon up, or nil to stop.
---@param cast CastEvent?
---@param reading CooldownReading?
function IconDisplay:SetTesting(cast, reading)
	self.testCast = cast
	self.testReading = reading
	self:Refresh()
end

---@return boolean
function IconDisplay:IsTesting()
	return self.testCast ~= nil
end

--- The player is always a candidate. A unit only joins when the player asked
--- for other units, so the slot of a nameplate that is not being read never
--- even gets looked up.
---@private
---@param host NameplateHost?
---@return CastEvent?
function IconDisplay:Pick(host)
	local slots = { Addon.CastHistory.PLAYER_SLOT }

	if host and self.preferences:Get(Keys.TRACK_OTHER_UNITS) then
		table.insert(slots, host.unit)
	end

	return self.history:Newest(slots, self.gameState.Now())
end

---@private
---@return IconAppearance
function IconDisplay:Appearance()
	local preferences = self.preferences

	return Addon.IconLayout.Appearance({
		width = preferences:Get(Keys.ICON_WIDTH),
		height = preferences:Get(Keys.ICON_HEIGHT),
		alphaPercent = preferences:Get(Keys.ICON_ALPHA),
		borderThickness = preferences:Get(Keys.BORDER_THICKNESS),
		borderHex = preferences:Get(Keys.BORDER_COLOR),
		showSwipe = preferences:Get(Keys.SHOW_SWIPE),
		showTimerText = preferences:Get(Keys.SHOW_TIMER_TEXT),
	})
end

--- Nothing is dressed before it is known the icon stays: hiding is one call,
--- and doing the work first would run on every event that changes nothing.
function IconDisplay:Refresh()
	local preferences = self.preferences
	local host = self.hosts:Current()
	local cast = self.testCast or self:Pick(host)

	local isShown = Addon.IconVisibility.IsShown({
		isEnabled = preferences:Get(Keys.ENABLED) == true,
		mode = preferences:Get(Keys.VISIBILITY_MODE),
		hasCast = cast ~= nil,
		hasHost = host ~= nil,
		hasTarget = self.gameState.HasTarget(),
		isInCombat = self.gameState.IsInCombat(),
		isTesting = self:IsTesting(),
	})

	if not isShown or not cast or not host then
		self.renderer:SetShown(false)
		return
	end

	self.renderer:SetIcon(cast.iconID, cast.spellID)
	self.renderer:SetCooldown(self.testReading or self.cooldowns.Read())
	self.renderer:SetAppearance(self:Appearance())
	self.renderer:SetFont(
		self.appearance.Font(preferences:Get(Keys.FONT_NAME)),
		preferences:Get(Keys.FONT_SIZE),
		Addon.FontFlags.Resolve(preferences:Get(Keys.FONT_FLAG))
	)
	self.renderer:Attach(host.frame, Addon.IconLayout.Placement(
		preferences:Get(Keys.ANCHOR_POINT),
		preferences:Get(Keys.OFFSET_X),
		preferences:Get(Keys.OFFSET_Y)
	))
	self.renderer:SetShown(true)
end

Addon.IconDisplay = IconDisplay
