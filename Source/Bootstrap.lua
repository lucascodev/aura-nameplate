--- Aura Nameplate: GCD Tracker
--- Copyright (c) 2026 Lucascodev. MIT licensed. See LICENSE.

local ADDON_NAME, Addon = ...

local Keys = Addon.PreferenceKeys
local L = Addon.L

local ADDON_AUTHOR = "Lucascodev"
local ADDON_LICENSE = "MIT"

local PLAYER = "player"
local TARGET = "target"

--- Each action takes the English term and the translated one, so the player
--- types what is written on their own interface.
local STATUS_ARGUMENTS = { status = true }
local HELP_ARGUMENTS = { help = true, [L.COMMAND_HELP_ARGUMENT] = true }
local TEST_ARGUMENTS = { test = true, [L.COMMAND_TEST_ARGUMENT] = true }
local RESET_ARGUMENTS = { reset = true, [L.COMMAND_RESET_ARGUMENT] = true }
local DIAG_ARGUMENTS = { diag = true, [L.COMMAND_DIAG_ARGUMENT] = true }
local WELCOME_ARGUMENTS = { welcome = true, [L.COMMAND_WELCOME_ARGUMENT] = true }
local MOVE_ARGUMENTS = { move = true, [L.COMMAND_MOVE_ARGUMENT] = true }

local SLASH_COMMANDS = {
	{ command = "/anp", description = L.COMMAND_OPTIONS },
	{ command = "/anp " .. L.COMMAND_HELP_ARGUMENT, description = L.COMMAND_HELP },
	{ command = "/anp status", description = L.COMMAND_STATUS },
	{ command = "/anp " .. L.COMMAND_TEST_ARGUMENT, description = L.COMMAND_TEST },
	{ command = "/anp " .. L.COMMAND_RESET_ARGUMENT, description = L.COMMAND_RESET },
	{ command = "/anp " .. L.COMMAND_DIAG_ARGUMENT, description = L.COMMAND_DIAG },
	{ command = "/anp " .. L.COMMAND_WELCOME_ARGUMENT, description = L.COMMAND_WELCOME },
	{ command = "/anp " .. L.COMMAND_MOVE_ARGUMENT, description = L.COMMAND_MOVE },
}

---@type Startup
local startup
---@type IconDisplay
local display
---@type HealthDisplay
local healthDisplay
---@type NameLayout
local nameLayout
---@type OwnAuras
local auraLayout
---@type WelcomeWindow
local welcomeWindow
---@type PlayerFrameVeil
local playerFrameVeil
---@type PortraitLayout
local portraitLayout
---@type CombatPlates
local combatPlates
---@type UnitWindows
local unitWindows
---@type MinimapButton
local minimapButton
---@type FloatingAnchor
local floatingAnchor
---@type fun()
local applyMinimapVisibility
---@type fun()
local applyPlateVisibility
--- Nada a redesenhar antes de o grafo existir.
---
--- Preferencias mudam durante a propria montagem — o baseline de layout faz
--- exatamente isso — e um redesenho nesse instante encontraria metade dos
--- objetos ainda nil. Comecar sem fazer nada, e so' depois apontar para o
--- desenho de verdade, torna essa janela inofensiva por construcao em vez de
--- depender de a ordem das linhas estar certa.
---@type fun()
local refreshAll = function() end

