local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Above whatever the client draws into the bar itself.
local FRAME_LEVEL_LIFT = 10

--- Quanto esperar depois da última mudança que os botões recusaram antes de
--- recriar a fileira. Um arrastar de slider dispara dezenas de mudanças, e
--- cada recriação deixa para trás um contêiner que o cliente não libera.
local REBUILD_DELAY = 0.4

--- O que o addon guarda de cada contêiner que criou.
---@class AuraContainerEntry
---@field container table
---@field signature string Os filtros com que os grupos foram montados.
---@field buttons table<table, boolean> Os botões que o cliente já pediu para montar.
---@field look { size: number, path: string, flags: string }? O último tamanho aplicado aos botões.
---@field isStale boolean? Marcada para recriação: os botões recusaram o tamanho novo.

--- A nossa própria fileira de auras, no lugar da que o cliente desenha.
---
--- Mover a fileira nativa não se sustentou: o cliente remonta o layout na
--- própria passada e reancora por cima, e nenhum gancho ganhou essa corrida de
--- forma confiável. Desenhar a nossa encerra a disputa — a fileira passa a ser
--- nossa, e o cliente não tem opinião sobre onde ela fica.
---
--- Os dados de aura são classificados, então nenhum addon consegue ler o ícone
--- de uma aura para desenhá-lo. `CustomAuraContainerTemplate` existe exatamente
--- para essa fronteira: nós escolhemos filtro, tamanho, espaçamento, ordem,
--- posição e as regiões de cada botão; o cliente as preenche.
---@class OwnAuras
---@field private hosts HostSource
---@field private preferences Preferences
---@field private appearance AppearanceSources
---@field private containers table<table, AuraContainerEntry> Por frame de placa, que o cliente recicla.
---@field private hidden table<table, boolean> Fileiras nativas já silenciadas.
---@field private failure string? O que estourou no último desenho.
---@field private rebuildTimer table? A recriação agendada, se houver.
---@field private pendingLook string? O que a recriação agendada vai aplicar.
local OwnAuras = {}
OwnAuras.__index = OwnAuras

---@param hosts HostSource
---@param preferences Preferences
---@param appearance AppearanceSources
---@return OwnAuras
function OwnAuras.New(hosts, preferences, appearance)
	return setmetatable({
		hosts = hosts,
		preferences = preferences,
		appearance = appearance,
		containers = setmetatable({}, { __mode = "k" }),
		hidden = setmetatable({}, { __mode = "k" }),
	}, OwnAuras)
end

--- O template é recente. Num cliente que não o traga, o addon não desenha
--- fileira nenhuma e deixa a nativa em paz, que é melhor que meia solução.
---@return boolean
function OwnAuras.IsSupported()
	return C_XMLUtil ~= nil
		and C_XMLUtil.GetTemplateInfo ~= nil
		and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") ~= nil
end

---@param container table
local function Clear(container)
	pcall(container.SetEnabled, container, false)
	pcall(container.Hide, container)
end

--- A fileira nativa some por alfa, e não por Hide: o cliente a mostra de novo
--- nas próprias atualizações, e brigar por visibilidade seria a mesma corrida
--- que já foi perdida por posição. Alfa zero sobrevive a um Show.
---@private
---@param native table
function OwnAuras:Silence(native)
	if self.hidden[native] then
		return
	end

	self.hidden[native] = true

	pcall(native.SetAlpha, native, 0)
	pcall(native.HookScript, native, "OnShow", function()
		pcall(native.SetAlpha, native, 0)
	end)
end

--- Cresce para longe da borda em que está presa: presa à direita, a fileira se
--- estende para a esquerda, e uma aura nova não empurra as que já estão.
---@param point string
---@return string
local function GrowthFrom(point)
	return point:find("RIGHT", 1, true) and "Left" or "Right"
end

---@param filters string[]
---@return string
local function Signature(filters)
	return table.concat(filters, "+")
end

--- O contêiner de uma placa, criado e montado uma vez só.
---
--- `AddAuraGroup` aceita cada chave uma única vez: repeti-la levanta
--- "aura group already exists". Como os grupos carregam os filtros, trocar de
--- filtro exige um contêiner novo — o antigo é desligado e escondido, porque o
--- cliente não oferece jeito de destruir um frame. São poucos: um por troca de
--- filtro, e trocar de filtro é ação de menu, não de combate.
---@private
---@param host NameplateHost
---@param signature string
---@return AuraContainerEntry?, boolean?
function OwnAuras:Container(host, signature)
	local existing = self.containers[host.frame]

	if existing and existing.signature == signature and not existing.isStale then
		return existing
	end

	if existing then
		Clear(existing.container)
	end

	local ok, container = pcall(
		CreateFrame,
		"AuraContainer",
		nil,
		host.frame,
		"CustomAuraContainerTemplate"
	)

	if not ok or not container then
		return nil
	end

	local entry = { container = container, signature = signature, buttons = {} }

	self.containers[host.frame] = entry

	return entry, true
