local _, Addon = ...

local L = Addon.L

--- Which side of the nameplate the icon hangs from.
---
--- Each choice carries the pair of anchor points the frame needs, so the id the
--- player picks is the only thing that ever gets saved and the geometry stays
--- out of the preference file.
---@class AnchorPoints
local AnchorPoints = {}

---@type PreferenceChoice[]
AnchorPoints.Choices = {
	{ id = "top", label = L.ANCHOR_TOP },
	{ id = "bottom", label = L.ANCHOR_BOTTOM },
	{ id = "left", label = L.ANCHOR_LEFT },
	{ id = "right", label = L.ANCHOR_RIGHT },
	{ id = "center", label = L.ANCHOR_CENTER },
}

--- point is the icon's own corner, relativePoint the nameplate's. Reading them
--- as a pair is what puts the icon beside the plate instead of over it.
local ANCHORS = {
	top = { point = "BOTTOM", relativePoint = "TOP" },
	bottom = { point = "TOP", relativePoint = "BOTTOM" },
	left = { point = "RIGHT", relativePoint = "LEFT" },
	right = { point = "LEFT", relativePoint = "RIGHT" },
	center = { point = "CENTER", relativePoint = "CENTER" },
}

--- Só os dois lados, para o que pende de uma borda e não tem versão em cima.
---@type PreferenceChoice[]
AnchorPoints.SideChoices = {
	{ id = "left", label = L.ANCHOR_LEFT },
	{ id = "right", label = L.ANCHOR_RIGHT },
}

local FALLBACK = ANCHORS.top

--- The same sides, pinned by a corner instead of a centre.
---
--- A row of aura icons grows sideways as icons are added. Held by its centre,
--- every new aura would shove the whole row across; held by an edge, it grows
--- away from that edge and the icons already on screen stay put.
local TRAILING = {
	top = { point = "BOTTOMRIGHT", relativePoint = "TOPRIGHT" },
	bottom = { point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT" },
	left = { point = "RIGHT", relativePoint = "LEFT" },
	right = { point = "LEFT", relativePoint = "RIGHT" },
	center = { point = "CENTER", relativePoint = "CENTER" },
}

--- An id saved by a version that offered a side this one dropped would return
--- nil and take the layout down with it.
---@param id string
---@return { point: string, relativePoint: string }
function AnchorPoints.Resolve(id)
	return ANCHORS[id] or FALLBACK
end

--- Como Resolve, para o que cresce de lado.
---@param id string
---@return { point: string, relativePoint: string }
function AnchorPoints.ResolveTrailing(id)
	return TRAILING[id] or TRAILING.bottom
end

Addon.AnchorPoints = AnchorPoints
