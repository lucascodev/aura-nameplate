---@meta

--- How the health text is dressed.
---@class TextAppearance
---@field color { red: number, green: number, blue: number }

--- A single line of text hung off whatever is holding it.
---
--- Kept as a port for the same reason as the icon: the rule that decides what it
--- says can then be tested against a table that only records what it was told.
---@class TextRenderer
---@field SetText fun(self: TextRenderer, reading: HealthReading)
---@field SetAppearance fun(self: TextRenderer, appearance: TextAppearance)
---@field SetFont fun(self: TextRenderer, path: string, size: number, flag: string)
---@field Attach fun(self: TextRenderer, host: table, placement: IconPlacement)
---@field SetShown fun(self: TextRenderer, isShown: boolean)
