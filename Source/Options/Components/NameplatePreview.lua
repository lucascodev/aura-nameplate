local _, Addon = ...

local Keys = Addon.PreferenceKeys
local Theme = Addon.OptionsTheme
local Fonts = Addon.OptionsFonts

local WHITE = [[Interface\Buttons\WHITE8X8]]
local PERCENT = 100

--- A placa de mentira tem medidas fixas. Ela não é uma régua — é o arranjo que
--- se está tentando ver, e um palco que muda de tamanho a cada ajuste faria a
--- prévia parecer instável justamente quando se está comparando.
local STAGE_HEIGHT = 148
local BAR_WIDTH = 160
local BAR_HEIGHT = 12
local FILLED_FRACTION = 0.85
local NAME_GAP = 3
local TEXT_INSET = 3

local TRACK_COLOR = { red = 0.09, green = 0.09, blue = 0.11 }
local FILL_COLOR = { red = 0.16, green = 0.6, blue = 0.24 }
local NAME_COLOR = { red = 0.86, green = 0.36, blue = 0.32 }

--- Arte qualquer, só para haver ícone onde os ícones vão ficar. Nenhuma aura de
--- verdade é lida: a prévia não pergunta nada ao jogo.
local SAMPLE_AURAS = {
	[[Interface\Icons\Spell_Shadow_UnholyFrenzy]],
	[[Interface\Icons\Ability_Rogue_Rupture]],
	[[Interface\Icons\Spell_Fire_Immolation]],
	[[Interface\Icons\Spell_Frost_FrostShock]],
	[[Interface\Icons\Spell_Nature_Drowsy]],
	[[Interface\Icons\Ability_Warrior_Sunder]],
}

--- Quantos ícones a prévia se dispõe a desenhar. O limite real é do jogador e
--- pode ser maior; passar disso não ensinaria nada e encheria o palco.
local PREVIEW_AURA_CEILING = 12

---@class NameplatePreview
local NameplatePreview = {}

---@param texture table
---@param color { red: number, green: number, blue: number }
---@param alpha number?
local function Paint(texture, color, alpha)
	texture:SetColorTexture(color.red, color.green, color.blue, alpha or 1)
end

---@param region table
---@param color { red: number, green: number, blue: number }
local function Tint(region, color)
	region:SetTextColor(color.red, color.green, color.blue)
end

--- A fonte que o jogador escolheu, no tamanho que ele escolheu. A prévia mente
--- sobre a unidade, nunca sobre o desenho.
---@param preferences Preferences
---@param size number
---@return string, number, string
local function ChosenFont(preferences, size)
	return Addon.MediaLibrary.FontPath(preferences:Get(Keys.FONT_NAME)),
		size,
		Addon.FontFlags.Resolve(preferences:Get(Keys.FONT_FLAG))
end

--- O palco: fundo, moldura e a etiqueta que avisa que nada ali é real.
---@param parent table
---@param width number
---@return table
local function BuildStage(parent, width)
	local stage = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	stage:SetSize(width, STAGE_HEIGHT)
	stage:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = Theme.RULE_THICKNESS })
	stage:SetBackdropColor(
		Theme.PAGE_COLOR.red,
		Theme.PAGE_COLOR.green,
		Theme.PAGE_COLOR.blue,
		1
	)
	stage:SetBackdropBorderColor(
		Theme.BORDER_COLOR.red,
		Theme.BORDER_COLOR.green,
		Theme.BORDER_COLOR.blue,
		Theme.BORDER_COLOR.alpha
	)

	local caption = stage:CreateFontString(nil, "OVERLAY")
	caption:SetFontObject(Fonts.EDGE)
	caption:SetPoint("TOPLEFT", 8, -7)
	caption:SetText(Addon.L.PREVIEW_CAPTION)
	Tint(caption, Theme.FAINT_COLOR)

	return stage
end

--- A barra de vida, que aqui é só duas texturas: nada se move, e a fração é
--- fixa. O que importa é onde o texto cai sobre ela.
---@param stage table
---@return table
local function BuildBar(stage)
	local bar = CreateFrame("Frame", nil, stage)
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	-- Um pouco acima do centro: o nome mora em cima e as auras embaixo, e o
	-- conjunto centrado de verdade é o dos três, não o da barra.
	bar:SetPoint("CENTER", 0, 8)

	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	Paint(track, TRACK_COLOR)

	local fill = bar:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT")
	fill:SetPoint("BOTTOMLEFT")
	fill:SetWidth(BAR_WIDTH * FILLED_FRACTION)
	Paint(fill, FILL_COLOR)

	return bar
