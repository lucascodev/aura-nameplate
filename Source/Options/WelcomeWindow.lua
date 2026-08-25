local _, Addon = ...

local Keys = Addon.PreferenceKeys
local Theme = Addon.OptionsTheme
local Fonts = Addon.OptionsFonts

--- Nomeado porque `UISpecialFrames` guarda nomes, e é ele que faz o Esc fechar.
local FRAME_NAME = "AuraNameplateWelcomeWindow"

local WHITE = [[Interface\Buttons\WHITE8X8]]

local WINDOW_WIDTH = 620
local ROW_HEIGHT = 34
local CONTROL_WIDTH = 210
local FOOTER_HEIGHT = 64
local PREVIEW_GAP = 14
local CARD_EYEBROW_BLOCK = 46
local CARD_HINT_BLOCK = 30
local BUTTON_GAP = 8

--- As etapas, uma decisão por vez.
---
--- Um assistente, e não um formulário: sete perguntas de uma vez é uma parede,
--- e quem acabou de instalar não tem contexto para atravessá-la. Cada etapa
--- apresenta um pedaço do addon, pergunta o mínimo, e a prévia responde na
--- hora — o resto continua nas opções, onde há espaço para tudo.
local STEPS = {
	{
		title = "WELCOME_STEP_ICON",
		hint = "WELCOME_STEP_ICON_HINT",
		rows = { { key = Keys.VISIBILITY_MODE } },
	},
	{
		title = "WELCOME_STEP_HEALTH",
		hint = "WELCOME_STEP_HEALTH_HINT",
		rows = {
			{ key = Keys.HEALTH_TEXT_ENABLED },
			{ key = Keys.HEALTH_TEXT_FORMAT },
			{ key = Keys.NAME_ABOVE_BAR },
		},
	},
	{
		title = "WELCOME_STEP_AURAS",
		hint = "WELCOME_STEP_AURAS_HINT",
		rows = {
			{ key = Keys.OWN_AURAS },
			{ key = Keys.AURA_FILTER },
		},
	},
	{
		title = "WELCOME_STEP_PLATES",
		hint = "WELCOME_STEP_PLATES_HINT",
		rows = {
			{ key = Keys.PLATES_FRIENDLY_PLAYERS },
			{ key = Keys.PLATES_FRIENDLY_NPCS },
			{ key = Keys.PLATES_STACKED },
			{ key = Keys.HIDE_FRIENDLY_IN_COMBAT },
		},
	},
	{
		title = "WELCOME_STEP_WINDOWS",
		hint = "WELCOME_STEP_WINDOWS_HINT",
		rows = {
			{ key = Keys.WINDOW_PLAYER },
			{ key = Keys.WINDOW_TARGET },
			{ key = Keys.WINDOW_FOCUS },
			{ key = Keys.WINDOW_TOT },
		},
	},
	{
		title = "WELCOME_STEP_EXTRAS",
		hint = "WELCOME_STEP_EXTRAS_HINT",
		rows = { { key = Keys.SHOW_MINIMAP_BUTTON } },
	},
}

--- Uma janela que aparece uma vez, na primeira execução, e conduz por etapas.
---@class WelcomeWindow
---@field private preferences Preferences
---@field private firstRun FirstRun
---@field private openOptions fun()
---@field private frame table?
---@field private stepIndex number
local WelcomeWindow = {}
WelcomeWindow.__index = WelcomeWindow

---@param preferences Preferences
---@param firstRun FirstRun
---@param openOptions fun()
---@return WelcomeWindow
function WelcomeWindow.New(preferences, firstRun, openOptions)
	return setmetatable({
		preferences = preferences,
		firstRun = firstRun,
		openOptions = openOptions,
		stepIndex = 1,
	}, WelcomeWindow)
end

---@param region table
---@param color table
local function Tint(region, color)
	region:SetTextColor(color.red, color.green, color.blue)
end

