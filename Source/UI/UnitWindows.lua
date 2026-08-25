local _, Addon = ...

local Keys = Addon.PreferenceKeys

local WIDTH = 220
local HEALTH_HEIGHT = 18
local POWER_HEIGHT = 8
local BAR_GAP = 2
local PORTRAIT_SIZE = 34
local PORTRAIT_GAP = 5
local NAME_SIZE = 12
local TEXT_SIZE = 11
local TEXT_INSET = 4
local BACKDROP_ALPHA = 0.55
local WHITE = [[Interface\Buttons\WHITE8X8]]

--- Verde de aliado e vermelho de inimigo, para quando a classe não é legível.
local FRIEND_COLOR = { red = 0.2, green = 0.7, blue = 0.3 }
local ENEMY_COLOR = { red = 0.8, green = 0.25, blue = 0.25 }
local POWER_FALLBACK = { red = 0.3, green = 0.45, blue = 0.85 }

--- Os quatro quadros, com a unidade, o interruptor e o quadro da Blizzard que
--- cada um substitui. O alvo do alvo não tem contraparte separada: o dele mora
--- dentro do quadro de alvo, e escondê-lo levaria o do alvo junto.
local WINDOWS = {
	{
		key = "player",
		unit = "player",
		labelKey = "PREF_WINDOW_PLAYER",
		switch = Keys.WINDOW_PLAYER,
		classColorKey = Keys.WINDOW_PLAYER_CLASS_COLOR,
		colorKey = Keys.WINDOW_PLAYER_COLOR,
		blizzard = { "PlayerFrame", "PlayerFrameContainer" },
		point = { x = -280, y = -220 },
	},
	{
		key = "target",
		unit = "target",
		labelKey = "PREF_WINDOW_TARGET",
		switch = Keys.WINDOW_TARGET,
		classColorKey = Keys.WINDOW_TARGET_CLASS_COLOR,
		colorKey = Keys.WINDOW_TARGET_COLOR,
		blizzard = { "TargetFrame", "TargetFrameContainer" },
		point = { x = 280, y = -220 },
	},
	{
		key = "focus",
		unit = "focus",
		labelKey = "PREF_WINDOW_FOCUS",
		switch = Keys.WINDOW_FOCUS,
		classColorKey = Keys.WINDOW_FOCUS_CLASS_COLOR,
		colorKey = Keys.WINDOW_FOCUS_COLOR,
		blizzard = { "FocusFrame", "FocusFrameContainer" },
		point = { x = -280, y = -100 },
	},
	{
		key = "targettarget",
		unit = "targettarget",
		labelKey = "PREF_WINDOW_TOT",
		switch = Keys.WINDOW_TOT,
		classColorKey = Keys.WINDOW_TOT_CLASS_COLOR,
		colorKey = Keys.WINDOW_TOT_COLOR,
		point = { x = 470, y = -290 },
	},
}

--- Quadros de unidade próprios: jogador, alvo, foco e alvo do alvo.
---
--- As barras são nossas e os números continuam sendo do cliente: `SetValue`
--- aceita vida classificada, e ninguém aqui lê o número que desenha.
---
--- Cada quadro é um botão seguro: clicar mira a unidade, e é o cliente quem
--- decide mostrar e esconder via RegisterUnitWatch — a única forma que
--- funciona em combate, onde Show e Hide nos são proibidos.
---@class UnitWindows
---@field private positions table Posições salvas, do perfil.
---@field private preferences Preferences
---@field private appearance AppearanceSources
---@field private views table<string, table>
---@field private veiled table<string, boolean>
local UnitWindows = {}
UnitWindows.__index = UnitWindows

---@param positions table
---@param preferences Preferences
---@param appearance AppearanceSources
---@return UnitWindows
function UnitWindows.New(positions, preferences, appearance)
	local windows = setmetatable({
		positions = positions,
		preferences = preferences,
		appearance = appearance,
		views = {},
		veiled = {},
	}, UnitWindows)

	local listener = CreateFrame("Frame")

	for _, event in ipairs({
		"PLAYER_TARGET_CHANGED",
		"PLAYER_FOCUS_CHANGED",
		"UNIT_TARGET",
		"UNIT_HEALTH",
		"UNIT_MAXHEALTH",
		"UNIT_POWER_UPDATE",
		"UNIT_MAXPOWER",
		"UNIT_PORTRAIT_UPDATE",
		"UNIT_NAME_UPDATE",
		"UNIT_FACTION",
	}) do
		listener:RegisterEvent(event)
	end

	listener:SetScript("OnEvent", function(_, event)
		windows:Paint(event)
	end)

	return windows
end

