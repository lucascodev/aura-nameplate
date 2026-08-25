---@meta

--- One text renderer per unit, handed out on demand.
---
--- Nameplates come and go constantly, and building a frame for each arrival
--- would leak one per unit seen in a session. The pool keeps them and lends the
--- same one back to the same unit.
---@class TextRendererPool
---@field Acquire fun(self: TextRendererPool, unit: string): TextRenderer
---@field HideOthers fun(self: TextRendererPool, kept: table<string, boolean>)
