local _, Addon = ...

local Theme = Addon.OptionsTheme
local Fonts = Addon.OptionsFonts

local WHITE = [[Interface\Buttons\WHITE8X8]]

local SWITCH_TEXT_GAP = 16
local HINT_GAP = 3
local BLOCK_CONTROL_TOP = 18
local ROW_CONTROL_WIDTH = 220
local WHEEL_STEP = 40

---@class OptionsPage
---@field frame table
---@field private refreshables table[]
---@field private sections table[] Os cartões montados, para o empilhamento poder ser refeito.
---@field private keys string[] The preferences the page shows, in the order they were added.
local OptionsPage = {}
OptionsPage.__index = OptionsPage

---@param options { title: string, subtitle: string?, icon: string? }
---@return OptionsPage
function OptionsPage.New(options)
	local frame = CreateFrame("Frame")
	frame.name = options.title

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetColorTexture(
		Theme.PAGE_COLOR.red,
		Theme.PAGE_COLOR.green,
		Theme.PAGE_COLOR.blue,
		Theme.PAGE_COLOR.alpha
	)
	background:SetAllPoints()

	Addon.OptionsHeader.Build(frame, options)

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", 0, -Theme.SCROLL_TOP)
	scroll:SetPoint("BOTTOMRIGHT")

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)

	scroll:SetScript("OnSizeChanged", function(_, width)
		content:SetWidth(width)
	end)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(owner, delta)
		local hidden = math.max(0, content:GetHeight() - owner:GetHeight())
		local wanted = owner:GetVerticalScroll() - delta * WHEEL_STEP

		owner:SetVerticalScroll(math.min(math.max(wanted, 0), hidden))
	end)

	local page = setmetatable(
		{ frame = frame, content = content, refreshables = {}, keys = {}, sections = {} },
		OptionsPage
	)

	frame:SetScript("OnShow", function()
		page:Layout()
		page:Refresh()
	end)

	return page
end

---@param bottom number
function OptionsPage:GrowContent(bottom)
	self.content:SetHeight(math.max(self.content:GetHeight(), bottom))
end

---@param refreshable table Qualquer coisa com Refresh().
function OptionsPage:AddRefresh(refreshable)
	table.insert(self.refreshables, refreshable)
end

--- Reads every drawn control again. Runs when the page shows and after a reset,
--- which changes the values under controls that are already built.
function OptionsPage:Refresh()
	for _, refreshable in ipairs(self.refreshables) do
		refreshable:Refresh()
	end
end