--- Uma pergunta por linha: rótulo à esquerda, controle à direita. O tipo do
--- controle sai do catálogo, não de uma escolha repetida aqui.
---@param parent table
---@param preference Preference
---@param preferences Preferences
---@param onChange fun()
---@return table
local function BuildRow(parent, preference, preferences, onChange)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)

	local label = row:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(Fonts.LABEL)
	label:SetPoint("LEFT")
	label:SetText(preference.label)
	Tint(label, Theme.TEXT_COLOR)

	local control

	if preference.choices then
		control = Addon.OptionsControls.Dropdown(row, {
			width = CONTROL_WIDTH,
			choices = function()
				return preference.choices
			end,
			get = function()
				return preferences:Get(preference.key)
			end,
			set = function(value)
				preferences:Set(preference.key, value)
				onChange()
			end,
		})
	else
		control = Addon.OptionsControls.Switch(row, {
			get = function()
				return preferences:Get(preference.key)
			end,
			set = function(value)
				preferences:Set(preference.key, value)
				onChange()
			end,
		})
	end

	control:SetPoint("RIGHT")

	function row:Refresh()
		control:Refresh()
	end

	return row
end

--- O cabeçalho, com a mesma régua das páginas de opção.
---@param frame table
local function BuildHeader(frame)
	local title = frame:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(Fonts.TITLE)
	title:SetPoint("TOPLEFT", Theme.PADDING, -Theme.HEADER_TOP)
	title:SetText(Addon.L.WELCOME_TITLE)
	Tint(title, Theme.TEXT_COLOR)

	local subtitle = frame:CreateFontString(nil, "ARTWORK")
	subtitle:SetFontObject(Fonts.SUBTITLE)
	subtitle:SetPoint("TOPLEFT", Theme.PADDING, -Theme.HEADER_SUBTITLE_GAP)
	subtitle:SetPoint("RIGHT", -Theme.PADDING, 0)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText(Addon.L.WELCOME_SUBTITLE)
	Tint(subtitle, Theme.MUTED_COLOR)

	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(
		Theme.BORDER_COLOR.red,
		Theme.BORDER_COLOR.green,
		Theme.BORDER_COLOR.blue,
		Theme.BORDER_COLOR.alpha
	)
	rule:SetHeight(Theme.RULE_THICKNESS)
	rule:SetPoint("TOPLEFT", Theme.PADDING, -Theme.HEADER_RULE_GAP)
	rule:SetPoint("TOPRIGHT", -Theme.PADDING, -Theme.HEADER_RULE_GAP)

	local accent = frame:CreateTexture(nil, "OVERLAY")
	accent:SetColorTexture(
		Theme.ACCENT_COLOR.red,
		Theme.ACCENT_COLOR.green,
		Theme.ACCENT_COLOR.blue,
		Theme.ACCENT_COLOR.alpha
	)
	accent:SetSize(Theme.HEADER_ACCENT_WIDTH, Theme.RULE_THICKNESS)
	accent:SetPoint("TOPLEFT", rule, "TOPLEFT")
end