--- Composition root: the only place allowed to know every concrete implementation.
local function Build()
	local logger = Addon.ChatLogger.New()
	local commands = Addon.SlashCommandRegistry.New(ADDON_NAME)
	local addonInfo = Addon.AddonMetadata.Read()

	-- Before anything reads a media list: our own fonts are among the choices.
	Addon.MediaLibrary.RegisterOwnMedia()

	AuraNameplateDB = AuraNameplateDB or {}

	-- Fora dos perfis: trocar de perfil nao e' instalar o addon de novo.
	local firstRun = Addon.FirstRun.New(AuraNameplateDB)

	local profiles = Addon.Profiles.New(
		AuraNameplateDB,
		("%s - %s"):format(UnitName(PLAYER), GetRealmName())
	)
	local profile = profiles:Current()

	-- The bundled fonts have no CJK glyphs, so on those clients the default
	-- becomes the game font and a saved choice of them is migrated: kept, it
	-- would be unreadable anyway.
	if Addon.ClientFont.PrefersGameFont() then
		local gameFont = Addon.MediaLibrary.GAME_FONT_NAME

		Addon.PreferenceLookup.Find(Addon.PreferenceCatalog, Keys.FONT_NAME).default = gameFont

		if Addon.MediaLibrary.IsBundledLatinFont(profile.settings[Keys.FONT_NAME]) then
			profile.settings[Keys.FONT_NAME] = gameFont
		end
	end

	local preferences = Addon.Preferences.New(
		Addon.PreferenceCatalog,
		profile.settings,
		function(changedKey)
			refreshAll()

			if changedKey == Keys.SHOW_MINIMAP_BUTTON and minimapButton then
				applyMinimapVisibility()
			end

			-- Redesenhar nao alcanca estas: elas mandam no cliente, e o efeito so
			-- existe depois de ele ser avisado.
			if Addon.PlateVisibility.Owns(changedKey) then
				applyPlateVisibility()
			end

			if changedKey == Keys.PLATES_SELF or changedKey == Keys.HIDE_PLAYER_FRAME then
				playerFrameVeil:Refresh()
			end

			if changedKey == Keys.HIDE_FRIENDLY_IN_COMBAT then
				combatPlates:Refresh()
			end
		end
	)

	-- Um layout de fabrica que mudou desde a ultima sessao volta ao padrao uma
	-- vez so'. Anunciado, nunca em silencio: sobrescrever ajuste salvo sem dizer
	-- nada e' pior do que exigir um clique.
	local hasNewLayout = Addon.LayoutBaseline.Apply(preferences, profile)

	-- Antes de qualquer escrita: na primeira vez o que o jogo ja' tem vira o que
	-- nos temos, para o addon nao chegar mudando as nameplates de quem instalou.
	applyPlateVisibility = function()
		Addon.PlateVisibility.Apply(preferences, Addon.PlateCVars.Write)
	end

	combatPlates = Addon.CombatPlates.New(preferences, applyPlateVisibility)

	Addon.PlateVisibility.SeedOnce(preferences, profile, Addon.PlateCVars.Read)

	local history = Addon.CastHistory.New(function()
		return preferences:Get(Keys.HOLD_DURATION)
	end)

	floatingAnchor = Addon.FloatingAnchor.New(profile.floatingPosition)

	local plates = Addon.NameplateTracker.New()
	local anchor = Addon.NameplateAnchor.New(preferences, floatingAnchor, plates)

	---@type AppearanceSources
	local appearance = {
		Font = Addon.MediaLibrary.FontPath,
	}

	local gameState = {
		HasTarget = function()
			return UnitExists(TARGET) == true
		end,
		IsInCombat = function()
			return InCombatLockdown() == true
		end,
		Now = GetTime,
	}

	local iconFrame = Addon.SpellIconFrame.New()
	local healthFrames = Addon.HealthTextPool.New()

	display = Addon.IconDisplay.New({
		history = history,
		renderer = iconFrame,
		preferences = preferences,
		hosts = anchor,
		cooldowns = Addon.GlobalCooldown,
		appearance = appearance,
		gameState = gameState,
	})

	healthDisplay = Addon.HealthDisplay.New({
		renderers = healthFrames,
		preferences = preferences,
		hosts = anchor,
		health = Addon.UnitHealthReading,
		appearance = appearance,
		gameState = gameState,
	})

	nameLayout = Addon.NameLayout.New(anchor, preferences)
	playerFrameVeil = Addon.PlayerFrameVeil.New(preferences)
	portraitLayout = Addon.PortraitLayout.New(anchor, preferences)
	unitWindows = Addon.UnitWindows.New(profile.windowPositions, preferences, appearance)
	auraLayout = Addon.OwnAuras.New(anchor, preferences, appearance)

	-- Cada estagio protegido e com o erro guardado: um estagio estourando
	-- derrubaria os seguintes em silencio, porque o cliente vem com os erros
	-- de Lua desligados.
	local pipeline = {
		{ name = "names", draw = function() nameLayout:Refresh() end },
		{ name = "portraits", draw = function() portraitLayout:Refresh() end },
		{ name = "windows", draw = function() unitWindows:Refresh() end },
		{ name = "auras", draw = function() auraLayout:Refresh() end },
		{ name = "icon", draw = function() display:Refresh() end },
		{ name = "health", draw = function() healthDisplay:Refresh() end },
	}
	local refreshFailures = {}

	refreshAll = function()
		for _, stage in ipairs(pipeline) do
			local ok, failure = pcall(stage.draw)

			refreshFailures[stage.name] = not ok and tostring(failure) or nil
		end
	end

	local events = Addon.CastEvents.New(function()
		refreshAll()

		-- O ícone expira por tempo, mas expirar não gera evento nenhum: sem um
		-- redesenho marcado para o vencimento, a última magia fica congelada na
		-- tela até o próximo evento — que fora de combate pode nunca vir.
		C_Timer.After(preferences:Get(Keys.HOLD_DURATION) + 0.1, refreshAll)
	end, function(unit)
		history:Forget(unit)
	end)

	-- Health moves far more often than anything the icon reacts to, so it gets
	-- its own funnel and redraws only its own line.
	Addon.HealthEvents.New(function()
		healthDisplay:Refresh()
	end):Start()

	-- Placas entrando e saindo mudam quem tem linha de vida e quem tem nome
	-- levantado, entao os dois redesenham junto.
	plates:Start(function()
		refreshAll()
	end)

	--- Booking the expiry as the cast is recorded is what makes the icon leave
	--- on its own: nothing in the client fires when a spell has been on screen
	--- long enough.
	---
	--- A cast nobody is reading is dropped here rather than stored. The display
	--- would refuse to draw it anyway; the point is not to redraw and book a
	--- timer for every spell every enemy in sight starts casting.
	local function Record(cast)
		if cast.slot ~= Addon.CastHistory.PLAYER_SLOT
			and not preferences:Get(Keys.TRACK_OTHER_UNITS) then
			return
		end

		history:Record(cast)
		display:Refresh()
		events:ExpireIn(preferences:Get(Keys.HOLD_DURATION))
	end

	Addon.PlayerCasts.New():Start(Record)

	-- Registered whatever the preference says, so switching it on later starts
	-- working without a reload.
	Addon.UnitCasts.New():Start(Record)

	events:Start()

	local testMode = Addon.TestMode.New(display, healthDisplay, anchor, logger)

	-- Switching a profile reloads the interface: re-pointing every table handed
	-- out would work until one was forgotten, and that fails silently.
	local profileCommands = {
		profileNames = function()
			return profiles:Names()
		end,
		currentProfile = function()
			return profiles:CurrentName()
		end,
		selectProfile = function(name)
			profiles:Select(name)
			ReloadUI()
		end,
		createProfile = function()
			Addon.NamePrompt.Ask(L.PROFILE_NEW_QUESTION, function(name)
				profiles:Create(name)
				profiles:Select(name)
				ReloadUI()
			end)
		end,
		copyProfile = function()
			Addon.NamePrompt.Ask(L.PROFILE_COPY_QUESTION, function(name)
				profiles:CopyCurrentTo(name)
				profiles:Select(name)
				ReloadUI()
			end)
		end,
		deleteProfile = function()
			Addon.NamePrompt.Ask(L.PROFILE_DELETE_QUESTION, function(name)
				if not profiles:Delete(name) then
					logger:Warn(L.PROFILE_DELETE_ACTIVE)
				end
			end)
		end,
	}

	local panelCommands = {
		openWelcome = function()
			welcomeWindow:Open()
		end,
		toggleEditing = function()
			if InCombatLockdown() then
				logger:Warn(L.EDIT_IN_COMBAT)
				return
			end

			local isEditing = unitWindows:ToggleEditing()

			logger:Info(isEditing and L.EDIT_MODE_ON or L.EDIT_MODE_OFF)
		end,
	}

	local optionsPanel = Addon.OptionsPanel.New(
		addonInfo,
		Addon.PreferenceCatalog,
		preferences,
		{
			{ label = L.INFO_VERSION, value = addonInfo.version },
			{ label = L.INFO_AUTHOR, value = ADDON_AUTHOR },
			{ label = L.INFO_LICENSE, value = ADDON_LICENSE },
			{ label = L.INFO_COMMANDS, value = ("/anp  ·  /anp %s  ·  /anp %s"):format(
				L.COMMAND_HELP_ARGUMENT,
				L.COMMAND_TEST_ARGUMENT
			) },
			{ label = L.INFO_BINDINGS, value = L.INFO_BINDINGS_PATH },
		},
		profileCommands,
		logger,
		panelCommands
	)
	optionsPanel:Register()

	welcomeWindow = Addon.WelcomeWindow.New(preferences, firstRun, function()
		optionsPanel:Open()
	end)

	local function Toggle()
		optionsPanel:SelectValue(Keys.ENABLED, not preferences:Get(Keys.ENABLED))
	end

	minimapButton = Addon.MinimapButton.New(addonInfo, profile.minimapButton, Toggle, function()
		optionsPanel:Open()
	end)

	applyMinimapVisibility = function()
		minimapButton:SetShown(preferences:Get(Keys.SHOW_MINIMAP_BUTTON) == true)
	end

	local status = Addon.StatusCommand.New(logger, addonInfo)
	local diagnose = Addon.DiagnoseCommand.New(logger, Addon.Probe.New({
		frames = { icon = iconFrame },
		displays = { health = healthDisplay, auras = auraLayout },
		anchor = anchor,
		preferences = preferences,
		portraits = portraitLayout,
		combatPlates = combatPlates,
		windows = unitWindows,
		refreshFailures = refreshFailures,
	}))
	local help = Addon.HelpCommand.New(logger, SLASH_COMMANDS)

	commands:Register("anp", function(argument)
		local command = strtrim(argument):lower()

		if STATUS_ARGUMENTS[command] then
			status:Run()
			return
		end

		if DIAG_ARGUMENTS[command] then
			diagnose:Run()
			return
		end

		if TEST_ARGUMENTS[command] then
			testMode:Toggle()
			return
		end

		-- An anchor dragged off screen cannot be reached to be dragged back.
		if RESET_ARGUMENTS[command] then
			floatingAnchor:ResetPosition()
			return
		end

		if WELCOME_ARGUMENTS[command] then
			welcomeWindow:Open()
			return
		end

		if MOVE_ARGUMENTS[command] then
			panelCommands.toggleEditing()
			return
		end

		if HELP_ARGUMENTS[command] then
			help:Run()
			return
		end

		optionsPanel:Open()
	end)

	Addon.KeyBindings.Install(Toggle, function()
		optionsPanel:Open()
	end)

	startup = Addon.Startup.New(logger, addonInfo, preferences, hasNewLayout)