---@param options { title: string?, top: number }
---@return table box
function OptionsPage:AddCard(options)
	local box = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
	box:SetBackdrop({
		bgFile = WHITE,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	box:SetBackdropColor(
		Theme.CARD_BACKGROUND_COLOR.red,
		Theme.CARD_BACKGROUND_COLOR.green,
		Theme.CARD_BACKGROUND_COLOR.blue,
		Theme.CARD_BACKGROUND_COLOR.alpha
	)
	box:SetBackdropBorderColor(
		Theme.BORDER_STRONG_COLOR.red,
		Theme.BORDER_STRONG_COLOR.green,
		Theme.BORDER_STRONG_COLOR.blue,
		Theme.BORDER_STRONG_COLOR.alpha
	)
	box:SetPoint("TOPLEFT", Theme.PADDING, -options.top)
	box:SetPoint("TOPRIGHT", -Theme.PADDING, -options.top)

	if options.title then
		local eyebrow = box:CreateFontString(nil, "ARTWORK")
		eyebrow:SetFontObject(Fonts.EYEBROW)
		eyebrow:SetPoint("TOPLEFT", Theme.CARD_PADDING, -Theme.CARD_PADDING)
		eyebrow:SetText(options.title)
		eyebrow:SetTextColor(
			Theme.ACCENT_COLOR.red,
			Theme.ACCENT_COLOR.green,
			Theme.ACCENT_COLOR.blue
		)
	end

	return box
end

---@param preference Preference
---@param preferences Preferences
---@return SchematicCell
local function FromPreference(cell, preference, preferences)
	local resolved = {
		-- Carried over so a cell can draw itself and still be a preference: the
		-- page's "Defaults" button restores every key it mounted, and a cell
		-- without one would sit outside that.
		build = cell.build,
		label = cell.label or preference.label,
		hint = cell.hint or preference.tooltip,
		span = cell.span,
		style = cell.style,
		controlWidth = cell.controlWidth,
		suffix = cell.suffix,
		choices = cell.choices or preference.choices and function()
			return preference.choices
		end,
		minimum = preference.minimum,
		maximum = cell.maximum or preference.maximum,
		step = preference.step,
		isEnabled = cell.isEnabled,
	}

	if preference.kind == "color" then
		resolved.style = resolved.style or "swatch"
		resolved.get = function()
			return Addon.HexColor.ToRGB(preferences:Get(preference.key))
		end
		resolved.set = function(red, green, blue)
			preferences:Set(preference.key, Addon.HexColor.FromRGB(red, green, blue))
		end

		return resolved
	end

	resolved.get = function()
		return preferences:Get(preference.key)
	end
	resolved.set = function(value)
		preferences:Set(preference.key, value)
	end

	if resolved.choices then
		resolved.style = resolved.style or "dropdown"
	elseif preference.kind == "boolean" then
		resolved.style = resolved.style or "switch"
	else
		resolved.style = resolved.style or "slider"
	end

	return resolved
end

--- A altura volta duas vezes: o valor de agora, e — quando ela pode mudar — um
--- fecho que a calcula de novo. Perguntar ao frame se ele sabe se remedir não
--- serve: um frame do cliente responde a qualquer nome.
---@param card table
---@param cell SchematicCell
---@param width number
---@return table frame
---@return number height
---@return (fun(): number)? measure
local function BuildCell(card, cell, width)
	if cell.build then
		local frame = cell.build(card, width, cell)

		return frame, frame:GetHeight()
	end

	if cell.style == "slider" then
		local slider = Addon.OptionsControls.Slider(card, cell)
		slider:SetWidth(width)

		return slider, slider:GetHeight()
	end

	if cell.style == "fact" then
		return Addon.OptionsControls.Fact(card, cell), Theme.FACT_LINE_HEIGHT
	end

	local frame = CreateFrame("Frame", nil, card)
	frame:SetWidth(width)

	if cell.style == "switch" then
		local label = frame:CreateFontString(nil, "ARTWORK")
		label:SetFontObject(Fonts.LABEL)
		label:SetPoint("TOPLEFT")
		label:SetText(cell.label)
		label:SetTextColor(Theme.TEXT_COLOR.red, Theme.TEXT_COLOR.green, Theme.TEXT_COLOR.blue)

		local switch = Addon.OptionsControls.Switch(frame, cell)
		switch:SetPoint("TOPRIGHT")

		local hint

		if cell.hint then
			hint = frame:CreateFontString(nil, "ARTWORK")
			hint:SetFontObject(Fonts.HINT)
			hint:SetPoint("TOPLEFT", 0, -(label:GetStringHeight() + HINT_GAP))
			hint:SetWidth(width - Theme.SWITCH_WIDTH - SWITCH_TEXT_GAP)
			hint:SetJustifyH("LEFT")
			hint:SetText(cell.hint)
			hint:SetTextColor(Theme.HINT_COLOR.red, Theme.HINT_COLOR.green, Theme.HINT_COLOR.blue)
		end

		--- Medida de novo a cada vez que a página aparece: a altura de um texto
		--- que quebra em duas linhas só é verdade depois de o frame existir na
		--- tela — no carregamento ela volta como uma linha só, e as linhas
		--- seguintes empilhariam por cima.
		local function Measure()
			local measured = label:GetStringHeight()

			if hint then
				hint:ClearAllPoints()
				hint:SetPoint("TOPLEFT", 0, -(measured + HINT_GAP))
				measured = measured + HINT_GAP + hint:GetStringHeight()
			end

			measured = math.max(measured, Theme.SWITCH_HEIGHT)
			frame:SetHeight(measured)

			return measured
		end

		frame.Refresh = function()
			switch:Refresh()
		end

		return frame, Measure(), Measure
	end

	local label = frame:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(Fonts.LABEL)
	label:SetText(cell.label)
	label:SetTextColor(Theme.TEXT_COLOR.red, Theme.TEXT_COLOR.green, Theme.TEXT_COLOR.blue)

	if cell.style == "dropdownRow" then
		label:SetPoint("LEFT")

		local dropdown = Addon.OptionsControls.Dropdown(frame, {
			width = cell.controlWidth or ROW_CONTROL_WIDTH,
			choices = cell.choices,
			get = cell.get,
			set = cell.set,
		})
		dropdown:SetPoint("RIGHT")

		frame:SetHeight(Theme.INPUT_HEIGHT)
		frame.Refresh = function()
			dropdown:Refresh()
		end

		return frame, Theme.INPUT_HEIGHT
	end

	label:SetPoint("TOPLEFT")

	local control

	if cell.style == "swatch" then
		control = Addon.OptionsControls.ColorSwatch(frame, cell)
	else
		control = Addon.OptionsControls.Dropdown(frame, {
			width = width,
			choices = cell.choices,
			get = cell.get,
			set = cell.set,
		})
	end

	control:SetPoint("TOPLEFT", 0, -BLOCK_CONTROL_TOP)

	local height = BLOCK_CONTROL_TOP + Theme.INPUT_HEIGHT
	frame:SetHeight(height)
	frame.Refresh = function()
		control:Refresh()
	end

	return frame, height
end

--- Empilha o que já foi construído, a partir das alturas de agora.
---
--- Separada da montagem de propósito: os frames nascem uma vez, e as posições
--- são refeitas toda vez que a página aparece, porque só então os textos sabem
--- dizer a própria altura.
---@private
function OptionsPage:Layout()
	local top = Theme.CARD_TOP

	for _, section in ipairs(self.sections) do
		local y = Theme.CARD_PADDING + (section.hasTitle and Theme.CARD_TITLE_BLOCK or 0)
		local items = {}

		for _, entry in ipairs(section.entries) do
			if entry.divider then
				entry.divider:ClearAllPoints()
				entry.divider:SetPoint("TOPLEFT", Theme.CARD_PADDING, -y)
				entry.divider:SetPoint("TOPRIGHT", -Theme.CARD_PADDING, -y)

				table.insert(items, Theme.RULE_THICKNESS)
				y = y + Theme.RULE_THICKNESS + Theme.ROW_GAP
			else
				local rowHeight = 0

				for column, frame in ipairs(entry.frames) do
					local height = entry.measures[column]()

					frame:ClearAllPoints()
					frame:SetPoint(
						"TOPLEFT",
						Theme.CARD_PADDING + (column - 1) * Theme.COLUMN_OFFSET,
						-y
					)

					rowHeight = math.max(rowHeight, height)
				end

				table.insert(items, rowHeight)
				y = y + rowHeight + Theme.ROW_GAP
			end
		end

		local height = Addon.OptionsSchematic.CardHeight(
			Addon.OptionsSchematic.ContentHeight(items, Theme.ROW_GAP),
			section.hasTitle,
			{ cardPadding = Theme.CARD_PADDING, titleBlock = Theme.CARD_TITLE_BLOCK }
		)

		section.card:SetHeight(height)
		section.card:ClearAllPoints()
		section.card:SetPoint("TOPLEFT", Theme.PADDING, -top)
		section.card:SetPoint("TOPRIGHT", -Theme.PADDING, -top)

		top = top + height + Theme.CARD_GAP
	end

	self.content:SetHeight(top)
end

---@param schematic Schematic
---@param context { catalog: Preference[]?, preferences: Preferences? }
function OptionsPage:Mount(schematic, context)
	context = context or {}

	for _, section in ipairs(schematic) do
		local card = self:AddCard({ title = section.title, top = Theme.CARD_TOP })
		local entries = {}

		for _, row in ipairs(section.rows) do
			if row == "divider" then
				local divider = card:CreateTexture(nil, "ARTWORK")
				divider:SetColorTexture(
					Theme.DIVIDER_COLOR.red,
					Theme.DIVIDER_COLOR.green,
					Theme.DIVIDER_COLOR.blue,
					Theme.DIVIDER_COLOR.alpha
				)
				divider:SetHeight(Theme.RULE_THICKNESS)

				table.insert(entries, { divider = divider })
			else
				local frames = {}
				local measures = {}

				for _, cell in ipairs(row) do
					if cell.key then
						table.insert(self.keys, cell.key)

						cell = FromPreference(
							cell,
							Addon.PreferenceLookup.Find(context.catalog, cell.key),
							context.preferences
						)
					end

					local width = cell.span == 2
						and Theme.COLUMN_WIDTH * 2 + Theme.COLUMN_GUTTER
						or cell.width or Theme.COLUMN_WIDTH

					local frame, height, measure = BuildCell(card, cell, width)

					if frame.Refresh then
						self:AddRefresh(frame)
					end

					table.insert(frames, frame)
					table.insert(measures, measure or function()
						return height
					end)
				end

				table.insert(entries, { frames = frames, measures = measures })
			end
		end

		table.insert(self.sections, { card = card, hasTitle = section.title ~= nil, entries = entries })
	end

	self:Layout()

	if context.preferences and #self.keys > 0 then
		self:AddDefaultsButton(context.preferences)
	end
end

--- In the header corner, where the game puts its own, and restoring only what
--- this page shows, so redoing the frame does not take the rest with it.
---@private
---@param preferences Preferences
function OptionsPage:AddDefaultsButton(preferences)
	local page = self
	local button = Addon.OptionsControls.Button(self.frame, {
		label = Addon.L.PAGE_DEFAULTS,
		run = function()
			Addon.ConfirmPrompt.Ask(Addon.L.PAGE_DEFAULTS_QUESTION:format(page.frame.name), function()
				preferences:Reset(page.keys)
				page:Refresh()
			end)
		end,
	})

	button:SetPoint("TOPRIGHT", -Theme.PADDING, -Theme.HEADER_TOP)
end

---@param name string
---@return table category
function OptionsPage:RegisterAsRoot(name)
	return Settings.RegisterCanvasLayoutCategory(self.frame, name)
end

---@param category table
---@return table subcategory
function OptionsPage:RegisterUnder(category)
	return (Settings.RegisterCanvasLayoutSubcategory(category, self.frame, self.frame.name))
end

Addon.OptionsPage = OptionsPage