end

---@private
---@return { iconSize: number, spacing: number, maxCount: number, filters: string[] }
function OwnAuras:Settings()
	local preferences = self.preferences

	return {
		iconSize = preferences:Get(Keys.AURA_ICON_SIZE),
		spacing = preferences:Get(Keys.AURA_ICON_SPACING),
		maxCount = preferences:Get(Keys.AURA_MAX_COUNT),
		filters = Addon.AuraFilters.Resolve(preferences:Get(Keys.AURA_FILTER)),
	}
end

---@private
---@return { path: string, flags: string }
function OwnAuras:Font()
	local preferences = self.preferences

	return {
		path = self.appearance.Font(preferences:Get(Keys.FONT_NAME)),
		flags = Addon.FontFlags.Resolve(preferences:Get(Keys.FONT_FLAG)),
	}
end

---@param settings table
---@return table
local function LayoutOf(settings)
	local element = settings.iconSize + settings.spacing

	return {
		elementSpacing = settings.spacing,
		lineSpacing = settings.spacing,
		groupSpacing = settings.spacing,
		groupLineSpacing = settings.spacing,
		elementWidth = settings.iconSize,
		elementHeight = settings.iconSize,
		maximumLineSize = settings.maxCount * element,
	}
end

--- Os grupos entram uma vez, na criação. Chamar de novo levanta erro, e o erro
--- caía antes do SetUnit — o contêiner ficava preso à unidade da primeira placa
--- e nunca mais era atualizado.
---
--- `initializeFrame` é o que faltava para a fileira aparecer: sem ele o cliente
--- cria os botões e não encontra nenhuma região para preencher, então nasce uma
--- fileira de nadas. O filtro serve de chave porque é único dentro do contêiner
--- por construção — dois grupos nunca pedem o mesmo.
---@private
---@param entry AuraContainerEntry
---@param settings table
function OwnAuras:AddGroups(entry, settings)
	local preferences = self.preferences
	local auras = self

	-- O tamanho é lido na hora de montar o botão, e não capturado aqui: o
	-- cliente cria botões novos conforme precisa, e um botão criado depois de o
	-- jogador mexer no controle deve nascer no tamanho de agora. O botão fica
	-- anotado porque o cliente o reaproveita: os que já existem só mudam de
	-- tamanho por Resize.
	local function Build(button)
		entry.buttons[button] = true
		Addon.AuraIcon.Build(button, preferences:Get(Keys.AURA_ICON_SIZE), auras:Font())
	end

	for _, filter in ipairs(settings.filters) do
		entry.container:AddAuraGroup(filter, filter, {
			maxFrameCount = settings.maxCount,
			sortMethod = AuraContainerSortMethod.Expiration,
			sortDirection = AuraContainerSortDirection.Normal,
			initializeFrame = Build,
			layout = LayoutOf(settings),
		})
	end
end

--- Tudo aqui pode ser repetido a cada redesenho sem reclamar, e é o que deixa
--- espaçamento, quantidade e lado responderem na hora. O layout só posiciona:
--- o tamanho de cada botão é de quem o montou, e muda em Resize.
---@param container table
---@param settings table
---@param anchor table
local function Configure(container, settings, anchor)
	local layout = LayoutOf(settings)

	for _, filter in ipairs(settings.filters) do
		container:SetAuraGroupLayout(filter, layout)
	end

	container:SetFlowLayoutAnchorPoint(anchor.point)
	container:SetFlowLayoutGrowthDirection(
		AnchorUtil.FlowDirection[GrowthFrom(anchor.point)],
		AnchorUtil.FlowDirection.Up
	)
	container:SetFlowLayoutMaximumLineSize(layout.maximumLineSize)
end