end

--- O nome e o tapete atrás dele. São um par: o tapete existe para dar contraste
--- ao nome, e desenhá-lo sem saber onde o nome ficou não faria sentido.
---@param bar table
---@return table
local function BuildName(bar)
	local backdrop = bar:CreateTexture(nil, "BACKGROUND")
	local text = bar:CreateFontString(nil, "OVERLAY")

	local name = { backdrop = backdrop, text = text }

	---@param preferences Preferences
	function name:Refresh(preferences)
		local isLifted = preferences:Get(Keys.NAME_ABOVE_BAR)

		text:SetFont(ChosenFont(preferences, preferences:Get(Keys.HEALTH_FONT_SIZE) + 1))
		text:SetText(Addon.L.PREVIEW_UNIT_NAME)
		Tint(text, NAME_COLOR)
		text:ClearAllPoints()

		if isLifted then
			text:SetPoint("BOTTOM", bar, "TOP", 0, NAME_GAP)
		else
			text:SetPoint("CENTER", bar, "CENTER", 0, 0)
		end

		if not preferences:Get(Keys.NAME_BACKDROP) then
			backdrop:Hide()
			return
		end

		local color = Addon.IconLayout.Color(preferences:Get(Keys.NAME_BACKDROP_COLOR))

		Paint(backdrop, color, preferences:Get(Keys.NAME_BACKDROP_OPACITY) / PERCENT)
		backdrop:ClearAllPoints()
		backdrop:SetHeight(preferences:Get(Keys.NAME_BACKDROP_HEIGHT))
		backdrop:SetPoint("LEFT", bar, "LEFT")
		backdrop:SetPoint("RIGHT", bar, "RIGHT")
		backdrop:SetPoint("CENTER", text, "CENTER")
		backdrop:Show()
	end

	return name
end

--- A linha de vida, com a mesma regra de espalhamento do desenho de verdade:
--- ancorada no centro ela ocupa a barra inteira, com a porcentagem numa ponta e
--- o número na outra; em qualquer outro canto as duas andam juntas.
---@param bar table
---@return table
local function BuildHealth(bar)
	local primary = bar:CreateFontString(nil, "OVERLAY")
	local secondary = bar:CreateFontString(nil, "OVERLAY")

	local health = {}

	---@param preferences Preferences
	function health:Refresh(preferences)
		if not preferences:Get(Keys.HEALTH_TEXT_ENABLED) then
			primary:Hide()
			secondary:Hide()
			return
		end

		local reading = Addon.SampleReading.Health(preferences:Get(Keys.HEALTH_TEXT_FORMAT))
		local placement = Addon.IconLayout.Placement(
			preferences:Get(Keys.HEALTH_ANCHOR_POINT),
			preferences:Get(Keys.HEALTH_OFFSET_X),
			preferences:Get(Keys.HEALTH_OFFSET_Y)
		)
		local color = Addon.IconLayout.Color(preferences:Get(Keys.HEALTH_COLOR))
		local font = { ChosenFont(preferences, preferences:Get(Keys.HEALTH_FONT_SIZE)) }

		for _, line in ipairs({ primary, secondary }) do
			line:SetFont(font[1], font[2], font[3])
			Tint(line, color)
			line:ClearAllPoints()
			line:Show()
		end

		primary:SetText(reading.primary)
		secondary:SetText(reading.secondary or "")

		if placement.spansHost then
			primary:SetPoint("LEFT", bar, "LEFT", TEXT_INSET + placement.x, placement.y)
			secondary:SetPoint("RIGHT", bar, "RIGHT", -TEXT_INSET + placement.x, placement.y)
			return
		end

		primary:SetPoint(placement.point, bar, placement.relativePoint, placement.x, placement.y)
		secondary:SetPoint("LEFT", primary, "RIGHT", TEXT_INSET * 2, 0)
	end

	return health
end

