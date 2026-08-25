---@meta

--- Where a slash command is filed. Core asks for one; System hands it the
--- global table the client actually reads.
---@class CommandRegistry
---@field Register fun(self: CommandRegistry, command: string, handler: fun(argument: string))