end

--- Everything that touches a frame, the minimap or the chat waits for the UI
--- to exist.
local function Start()
	minimapButton:Attach()
	applyMinimapVisibility()
	refreshAll()

	-- O perfil manda, e nao o que estiver no cliente: trocar de perfil, ou entrar
	-- com outro personagem, tem que trazer as placas junto.
	applyPlateVisibility()
	playerFrameVeil:Refresh()
	startup:Run()
	welcomeWindow:OpenOnFirstRun()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
-- Starting on PLAYER_LOGIN, not on ADDON_LOADED: addons load during the loading
-- screen, and the chat frame restores its history afterwards, dropping whatever was
-- written before it. PLAYER_LOGIN is the first moment a message actually survives.
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, loadedAddonName)
	if event ~= "ADDON_LOADED" or loadedAddonName ~= ADDON_NAME then
		if event == "PLAYER_LOGIN" then
			self:UnregisterEvent("PLAYER_LOGIN")
			Start()
		end
		return
	end

	-- SavedVariables are only readable from here on.
	self:UnregisterEvent("ADDON_LOADED")
	Build()

	-- Already logged in means PLAYER_LOGIN is long gone (/reload, or a future
	-- load-on-demand). Start now instead of waiting for an event that will
	-- never come.
	if IsLoggedIn() then
		self:UnregisterEvent("PLAYER_LOGIN")
		Start()
	end
end)
