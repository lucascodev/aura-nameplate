---@meta

--- A cooldown as the client reports it.
---
--- start and duration are handed straight to Cooldown:SetCooldown, which
--- accepts secret values: the addon animates the sweep without ever reading
--- the numbers. Nothing may compare or do maths on them.
---@class CooldownReading
---@field start number|unknown
---@field duration number|unknown

---@class CooldownSource
---@field Read fun(): CooldownReading?