--- A cor da barra de vida: classe quando legível, reação quando não.
---@param unit string
---@return { red: number, green: number, blue: number }
local function HealthColor(unit)
	local ok, _, class = pcall(UnitClass, unit)

	if ok and type(class) == "string" and not Addon.Secrets.Is(class) then
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

		if color then
			return { red = color.r, green = color.g, blue = color.b }
		end
	end

	local asked, isFriend = pcall(UnitIsFriend, "player", unit)

	if asked and not Addon.Secrets.Is(isFriend) and isFriend == true then
		return FRIEND_COLOR
	end

	return ENEMY_COLOR
end

---@param unit string
---@return { red: number, green: number, blue: number }
local function PowerColor(unit)
	local ok, _, token = pcall(UnitPowerType, unit)

	if ok and type(token) == "string" and not Addon.Secrets.Is(token) then
		local color = PowerBarColor and PowerBarColor[token]

		if color then
			return { red = color.r, green = color.g, blue = color.b }
		end
	end

	return POWER_FALLBACK
end

---@param bar table
---@param unit string
---@param current fun(unit: string): unknown
---@param maximum fun(unit: string): unknown
local function FillBar(bar, unit, current, maximum)
	-- Os dois valores podem ser classificados; SetMinMaxValues e SetValue os
	-- aceitam, e a barra enche sem ninguém aqui saber quanto.
	pcall(function()
		bar:SetMinMaxValues(0, maximum(unit))
		bar:SetValue(current(unit))
	end)
end

---@param window table A definição, de WINDOWS.
---@param positions table
---@param isEditing fun(): boolean
---@return table view
local function Build(window, positions, isEditing)
	local button = CreateFrame(
		"Button",
		"AuraNameplateWindow" .. window.key,
		UIParent,
		"SecureUnitButtonTemplate"
	)

	button:SetSize(WIDTH, HEALTH_HEIGHT + BAR_GAP + POWER_HEIGHT)
	button:SetAttribute("unit", window.unit)
	button:SetAttribute("*type1", "target")
	button:SetAttribute("*type2", "togglemenu")
	button:RegisterForClicks("AnyUp")

	local saved = positions[window.key]

	button:SetPoint(
		saved and saved.point or "CENTER",
		UIParent,
		saved and saved.point or "CENTER",
		saved and saved.x or window.point.x,
		saved and saved.y or window.point.y
	)

	-- Arrastar move, soltar grava — mas só no modo de edição: fora dele o
	-- clique é para mirar, e um arrasto acidental levaria o quadro junto.
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function(owner)
		if isEditing() and not InCombatLockdown() then
			owner:StartMoving()
		end
	end)
	button:SetScript("OnDragStop", function(owner)
		owner:StopMovingOrSizing()

		local ok, point, _, _, x, y = pcall(owner.GetPoint, owner, 1)

		if ok and point then
			positions[window.key] = { point = point, x = x, y = y }
		end
	end)

	local backdrop = button:CreateTexture(nil, "BACKGROUND")
	backdrop:SetColorTexture(0, 0, 0, BACKDROP_ALPHA)
	backdrop:SetPoint("TOPLEFT", -2, 2)
	backdrop:SetPoint("BOTTOMRIGHT", 2, -2)

	local health = CreateFrame("StatusBar", nil, button)
	health:SetPoint("TOPLEFT")
	health:SetPoint("TOPRIGHT")
	health:SetHeight(HEALTH_HEIGHT)
	health:SetStatusBarTexture(WHITE)

	local power = CreateFrame("StatusBar", nil, button)
	power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -BAR_GAP)
	power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -BAR_GAP)
	power:SetHeight(POWER_HEIGHT)
	power:SetStatusBarTexture(WHITE)

	local portrait = button:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait:SetPoint("RIGHT", button, "LEFT", -PORTRAIT_GAP, 0)

	local text = health:CreateFontString(nil, "OVERLAY")
	text:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET, 0)
	text:SetJustifyH("RIGHT")

	-- Preso dos dois lados e sem quebra: um nome comprido termina em
	-- reticências antes de encostar na vida, em vez de atropelá-la.
	local name = health:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", health, "LEFT", TEXT_INSET, 0)
	name:SetPoint("RIGHT", text, "LEFT", -TEXT_INSET, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)

	-- Mostrar e esconder passam a ser do cliente, que pode fazê-lo em combate.
	if RegisterUnitWatch then
		RegisterUnitWatch(button)
	end

	return {
		button = button,
		health = health,
		power = power,
		portrait = portrait,
		name = name,
		text = text,
		unit = window.unit,
		window = window,
		isWatched = true,
	}
end

