local _, Addon = ...

--- One health line per unit, reused as plates come and go.
---
--- Nameplates are recycled constantly; building a frame per arrival would leave
--- one behind for every unit seen in a session. Frames are never destroyed —
--- the client has no way to — so the only honest strategy is to keep and lend
--- them back.
---@class HealthTextPool : TextRendererPool
---@field private renderers table<string, HealthTextFrame>
local HealthTextPool = {}
HealthTextPool.__index = HealthTextPool

---@return HealthTextPool
function HealthTextPool.New()
	return setmetatable({ renderers = {} }, HealthTextPool)
end

---@param unit string
---@return HealthTextFrame
function HealthTextPool:Acquire(unit)
	if not self.renderers[unit] then
		self.renderers[unit] = Addon.HealthTextFrame.New()
	end

	return self.renderers[unit]
end

--- Everything not drawn this round goes away. Hiding by omission rather than by
--- bookkeeping: a unit whose plate vanished raises no event we can rely on for
--- the frame, and a line left on screen would follow whatever unit the plate is
--- recycled onto next.
---@param kept table<string, boolean>
function HealthTextPool:HideOthers(kept)
	for unit, renderer in pairs(self.renderers) do
		if not kept[unit] then
			renderer:SetShown(false)
		end
	end
end

Addon.HealthTextPool = HealthTextPool
