local _, Addon = ...

---@class MainPanel
local MainPanel = {}

---@param catalog Preference[]
---@return (SchematicCell[]|string)[]
local function SwitchRows(catalog)
	local rows = {}

	for index, preference in ipairs(Addon.PreferenceLookup.Roots(catalog)) do
		if index > 1 then
			table.insert(rows, "divider")
		end

		table.insert(rows, { { key = preference.key, span = 2 } })
	end

	return rows
end

---@param entries { label: string, value: string }[]
---@return SchematicCell[][]
local function FactRows(entries)
	local rows = {}

	for _, entry in ipairs(entries) do
		table.insert(rows, { { style = "fact", label = entry.label, value = entry.value, span = 2 } })
	end

	return rows
end

--- O botão que reabre a apresentação da primeira vez. Vive nas opções porque a
--- janela nasce com "não mostrar novamente" marcado: sem uma porta de volta
--- visível, rever seria só para quem decorou o comando de barra.
---@param commands { openWelcome: fun() }
---@return fun(parent: table, width: number): table
local function WelcomeCell(commands)
	return function(parent, width)
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetWidth(width)

		local button = Addon.OptionsControls.Button(frame, {
			label = Addon.L.MAIN_WELCOME_BUTTON,
			run = commands.openWelcome,
		})
		button:SetPoint("TOPLEFT")

		frame:SetHeight(button:GetHeight())

		function frame:Refresh() end

		return frame
	end
end

---@param addonInfo AddonInfo
---@param catalog Preference[]
---@param preferences Preferences
---@param entries { label: string, value: string }[]
---@param commands { openWelcome: fun() }?
---@return table category
function MainPanel.Register(addonInfo, catalog, preferences, entries, commands)
	local page = Addon.OptionsPage.New({
		title = addonInfo.title,
		subtitle = Addon.L.INFO_SUBTITLE,
	})

	local rows = SwitchRows(catalog)

	if commands and commands.openWelcome then
		table.insert(rows, "divider")
		table.insert(rows, { { build = WelcomeCell(commands), span = 2 } })
	end

	page:Mount({
		{ title = Addon.L.SECTION_GENERAL, rows = rows },
		{ title = Addon.L.SECTION_ABOUT, rows = FactRows(entries) },
	}, { catalog = catalog, preferences = preferences })

	return page:RegisterAsRoot(addonInfo.brand)
end

Addon.MainPanel = MainPanel
