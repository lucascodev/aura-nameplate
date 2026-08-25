---@meta

--- One line of the self-check.
---@class DiagnosticLine
---@field label string
---@field value string

--- Answers, in order, every question that stands between "the addon is loaded"
--- and "the icon is on screen". Implemented where the game is read, because
--- every one of those questions is a call Core is not allowed to make.
---@class DiagnosticsProbe
---@field Read fun(self: DiagnosticsProbe): DiagnosticLine[]
