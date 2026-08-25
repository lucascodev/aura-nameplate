local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Enough to clear the bar's border without floating away from it.
local GAP = 2
local WHITE = [[Interface\Buttons\WHITE8X8]]
local PERCENT = 100

--- What the addon does to the client's own name text.
---
--- The one place that touches something the client drew, rather than adding
--- something beside it. That is why every part of it is a switch, and why the
--- work is reapplied rather than done once: the client re-anchors the name on
--- its own updates, so a single move would hold only until the next one.
---
--- Switching the lift back off does not undo it — the original anchor belongs
--- to the client and reading it back is a measurement the client refuses on a
--- nameplate. A reload puts everything where the client wants it.
---@class NameLayout
---@field private hosts HostSource
---@field private preferences Preferences
---@field private backdrops table<table, table> Por frame de placa, nunca por unidade.
local NameLayout = {}
NameLayout.__index = NameLayout

---@param hosts HostSource
---@param preferences Preferences
---@return NameLayout
function NameLayout.New(hosts, preferences)
	return setmetatable({
		hosts = hosts,
		preferences = preferences,
		backdrops = setmetatable({}, { __mode = "k" }),
	}, NameLayout)
end

--- Drawn onto the frame that owns the name, in the layer beneath it.
---
--- Frame levels cannot settle this: the name belongs to one frame and the bar
--- to another, so "above the bar but below the name" has no reliable answer
--- across the two. A texture in BACKGROUND on the name's own frame is behind
--- the name by construction.
---
--- Kept per plate frame rather than per unit. The client recycles a fixed pool
--- of plates, so this table stops growing on its own; keying by unit would add
--- an entry for everything seen all session.
---@private
---@param owner table
---@return table
function NameLayout:Backdrop(owner)
	if not self.backdrops[owner] then
		self.backdrops[owner] = {
			solid = owner:CreateTexture(nil, "BACKGROUND"),
			fade = owner:CreateTexture(nil, "BACKGROUND"),
		}
	end

	return self.backdrops[owner]
end

--- Solid to the halfway mark, then out to nothing by the right edge — which is
--- what "fading from the middle" asks for. A single gradient across the whole
--- width would start thinning under the first letter.
---
--- Anchoring to the parent's TOP and BOTTOM is how the halfway mark is found
--- without measuring the bar, which the client refuses.
---@private
---@param textures table
---@param bar table
---@param settings { red: number, green: number, blue: number, alpha: number, height: number }
local function Paint(textures, bar, settings)
	local solid, fade = textures.solid, textures.fade
	local red, green, blue, alpha = settings.red, settings.green, settings.blue, settings.alpha

	for _, texture in ipairs({ solid, fade }) do
		texture:ClearAllPoints()
		texture:SetTexture(WHITE)
		texture:SetHeight(settings.height)
	end

	solid:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, GAP)
	solid:SetPoint("BOTTOMRIGHT", bar, "TOP", 0, GAP)
	solid:SetVertexColor(red, green, blue, alpha)

	fade:SetPoint("BOTTOMLEFT", bar, "TOP", 0, GAP)
	fade:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, GAP)
	fade:SetVertexColor(red, green, blue, alpha)

	-- A degradação por vértice chegou com um nome e uma assinatura diferentes ao
	-- longo das versões. Sem ela, a metade da direita fica apenas sólida, o que
	-- é feio mas não quebra nada.
	if fade.SetGradient and CreateColor then
		fade:SetGradient(
			"HORIZONTAL",
			CreateColor(red, green, blue, alpha),
			CreateColor(red, green, blue, 0)
		)
	end

	solid:Show()
	fade:Show()
end

---@private
---@param textures table
local function Clear(textures)
	textures.solid:Hide()
	textures.fade:Hide()
end

---@private
---@param host NameplateHost
function NameLayout:Lift(host)
	host.name:ClearAllPoints()
	host.name:SetPoint("BOTTOMLEFT", host.frame, "TOPLEFT", GAP, GAP)

	-- Encostar o ponto na esquerda nao basta: sem isto o texto continua
	-- centralizado dentro da propria largura que o cliente reservou.
	host.name:SetJustifyH("LEFT")
end

--- Apaga todo fundo ja' desenhado, e nao apenas os das placas visiveis agora.
--- Uma placa fora de cena, ou reciclada para uma unidade sem nome legivel, nao
--- passa mais por Dress: sem isto, desligar a opcao deixaria o fundo aceso ate'
--- aquela placa voltar por acaso.
---@private
function NameLayout:ClearAll()
	for _, textures in pairs(self.backdrops) do
		Clear(textures)
	end
end

---@private
---@param host NameplateHost
function NameLayout:Dress(host)
	local owner = host.name:GetParent()

	if not owner or not owner.CreateTexture then
		return
	end

	local textures = self:Backdrop(owner)
	local red, green, blue = Addon.HexColor.ToRGB(self.preferences:Get(Keys.NAME_BACKDROP_COLOR))

	Paint(textures, host.frame, {
		red = red,
		green = green,
		blue = blue,
		alpha = self.preferences:Get(Keys.NAME_BACKDROP_OPACITY) / PERCENT,
		height = self.preferences:Get(Keys.NAME_BACKDROP_HEIGHT),
	})
end

function NameLayout:Refresh()
	local isLifted = self.preferences:Get(Keys.NAME_ABOVE_BAR)
	local isDressed = self.preferences:Get(Keys.NAME_BACKDROP)

	if not isDressed then
		self:ClearAll()
	end

	for _, host in ipairs(self.hosts:Nameplates()) do
		if host.name then
			if isLifted then
				self:Lift(host)
			end

			if isDressed then
				self:Dress(host)
			end
		end
	end
end

Addon.NameLayout = NameLayout
