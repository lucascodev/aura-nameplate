---@meta

--- How the icon is dressed. Measured values only: the renderer receives what
--- to draw, never the preferences that decided it.
---@class IconAppearance
---@field width number
---@field height number
---@field alpha number
---@field borderThickness number
---@field borderColor { red: number, green: number, blue: number }
---@field showSwipe boolean
---@field showTimerText boolean

--- Where the icon sits relative to whatever holds it.
---@class IconPlacement
---@field point string
---@field relativePoint string
---@field x number
---@field y number
---@field spansHost boolean Stretch to the host's width instead of taking a point. Text only.

--- The widget the tracker drives. Kept as a port so the display logic can be
--- tested against a table that only records what it was told.
---@class IconRenderer
---@field SetIcon fun(self: IconRenderer, iconID: number, spellID: number?)
---@field SetCooldown fun(self: IconRenderer, reading: CooldownReading?)
---@field SetAppearance fun(self: IconRenderer, appearance: IconAppearance)
---@field SetFont fun(self: IconRenderer, path: string, size: number, flag: string)
---@field Attach fun(self: IconRenderer, host: table, placement: IconPlacement)
---@field SetShown fun(self: IconRenderer, isShown: boolean)
