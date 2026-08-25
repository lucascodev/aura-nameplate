local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Above whatever the client draws into the bar itself.
local FRAME_LEVEL_LIFT = 10

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
---@field private containers table<table, table> Por frame de placa, que o cliente recicla.
---@field private hidden table<table, boolean> Fileiras nativas já silenciadas.
---@field private failure string? O que estourou no último desenho.
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
---@return table?, boolean?
function OwnAuras:Container(host, signature)
	local existing = self.containers[host.frame]

	if existing and existing.signature == signature then
		return existing.container
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

	self.containers[host.frame] = { container = container, signature = signature }

	return container, true
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
---@param container table
---@param settings table
function OwnAuras:AddGroups(container, settings)
	local preferences = self.preferences
	local appearance = self.appearance

	-- O tamanho é lido na hora de montar o botão, e não capturado aqui: o
	-- cliente cria botões novos conforme precisa, e um botão criado depois de o
	-- jogador mexer no controle deve nascer no tamanho de agora.
	local function Build(button)
		Addon.AuraIcon.Build(button, preferences:Get(Keys.AURA_ICON_SIZE), {
			path = appearance.Font(preferences:Get(Keys.FONT_NAME)),
			flags = Addon.FontFlags.Resolve(preferences:Get(Keys.FONT_FLAG)),
		})
	end

	for _, filter in ipairs(settings.filters) do
		container:AddAuraGroup(filter, filter, {
			maxFrameCount = settings.maxCount,
			sortMethod = AuraContainerSortMethod.Expiration,
			sortDirection = AuraContainerSortDirection.Normal,
			initializeFrame = Build,
			layout = LayoutOf(settings),
		})
	end
end

--- Tudo aqui pode ser repetido a cada redesenho sem reclamar, e é o que deixa
--- tamanho, espaçamento e lado responderem na hora.
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

---@private
---@param host NameplateHost
function OwnAuras:Draw(host)
	local settings = self:Settings()
	local container, isNew = self:Container(host, Signature(settings.filters))

	if not container then
		return
	end

	local preferences = self.preferences
	local anchor = Addon.AnchorPoints.ResolveTrailing(preferences:Get(Keys.AURA_ANCHOR_POINT))

	if isNew then
		self:AddGroups(container, settings)
	end

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
