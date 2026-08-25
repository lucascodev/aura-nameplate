local _, Addon = ...

--- Writes out why nothing is being drawn.
---
--- "It is not showing" has half a dozen causes that look identical on screen:
--- no target, a nameplate the client refuses to hand over, an API this client
--- version does not have. Asking the addon beats guessing from a screenshot.
---@class DiagnoseCommand
---@field private logger Logger
---@field private probe DiagnosticsProbe
local DiagnoseCommand = {}
DiagnoseCommand.__index = DiagnoseCommand

---@param logger Logger
---@param probe DiagnosticsProbe
---@return DiagnoseCommand
function DiagnoseCommand.New(logger, probe)
	return setmetatable({ logger = logger, probe = probe }, DiagnoseCommand)
end

function DiagnoseCommand:Run()
	self.logger:Info(Addon.L.DIAG_TITLE)

	for _, line in ipairs(self.probe:Read()) do
		self.logger:Info(("%s: %s"):format(line.label, line.value))
	end
end

Addon.DiagnoseCommand = DiagnoseCommand
