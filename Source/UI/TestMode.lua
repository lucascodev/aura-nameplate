local _, Addon = ...

--- Long enough to watch the sweep run, short enough that it starts again before
--- anyone wonders whether it froze.
local SAMPLE_DURATION = 3

--- The widest case on purpose: someone aligning the health line needs to see
--- how much room it will actually take, not the shortest thing it can say.
local SAMPLE_HEALTH = { primary = "85%", secondary = "330k" }

---@class TestMode
---@field private display IconDisplay
---@field private healthDisplay HealthDisplay
---@field private anchor NameplateAnchor
---@field private logger Logger
---@field private ticker table?
local TestMode = {}
TestMode.__index = TestMode

---@param display IconDisplay
---@param healthDisplay HealthDisplay
---@param anchor NameplateAnchor
---@param logger Logger
---@return TestMode
function TestMode.New(display, healthDisplay, anchor, logger)
	return setmetatable({
		display = display,
		healthDisplay = healthDisplay,
		anchor = anchor,
		logger = logger,
	}, TestMode)
end

---@private
---@return CastEvent
local function SampleCast()
	return { slot = "test", iconID = Addon.SpellIcon.SAMPLE, castAt = GetTime() }
end

--- Re-armed on a ticker rather than left frozen: a still icon says nothing
--- about where the sweep and the number will actually sit.
---@private
function TestMode:Pin()
	self.display:SetTesting(SampleCast(), { start = GetTime(), duration = SAMPLE_DURATION })
end

---@return boolean isOn
function TestMode:Toggle()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil

		self.anchor:ForceFloating(false)
		self.display:SetTesting(nil)
		self.healthDisplay:SetTesting(nil)
		self.logger:Info(Addon.L.TEST_MODE_OFF)

		return false
	end

	self.anchor:ForceFloating(true)
	self.healthDisplay:SetTesting(SAMPLE_HEALTH)
	self:Pin()
	self.ticker = C_Timer.NewTicker(SAMPLE_DURATION, function()
		self:Pin()
	end)

	self.logger:Info(Addon.L.TEST_MODE_ON)
	self.logger:Info(Addon.L.FLOATING_DRAG_HINT)

	return true
end

Addon.TestMode = TestMode