--- O primeiro nome que este cliente conhece, lembrado — nomes de frame mudam
--- entre versões tanto quanto os de CVar.
---@private
---@param names string[]
---@return string?, table?
function UnitWindows:BlizzardFrame(names)
	for _, name in ipairs(names) do
		if type(_G[name]) == "table" then
			return name, _G[name]
		end
	end

	return nil, nil
end

--- Some com o quadro da Blizzard que o nosso substitui — por alfa, nunca por
--- Hide, pelo mesmo motivo do quadro do jogador: são frames protegidos.
---
--- O alfa é reafirmado mesmo quando o estado não mudou: o cliente anima o alfa
--- dos próprios quadros — montaria, veículo — e uma escrita única perderia essa
--- corrida em silêncio.
---@private
---@param names string[]
---@param isVeiled boolean
function UnitWindows:Veil(names, isVeiled)
	local globalName, frame = self:BlizzardFrame(names)

	if not frame then
		return
	end

	if isVeiled then
		pcall(frame.SetAlpha, frame, 0)
	end

	if self.veiled[globalName] == isVeiled then
		return
	end

	self.veiled[globalName] = isVeiled
	self.hooked = self.hooked or {}

	if isVeiled and not self.hooked[globalName] then
		self.hooked[globalName] = true

		pcall(frame.HookScript, frame, "OnShow", function()
			if self.veiled[globalName] then
				pcall(frame.SetAlpha, frame, 0)
			end
		end)
	end

	if not isVeiled then
		pcall(frame.SetAlpha, frame, 1)
	end

	if not InCombatLockdown() then
		pcall(frame.EnableMouse, frame, not isVeiled)
	end
end

--- O estado de cada véu, para o autoteste: ausente, visível ou sob véu, com o
--- alfa que o quadro tem agora — é o alfa que denuncia quem o reescreveu.
---@return string[]
function UnitWindows:InspectVeils()
	local parts = {}

	for _, window in ipairs(WINDOWS) do
		if window.blizzard then
			local globalName, frame = self:BlizzardFrame(window.blizzard)

			if not frame then
				table.insert(parts, ("%s=missing"):format(window.blizzard[1]))
			else
				local ok, alpha = pcall(frame.GetAlpha, frame)

				table.insert(parts, ("%s=%s(alpha=%s)"):format(
					globalName,
					self.veiled[globalName] and "veiled" or "shown",
					ok and tostring(alpha) or "?"
				))
			end
		end
	end

	return parts
end

--- Os dados de um quadro: cores, valores e textos, na fonte do jogador.
---@private
---@param view table
---@param shouldPaintPortrait boolean
function UnitWindows:PaintView(view, shouldPaintPortrait)
	local preferences = self.preferences
	local powerColor = PowerColor(view.unit)

	-- A cor de classe conta quem é a unidade; a fixa deixa o quadro do jeito do
	-- jogador. Por quadro, porque "alvo vermelho, eu verde" é um arranjo comum
	-- que um par global de chaves não consegue dizer.
	local healthColor = preferences:Get(view.window.classColorKey)
			and HealthColor(view.unit)
		or Addon.IconLayout.Color(preferences:Get(view.window.colorKey))

	view.health:SetStatusBarColor(healthColor.red, healthColor.green, healthColor.blue)
	view.power:SetStatusBarColor(powerColor.red, powerColor.green, powerColor.blue)

	FillBar(view.health, view.unit, UnitHealth, UnitHealthMax)
	FillBar(view.power, view.unit, UnitPower, UnitPowerMax)

	local path = self.appearance.Font(preferences:Get(Keys.FONT_NAME))
	local flags = Addon.FontFlags.Resolve(preferences:Get(Keys.FONT_FLAG))

	view.name:SetFont(path, NAME_SIZE, flags)
	view.text:SetFont(path, TEXT_SIZE, flags)

	-- O nome pode vir classificado; SetText o aceita como aceita a vida.
	pcall(function()
		view.name:SetText(UnitName(view.unit))
	end)

	local reading = Addon.UnitHealthReading.Text(
		view.unit,
		preferences:Get(Keys.HEALTH_TEXT_FORMAT)
	)

	pcall(function()
		if reading.secondary then
			view.text:SetText(("%s  %s"):format(reading.primary, reading.secondary))
		else
			view.text:SetText(reading.primary)
		end
	end)

	view.portrait:SetShown(preferences:Get(Keys.WINDOW_PORTRAIT) == true)

	if shouldPaintPortrait then
		pcall(SetPortraitTexture, view.portrait, view.unit)
	end
end

--- Eventos de dado repintam; eventos de identidade repintam o retrato junto.
local PORTRAIT_EVENTS = {
	PLAYER_TARGET_CHANGED = true,
	PLAYER_FOCUS_CHANGED = true,
	UNIT_TARGET = true,
	UNIT_PORTRAIT_UPDATE = true,
}

