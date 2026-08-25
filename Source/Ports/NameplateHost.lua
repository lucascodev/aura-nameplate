---@meta

--- The frame an icon can hang from, and the token that names its unit.
---@class NameplateHost
---@field frame table The bar the client draws into, which is what an offset should mean something against.
---@field unit string
---@field name? table The client's own name text, when it is where it is expected to be.
---@field auras? table The client's own aura icons, when they exist and are not forbidden.

--- Publishes nameplates as the client shows and hides them.
---@class NameplateSource
---@field Start fun(self: NameplateSource, onChanged: fun())
---@field ForUnit fun(self: NameplateSource, unit: string): NameplateHost?