--- O cartão de uma etapa: número, título, uma linha de contexto e as perguntas
--- dela, separadas por divisórias — a mesma gramática das páginas de opções.
---@param frame table
---@param step table
---@param stepIndex number
---@param preferences Preferences
---@param onChange fun()
---@return table card, table[] rows
local function BuildStepCard(frame, step, stepIndex, preferences, onChange)
	local card = CreateFrame("Frame", nil, frame, "BackdropTemplate")

	card:SetBackdrop({
		bgFile = WHITE,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	card:SetBackdropColor(
		Theme.CARD_BACKGROUND_COLOR.red,
		Theme.CARD_BACKGROUND_COLOR.green,
		Theme.CARD_BACKGROUND_COLOR.blue,
		Theme.CARD_BACKGROUND_COLOR.alpha
	)
	card:SetBackdropBorderColor(
		Theme.BORDER_STRONG_COLOR.red,
		Theme.BORDER_STRONG_COLOR.green,
		Theme.BORDER_STRONG_COLOR.blue,
		Theme.BORDER_STRONG_COLOR.alpha
	)

	local eyebrow = card:CreateFontString(nil, "ARTWORK")
	eyebrow:SetFontObject(Fonts.EYEBROW)
	eyebrow:SetPoint("TOPLEFT", Theme.CARD_PADDING, -Theme.CARD_PADDING)
	eyebrow:SetText((Addon.L.WELCOME_STEP_COUNT):format(stepIndex, #STEPS))
	Tint(eyebrow, Theme.ACCENT_COLOR)

	local title = card:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(Fonts.STRONG)
	title:SetPoint("TOPLEFT", Theme.CARD_PADDING, -(Theme.CARD_PADDING + 18))
	title:SetText(Addon.L[step.title])
	Tint(title, Theme.TEXT_COLOR)

	local hint = card:CreateFontString(nil, "ARTWORK")
	hint:SetFontObject(Fonts.HINT)
	hint:SetPoint("TOPLEFT", Theme.CARD_PADDING, -(Theme.CARD_PADDING + CARD_EYEBROW_BLOCK - 10))
	hint:SetPoint("RIGHT", -Theme.CARD_PADDING, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText(Addon.L[step.hint])
	Tint(hint, Theme.HINT_COLOR)

	local rows = {}
	local top = Theme.CARD_PADDING + CARD_EYEBROW_BLOCK + CARD_HINT_BLOCK

	for index, entry in ipairs(step.rows) do
		local preference = Addon.PreferenceLookup.Find(Addon.PreferenceCatalog, entry.key)
		local row = BuildRow(card, preference, preferences, onChange)
		local y = top + (index - 1) * ROW_HEIGHT

		row:SetPoint("TOPLEFT", Theme.CARD_PADDING, -y)
		row:SetPoint("TOPRIGHT", -Theme.CARD_PADDING, -y)

		if index > 1 then
			local divider = card:CreateTexture(nil, "ARTWORK")
			divider:SetColorTexture(
				Theme.DIVIDER_COLOR.red,
				Theme.DIVIDER_COLOR.green,
				Theme.DIVIDER_COLOR.blue,
				Theme.DIVIDER_COLOR.alpha
			)
			divider:SetHeight(Theme.RULE_THICKNESS)
			divider:SetPoint("TOPLEFT", Theme.CARD_PADDING, -y)
			divider:SetPoint("TOPRIGHT", -Theme.CARD_PADDING, -y)
		end

		rows[index] = row
	end

	return card, rows
end

--- A altura que abriga a etapa mais cheia, para a janela não pular de tamanho
--- entre um passo e o outro.
---@return number
local function StepAreaHeight()
	local most = 0

	for _, step in ipairs(STEPS) do
		most = math.max(most, #step.rows)
	end

	return Theme.CARD_PADDING * 2 + CARD_EYEBROW_BLOCK + CARD_HINT_BLOCK + most * ROW_HEIGHT
end

--- O rodapé: a decisão de não rever à esquerda, a navegação à direita.
---@param frame table
---@param window WelcomeWindow
---@return table checkbox
local function BuildFooter(frame, window)
	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(
		Theme.DIVIDER_COLOR.red,
		Theme.DIVIDER_COLOR.green,
		Theme.DIVIDER_COLOR.blue,
		Theme.DIVIDER_COLOR.alpha
	)
	rule:SetHeight(Theme.RULE_THICKNESS)
	rule:SetPoint("BOTTOMLEFT", Theme.PADDING, FOOTER_HEIGHT)
	rule:SetPoint("BOTTOMRIGHT", -Theme.PADDING, FOOTER_HEIGHT)

	local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	checkbox:SetSize(Theme.SWITCH_WIDTH, Theme.SWITCH_HEIGHT)
	checkbox:SetPoint("BOTTOMLEFT", Theme.PADDING, 20)

	if checkbox.Text then
		checkbox.Text:SetText("")
	end

	local caption = frame:CreateFontString(nil, "ARTWORK")
	caption:SetFontObject(Fonts.LABEL)
	caption:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	caption:SetText(Addon.L.WELCOME_DISMISS)
	Tint(caption, Theme.TEXT_COLOR)

	local hint = frame:CreateFontString(nil, "ARTWORK")
	hint:SetFontObject(Fonts.HINT)
	hint:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -2)
	hint:SetText(Addon.L.WELCOME_DISMISS_HINT)
	Tint(hint, Theme.HINT_COLOR)

	-- Criado com o rótulo mais largo que vai carregar, para não mudar de
	-- tamanho quando o texto trocar no último passo.
	local primary = Addon.OptionsControls.Button(frame, {
		label = Addon.L.WELCOME_START,
		run = function()
			window:Advance()
		end,
		variant = "primary",
	})
	primary:SetPoint("BOTTOMRIGHT", -Theme.PADDING, 22)

	local back = Addon.OptionsControls.Button(frame, {
		label = Addon.L.WELCOME_BACK,
		run = function()
			window:Retreat()
		end,
	})
	back:SetPoint("RIGHT", primary, "LEFT", -BUTTON_GAP, 0)

	local options = Addon.OptionsControls.Button(frame, {
		label = Addon.L.WELCOME_OPEN_OPTIONS,
		run = function()
			frame:Hide()
			window.openOptions()
		end,
	})
	options:SetPoint("RIGHT", back, "LEFT", -BUTTON_GAP, 0)

	window.primaryButton = primary
	window.backButton = back
	window.optionsButton = options

	return checkbox
end

--- Mostra a etapa atual e ajusta a navegação a ela.
---@private
function WelcomeWindow:ShowStep()
	for index, card in ipairs(self.cards) do
		card:SetShown(index == self.stepIndex)
	end

	local isLast = self.stepIndex == #STEPS

	self.primaryButton:SetText(isLast and Addon.L.WELCOME_START or Addon.L.WELCOME_CONTINUE)
	self.backButton:SetEnabled(self.stepIndex > 1)
	self.optionsButton:SetShown(isLast)
end

--- Avança; do último passo, fecha — a decisão da caixa vale na saída.
---@private
function WelcomeWindow:Advance()
	if self.stepIndex == #STEPS then
		self.frame:Hide()
		return
	end

	self.stepIndex = self.stepIndex + 1
	self:ShowStep()
end

---@private
function WelcomeWindow:Retreat()
	if self.stepIndex > 1 then
		self.stepIndex = self.stepIndex - 1
		self:ShowStep()
	end
end

--- Montada sob demanda: quem já dispensou a apresentação nunca paga por ela.
---@private
---@return table
function WelcomeWindow:Build()
	local preferences = self.preferences

	local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
	frame:SetFrameStrata("DIALOG")
	frame:SetPoint("CENTER")
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = Theme.RULE_THICKNESS })
	frame:SetBackdropColor(
		Theme.PAGE_COLOR.red,
		Theme.PAGE_COLOR.green,
		Theme.PAGE_COLOR.blue,
		1
	)
	frame:SetBackdropBorderColor(
		Theme.BORDER_STRONG_COLOR.red,
		Theme.BORDER_STRONG_COLOR.green,
		Theme.BORDER_STRONG_COLOR.blue,
		Theme.BORDER_STRONG_COLOR.alpha
	)

	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	BuildHeader(frame)

	local preview = Addon.NameplatePreview.Build(
		frame,
		preferences,
		WINDOW_WIDTH - Theme.PADDING * 2
	)
	preview:SetPoint("TOPLEFT", Theme.PADDING, -Theme.SCROLL_TOP)

	local onChange = function()
		preview:Refresh()
	end

	local areaTop = Theme.SCROLL_TOP + preview:GetHeight() + PREVIEW_GAP
	local areaHeight = StepAreaHeight()

	self.cards = {}
	self.rows = {}

	for index, step in ipairs(STEPS) do
		local card, rows = BuildStepCard(frame, step, index, preferences, onChange)

		card:SetPoint("TOPLEFT", Theme.PADDING, -areaTop)
		card:SetPoint("TOPRIGHT", -Theme.PADDING, -areaTop)
		card:SetHeight(areaHeight)
		card:Hide()

		self.cards[index] = card

		for _, row in ipairs(rows) do
			table.insert(self.rows, row)
		end
	end

	local checkbox = BuildFooter(frame, self)

	frame:SetSize(WINDOW_WIDTH, areaTop + areaHeight + FOOTER_HEIGHT + Theme.PADDING)

	frame:SetScript("OnShow", function()
		-- Marcada por padrão: o comportamento pedido é abrir uma vez. Desmarcar
		-- é a forma de pedir o contrário, e não o caminho normal.
		checkbox:SetChecked(true)

		self.stepIndex = 1
		self:ShowStep()
		preview:Refresh()

		for _, row in ipairs(self.rows) do
			row:Refresh()
		end
	end)

	-- Fechar pelo Esc, pelo botão ou pelo X dá no mesmo: a decisão que vale é a
	-- da caixa no instante em que a janela sai da tela.
	frame:SetScript("OnHide", function()
		self.firstRun:Remember(checkbox:GetChecked() == true)
	end)

	table.insert(UISpecialFrames, FRAME_NAME)

	return frame
end

--- Abre a apresentação, montando-a se ainda não existir.
function WelcomeWindow:Open()
	self.frame = self.frame or self:Build()
	self.frame:Show()
	self.frame:Raise()
end

--- Abre só se for a primeira vez. Quem chama no login não precisa saber a regra.
function WelcomeWindow:OpenOnFirstRun()
	if not self.firstRun:ShouldGreet() then
		return
	end

	self:Open()
end

Addon.WelcomeWindow = WelcomeWindow