---@private
---@param event string?
function UnitWindows:Paint(event)
	local shouldPaintPortrait = event == nil or PORTRAIT_EVENTS[event] == true

	-- O véu junto dos dados: os eventos de unidade são o relógio mais frequente
	-- que temos, e é barato — um SetAlpha por quadro escondido.
	for _, window in ipairs(WINDOWS) do
		if window.blizzard then
			local globalName, frame = self:BlizzardFrame(window.blizzard)

			if frame and self.veiled[globalName] then
				pcall(frame.SetAlpha, frame, 0)
			end
		end
	end

	for _, view in pairs(self.views) do
		if view.button:IsShown() then
			-- Protegida por quadro: um quadro com dado que o cliente recusa nao
			-- pode calar os outros tres nem os eventos seguintes.
			local ok, failure = pcall(self.PaintView, self, view, shouldPaintPortrait)

			self.paintFailure = not ok and tostring(failure) or nil
		end
	end
end

--- O que impediu a ultima pintura, se algo impediu.
---@return string?
function UnitWindows:LastPaintFailure()
	return self.paintFailure
end

--- Liga e desliga quadros conforme as preferências, e pinta os ligados.
function UnitWindows:Refresh()
	local hideBlizzard = self.preferences:Get(Keys.WINDOW_HIDE_BLIZZARD) == true

	for _, window in ipairs(WINDOWS) do
		local isWanted = self.preferences:Get(window.switch) == true
		local view = self.views[window.key]

		if isWanted and not view then
			view = Build(window, self.positions, function()
				return self.isEditing == true
			end)
			self.views[window.key] = view
		end

		-- O relógio de unidades arma uma vez e só desarma quando o estado
		-- muda, sempre fora de combate: re-armar a cada passada toca atributo
		-- seguro, e o pcall não impede o bloqueio, só engole o aviso. Enquanto
		-- a edição durar, ela manda.
		if view and not self.isEditing and not InCombatLockdown() then
			if not isWanted and view.isWatched then
				if UnregisterUnitWatch then
					pcall(UnregisterUnitWatch, view.button)
				end

				view.isWatched = false
				view.button:Hide()
			elseif isWanted and not view.isWatched and RegisterUnitWatch then
				pcall(RegisterUnitWatch, view.button)
				view.isWatched = true
			end
		end

		if window.blizzard then
			self:Veil(window.blizzard, isWanted and hideBlizzard)
		end
	end

	self:Paint(nil)
end

--- A capa que marca um quadro em edição: preenchimento e o nome do quadro.
---@private
---@param view table
---@return table
function UnitWindows:Overlay(view)
	if view.overlay then
		return view.overlay
	end

	local overlay = CreateFrame("Frame", nil, view.button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(view.button:GetFrameLevel() + 5)

	local fill = overlay:CreateTexture(nil, "OVERLAY")
	fill:SetAllPoints()
	fill:SetColorTexture(0.95, 0.72, 0.25, 0.3)

	local label = overlay:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(Addon.OptionsFonts.STRONG)
	label:SetPoint("CENTER")
	label:SetText(Addon.L[view.window.labelKey])
	label:SetTextColor(1, 1, 1)

	view.overlay = overlay

	return overlay
end

--- Liga e desliga o posicionamento.
---
--- Em edição todo quadro ligado aparece, exista a unidade ou não — posicionar
--- a janela de foco não pode exigir arranjar um foco primeiro. O relógio de
--- unidades é desligado enquanto durar e religado na saída, e por isso a
--- edição não começa em combate: religar é operação protegida.
---@param isEditing boolean
---@return boolean isNowEditing
function UnitWindows:SetEditing(isEditing)
	-- Nem entrar nem sair em combate: os dois lados mexem no relógio de
	-- unidades, e ele é atributo seguro.
	if InCombatLockdown() then
		return self.isEditing == true
	end

	self.isEditing = isEditing == true

	self:Refresh()

	for _, view in pairs(self.views) do
		local isWanted = self.preferences:Get(view.window.switch) == true

		if self.isEditing and isWanted then
			if view.isWatched and UnregisterUnitWatch then
				pcall(UnregisterUnitWatch, view.button)
				view.isWatched = false
			end

			view.button:Show()
			self:Overlay(view):Show()
		else
			if view.overlay then
				view.overlay:Hide()
			end

			if isWanted and not view.isWatched and RegisterUnitWatch then
				pcall(RegisterUnitWatch, view.button)
				view.isWatched = true
			end
		end
	end

	return self.isEditing
end

---@return boolean isNowEditing
function UnitWindows:ToggleEditing()
	return self:SetEditing(not self.isEditing)
end

Addon.UnitWindows = UnitWindows
