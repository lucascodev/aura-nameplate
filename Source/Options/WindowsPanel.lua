local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Os quadros de unidade próprios, e não as nameplates: janela de jogador,
--- alvo, foco e alvo do alvo, cada uma com o próprio interruptor.
---@class WindowsPanel
local WindowsPanel = {}

--- O botão que liga o posicionamento, com a dica de como ele funciona.
---@param commands { toggleEditing: fun() }
---@return fun(parent: table, width: number): table
local function EditCell(commands)
	return function(parent, width)
		local Fonts = Addon.OptionsFonts
		local Theme = Addon.OptionsTheme

		local frame = CreateFrame("Frame", nil, parent)
		frame:SetWidth(width)

		local button = Addon.OptionsControls.Button(frame, {
			label = Addon.L.WINDOWS_EDIT_BUTTON,
			run = commands.toggleEditing,
			variant = "primary",
		})
		button:SetPoint("TOPLEFT")

		local hint = frame:CreateFontString(nil, "ARTWORK")
		hint:SetFontObject(Fonts.HINT)
		hint:SetPoint("LEFT", button, "RIGHT", 10, 0)
		hint:SetPoint("RIGHT")
		hint:SetJustifyH("LEFT")
		hint:SetText(Addon.L.WINDOWS_EDIT_HINT)
		hint:SetTextColor(Theme.HINT_COLOR.red, Theme.HINT_COLOR.green, Theme.HINT_COLOR.blue)

		frame:SetHeight(28)

		function frame:Refresh() end

		return frame
	end
end

---@param category table
---@param catalog Preference[]
---@param preferences Preferences
---@param commands { toggleEditing: fun() }
---@return table subcategory
function WindowsPanel.Register(category, catalog, preferences, commands)
	local page = Addon.OptionsPage.New({
		title = Addon.L.PAGE_WINDOWS,
		subtitle = Addon.L.PAGE_WINDOWS_HINT,
	})

	page:Mount({
		{
			title = Addon.L.SECTION_WINDOWS,
			rows = {
				{ { key = Keys.WINDOW_PLAYER, span = 2 } },
				"divider",
				{ { key = Keys.WINDOW_TARGET, span = 2 } },
				"divider",
				{ { key = Keys.WINDOW_FOCUS, span = 2 } },
				"divider",
				{ { key = Keys.WINDOW_TOT, span = 2 } },
			},
		},
		{
			title = Addon.L.SECTION_WINDOWS_POSITION,
			rows = {
				{ { build = EditCell(commands), span = 2 } },
			},
		},
		{
			title = Addon.L.SECTION_WINDOWS_LOOK,
			rows = {
				{ { key = Keys.WINDOW_PORTRAIT, span = 2 } },
				"divider",
				{
					{ key = Keys.WINDOW_PLAYER_CLASS_COLOR },
					{ key = Keys.WINDOW_PLAYER_COLOR },
				},
				{
					{ key = Keys.WINDOW_TARGET_CLASS_COLOR },
					{ key = Keys.WINDOW_TARGET_COLOR },
				},
				{
					{ key = Keys.WINDOW_FOCUS_CLASS_COLOR },
					{ key = Keys.WINDOW_FOCUS_COLOR },
				},
				{
					{ key = Keys.WINDOW_TOT_CLASS_COLOR },
					{ key = Keys.WINDOW_TOT_COLOR },
				},
			},
		},
		{
			title = Addon.L.SECTION_WINDOWS_BLIZZARD,
			rows = {
				{ { key = Keys.WINDOW_HIDE_BLIZZARD, span = 2 } },
			},
		},
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterUnder(category)
end

Addon.WindowsPanel = WindowsPanel