--- Os botões nascem no tamanho da hora, mas o cliente os guarda num pool e os
--- reaproveita: mexer no controle depois não recria nenhum, e o layout do
--- grupo não os redimensiona. Então o tamanho novo é aplicado aos que já
--- existem — uma vez por mudança, porque SetFont a cada redesenho seria caro
--- à toa.
---
--- Um botão que mostra aura secreta é proibido pelo cliente (12.1): qualquer
--- chamada nele estoura, e em combate é o caso de quase todos. Esses ficam
--- para depois, e o tamanho só é dado como aplicado quando nenhum sobrou —
--- assim o próximo redesenho, já fora de combate, termina o serviço.
---@private
---@param entry AuraContainerEntry
---@param settings table
function OwnAuras:Resize(entry, settings)
	local font = self:Font()
	local look = entry.look

	if look
		and look.size == settings.iconSize
		and look.path == font.path
		and look.flags == font.flags then
		return
	end

	local isComplete = true

	for button in pairs(entry.buttons) do
		if button:IsForbidden() then
			isComplete = false
		else
			Addon.AuraIcon.Resize(button, settings.iconSize, font)
		end
	end

	entry.look = isComplete
		and { size = settings.iconSize, path = font.path, flags = font.flags }
		or nil

	if not isComplete then
		self:ScheduleRebuild(("%s|%s|%s"):format(settings.iconSize, font.path, font.flags))
	end
end

--- Botão proibido não muda de tamanho, mas um botão novo nasce no tamanho de
--- agora: recriar a fileira é o único jeito de o tamanho valer em combate. O
--- atraso junta as mudanças de um arrastar numa recriação só, e quem já
--- aceitou o tamanho no meio-tempo — o combate acabou — fica como está.
---
--- Só uma mudança no que se pede adia o prazo. Todo redesenho passa por aqui
--- enquanto os botões estão proibidos, e em combate eles vêm em rajada: se
--- cada um reiniciasse a contagem, a recriação nunca chegaria.
---@private
---@param wanted string O tamanho e a fonte pedidos, como chave.
function OwnAuras:ScheduleRebuild(wanted)
	if self.rebuildTimer and self.pendingLook == wanted then
		return
	end

	if self.rebuildTimer then
		self.rebuildTimer:Cancel()
	end

	self.pendingLook = wanted
	self.rebuildTimer = C_Timer.NewTimer(REBUILD_DELAY, function()
		self.rebuildTimer = nil
		self.pendingLook = nil

		-- Só as placas na tela: a de uma placa guardada no pool espera ela
		-- voltar, e então o caminho normal decide se recria.
		for _, host in ipairs(self.hosts:Nameplates()) do
			local entry = self.containers[host.frame]

			if entry and not entry.look then
				entry.isStale = true
			end
		end

		self:Refresh()
	end)
end

---@private
---@param host NameplateHost
function OwnAuras:Draw(host)
	local settings = self:Settings()
	local entry, isNew = self:Container(host, Signature(settings.filters))

	if not entry then
		return
	end

	local container = entry.container
	local preferences = self.preferences
	local anchor = Addon.AnchorPoints.ResolveTrailing(preferences:Get(Keys.AURA_ANCHOR_POINT))

	if isNew then
		self:AddGroups(entry, settings)
	end

	-- Antes de posicionar: o tamanho dos botões não depende de o resto dar
	-- certo, e um erro lá embaixo não pode deixá-lo para trás.
	self:Resize(entry, settings)

	container:SetFrameLevel(host.frame:GetFrameLevel() + FRAME_LEVEL_LIFT)
	container:SetSize(1, 1)
	container:ClearAllPoints()
	container:SetPoint(
		anchor.point,
		host.frame,
		anchor.relativePoint,
		preferences:Get(Keys.AURA_OFFSET_X),
		preferences:Get(Keys.AURA_OFFSET_Y)
	)

	Configure(container, settings, anchor)

	container:SetEnabled(true)
	container:SetUnit(host.unit)
	container:Show()
end

function OwnAuras:Refresh()
	if not self.preferences:Get(Keys.OWN_AURAS) or not OwnAuras.IsSupported() then
		for _, entry in pairs(self.containers) do
			Clear(entry.container)
		end

		return
	end

	for _, host in ipairs(self.hosts:Nameplates()) do
		if host.auras then
			self:Silence(host.auras)
		end

		-- O cliente pode recusar o frame entre um refresh e o outro, e um erro
		-- aqui derrubaria o desenho da vida junto. Mas engolir sem guardar deixa
		-- "não desenhou" e "estourou" com a mesma cara na tela, então o motivo
		-- fica gravado para o autoteste contar.
		local ok, failure = pcall(self.Draw, self, host)

		self.failure = not ok and tostring(failure) or nil
	end
end

--- O que impediu o último desenho, se algo impediu.
---@return string?
function OwnAuras:LastFailure()
	return self.failure
end

Addon.OwnAuras = OwnAuras