--- O ícone do cooldown global, com a moldura que o jogador escolheu.
---@param bar table
---@return table
local function BuildIcon(bar)
	local frame = CreateFrame("Frame", nil, bar, "BackdropTemplate")

	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	texture:SetTexture(Addon.SpellIcon.SAMPLE)

	local icon = {}

	---@param preferences Preferences
	function icon:Refresh(preferences)
		if not preferences:Get(Keys.ENABLED) then
			frame:Hide()
			return
		end

		local appearance = Addon.IconLayout.Appearance({
			width = preferences:Get(Keys.ICON_WIDTH),
			height = preferences:Get(Keys.ICON_HEIGHT),
			alphaPercent = preferences:Get(Keys.ICON_ALPHA),
			borderThickness = preferences:Get(Keys.BORDER_THICKNESS),
			borderHex = preferences:Get(Keys.BORDER_COLOR),
			showSwipe = preferences:Get(Keys.SHOW_SWIPE),
			showTimerText = preferences:Get(Keys.SHOW_TIMER_TEXT),
		})

		local placement = Addon.IconLayout.Placement(
			preferences:Get(Keys.ANCHOR_POINT),
			preferences:Get(Keys.OFFSET_X),
			preferences:Get(Keys.OFFSET_Y)
		)

		frame:SetSize(appearance.width, appearance.height)
		frame:SetAlpha(appearance.alpha)
		frame:ClearAllPoints()
		frame:SetPoint(placement.point, bar, placement.relativePoint, placement.x, placement.y)

		if appearance.borderThickness > 0 then
			frame:SetBackdrop({ edgeFile = WHITE, edgeSize = appearance.borderThickness })
			frame:SetBackdropBorderColor(
				appearance.borderColor.red,
				appearance.borderColor.green,
				appearance.borderColor.blue,
				1
			)
		else
			frame:SetBackdrop(nil)
		end

		frame:Show()
	end

	return icon
end

--- A fileira de auras.
---
--- Cresce para longe da borda em que está presa, igual à de verdade, e por isso
--- pergunta o mesmo par de âncoras a `ResolveTrailing`. As texturas são criadas
--- uma vez, no limite da prévia, e escondidas quando sobram: criar frame a cada
--- ajuste de controle deslizante seria criar dezenas por segundo.
---@param bar table
---@return table
local function BuildAuras(bar)
	local icons = {}

	for index = 1, PREVIEW_AURA_CEILING do
		local texture = bar:CreateTexture(nil, "ARTWORK")
		texture:SetTexture(SAMPLE_AURAS[(index - 1) % #SAMPLE_AURAS + 1])
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		texture:Hide()

		icons[index] = texture
	end

	local auras = {}

	---@param preferences Preferences
	function auras:Refresh(preferences)
		local filters = Addon.AuraFilters.Resolve(preferences:Get(Keys.AURA_FILTER))
		local wanted = preferences:Get(Keys.AURA_MAX_COUNT) * #filters

		if not preferences:Get(Keys.OWN_AURAS) then
			wanted = 0
		end

		local size = preferences:Get(Keys.AURA_ICON_SIZE)
		local spacing = preferences:Get(Keys.AURA_ICON_SPACING)
		local anchor = Addon.AnchorPoints.ResolveTrailing(preferences:Get(Keys.AURA_ANCHOR_POINT))
		local offsetX = preferences:Get(Keys.AURA_OFFSET_X)
		local offsetY = preferences:Get(Keys.AURA_OFFSET_Y)
		local step = (anchor.point:find("RIGHT", 1, true) and -1 or 1) * (size + spacing)

		for index, texture in ipairs(icons) do
			if index > wanted then
				texture:Hide()
			else
				texture:SetSize(size, size)
				texture:ClearAllPoints()
				texture:SetPoint(
					anchor.point,
					bar,
					anchor.relativePoint,
					offsetX + (index - 1) * step,
					offsetY
				)
				texture:Show()
			end
		end
	end

	return auras
end

--- Uma placa de mentira que responde às preferências de verdade.
---
--- Nada aqui pergunta o estado do jogo: a prévia precisa desenhar sem alvo, sem
--- combate e sem nameplate na tela — que é exatamente a situação de quem acabou
--- de instalar o addon e abriu a apresentação.
---@param parent table
---@param preferences Preferences
---@param width number
---@return table
function NameplatePreview.Build(parent, preferences, width)
	local stage = BuildStage(parent, width)
	local bar = BuildBar(stage)

	local parts = {
		BuildName(bar),
		BuildHealth(bar),
		BuildIcon(bar),
		BuildAuras(bar),
	}

	function stage:Refresh()
		for _, part in ipairs(parts) do
			part:Refresh(preferences)
		end
	end

	stage:Refresh()

	return stage
end

Addon.NameplatePreview = NameplatePreview
