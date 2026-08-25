local _, Addon = ...

--- Which units currently wear a nameplate.
---
--- The token comes from the event, not from the frame. That is the only source
--- that is always there: the plate stopped publishing its own token reliably,
--- and reading health needs a token more than it needs a frame.
---
--- The frame is resolved again on every ask rather than stored. The client
--- recycles plates between units, so a frame kept from when the plate arrived
--- can belong to somebody else by the time it is drawn into.
---@class NameplateTracker
---@field private tokens table<string, boolean>
local NameplateTracker = {}
NameplateTracker.__index = NameplateTracker

---@return NameplateTracker
function NameplateTracker.New()
	return setmetatable({ tokens = {} }, NameplateTracker)
end

---@param onChanged fun()
function NameplateTracker:Start(onChanged)
	local listener = CreateFrame("Frame")

	listener:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	listener:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

	listener:SetScript("OnEvent", function(_, event, unit)
		if type(unit) ~= "string" then
			return
		end

		self.tokens[unit] = event == "NAME_PLATE_UNIT_ADDED" or nil
		onChanged()
	end)
end

--- Every plate on screen, as hosts ready to be drawn into. A token whose plate
--- has already gone is dropped on the way past: the removal event is the usual
--- way out, but a reload or a zone change can leave one behind.
---@return NameplateHost[]
function NameplateTracker:Hosts()
	local hosts = {}

	for token in pairs(self.tokens) do
		local host = Addon.NameplateRegistry.ForUnit(token)

		if host then
			table.insert(hosts, host)
		else
			self.tokens[token] = nil
		end
	end

	return hosts
end

Addon.NameplateTracker = NameplateTracker
