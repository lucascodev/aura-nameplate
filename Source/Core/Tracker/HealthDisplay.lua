local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- What each nameplate's health line says, and whether it is on screen.
---
--- A sibling of IconDisplay rather than a branch inside it: the two answer to
--- different things. The icon belongs to one unit — whatever the player is
--- casting at — and can fall back to the free spot. The health belongs to every
--- plate on screen, clicked or not.
---
--- They also come and go on different terms, which is why the health carries its
--- own visibility mode. Tying it to the icon's meant a health readout that
--- vanished the moment the fight ended, which is not what anyone asks for when
--- they ask to see the health.
---@class HealthDisplay
---@field private renderers TextRendererPool
---@field private preferences Preferences
---@field private hosts HostSource
---@field private health HealthSource
---@field private appearance AppearanceSources
---@field private gameState { HasTarget: fun(): boolean, IsInCombat: fun(): boolean }
---@field private testText HealthReading?
local HealthDisplay = {}
HealthDisplay.__index = HealthDisplay

---@param dependencies { renderers: TextRendererPool, preferences: Preferences, hosts: HostSource, health: HealthSource, appearance: AppearanceSources, gameState: table }
---@return HealthDisplay
function HealthDisplay.New(dependencies)
	return setmetatable({
		renderers = dependencies.renderers,
		preferences = dependencies.preferences,
		hosts = dependencies.hosts,
		health = dependencies.health,
		appearance = dependencies.appearance,
		gameState = dependencies.gameState,
	}, HealthDisplay)
end

--- A line to pin on screen while the player lines the text up, or nil to stop.
--- Wrapped like a real reading so the draw path has a single shape.
---@param reading HealthReading?
function HealthDisplay:SetTesting(reading)
	self.testText = reading
	self:Refresh()
end

--- Both switches have to be on. The general one silences the whole addon; the
--- health one silences only this line.
---@private
---@return boolean
function HealthDisplay:IsWanted()
	return self.preferences:Get(Keys.ENABLED) == true
		and self.preferences:Get(Keys.HEALTH_TEXT_ENABLED) == true
end

--- The part of the decision that does not depend on which plate is being drawn:
--- the switches, the mode, and whether there is a target at all. Asked once per
--- refresh rather than once per nameplate.
---@private
---@return boolean
function HealthDisplay:IsAllowed()
	return Addon.IconVisibility.IsShown({
		isEnabled = self:IsWanted(),
		mode = self.preferences:Get(Keys.HEALTH_VISIBILITY_MODE),
		-- The health does not wait on a spell being cast; having a plate to
		-- write on is the equivalent condition, and that is decided per plate.
		hasCast = true,
		hasHost = true,
		hasTarget = self.gameState.HasTarget(),
		isInCombat = self.gameState.IsInCombat(),
		isTesting = self.testText ~= nil and self:IsWanted(),
	})
end

---@private
---@param renderer TextRenderer
---@param reading HealthReading
---@param host NameplateHost
function HealthDisplay:Draw(renderer, reading, host)
	local preferences = self.preferences

	-- A fonte antes do texto, e nao o contrario: escrever num FontString que
	-- ainda nao tem fonte levanta erro, e o desenho morre antes de aparecer.
	renderer:SetFont(
		self.appearance.Font(preferences:Get(Keys.FONT_NAME)),
		preferences:Get(Keys.HEALTH_FONT_SIZE),
		Addon.FontFlags.Resolve(preferences:Get(Keys.FONT_FLAG))
	)
	renderer:SetAppearance({
		color = Addon.IconLayout.Color(preferences:Get(Keys.HEALTH_COLOR)),
	})
	renderer:SetText(reading)
	renderer:Attach(host.frame, Addon.IconLayout.Placement(
		preferences:Get(Keys.HEALTH_ANCHOR_POINT),
		preferences:Get(Keys.HEALTH_OFFSET_X),
		preferences:Get(Keys.HEALTH_OFFSET_Y)
	))
	renderer:SetShown(true)
end

--- One pass over every plate on screen. What is not drawn this round is hidden
--- by omission: a plate the client took away raises nothing we can trust for
--- its line, and a line left behind would follow whatever unit the plate gets
--- recycled onto next.
function HealthDisplay:Refresh()
	local drawn = {}

	if self:IsAllowed() then
		local format = self.preferences:Get(Keys.HEALTH_TEXT_FORMAT)

		for _, host in ipairs(self.hosts:Nameplates()) do
			-- O envelope existe para esta linha: perguntar `text ~= nil` direto
			-- na string da vida seria comparar um valor classificado.
			local reading = self.testText or self.health.Text(host.unit, format)

			if reading then
				self:Draw(self.renderers:Acquire(host.unit), reading, host)
				drawn[host.unit] = true
			end
		end
	end

	self.renderers:HideOthers(drawn)
end

Addon.HealthDisplay = HealthDisplay
