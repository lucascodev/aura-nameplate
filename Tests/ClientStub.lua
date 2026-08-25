--- Um cliente de World of Warcraft falso, o bastante para montar o addon.
---
--- Não simula comportamento: responde a qualquer chamada e guarda os handlers
--- de evento, para que o teste consiga disparar ADDON_LOADED e PLAYER_LOGIN e
--- ver se a montagem sobrevive. É o único jeito de exercitar o composition root
--- fora do jogo, e a classe de erro que ele pega — uma ordem de linhas errada
--- que só aparece em tempo de execução — não aparece em nenhum outro teste.

local ClientStub = {}

--- Chave numérica devolve nil, e não outro stub. Sem isto um `ipairs` sobre
--- qualquer resposta nunca terminaria.
---@param name string
---@return table
local function Anything(name)
	local stub = {}

	setmetatable(stub, {
		__index = function(_, key)
			if type(key) == "number" then
				return nil
			end

			return Anything(name .. "." .. tostring(key))
		end,
		__call = function()
			return Anything(name .. "()")
		end,
		__tostring = function()
			return name
		end,
	})

	return stub
end

ClientStub.Anything = Anything

--- Os métodos que precisam responder com um valor de verdade, porque quem
--- chama faz conta ou compara com o resultado.
local MEASURED = {
	GetFrameLevel = 0,
	GetLeft = 0,
	GetTop = 0,
	GetWidth = 10,
	GetHeight = 10,
	GetStringWidth = 10,
	GetStringHeight = 10,
	GetID = 1,
	IsShown = false,
	IsForbidden = false,
	IsObjectType = false,
	GetObjectType = "Frame",
	SetFont = true,
}

---@param frames table[] Coletor de todo frame criado, para o teste alcançar os handlers.
---@return table
local function NewFrame(frames)
	local frame = { scripts = {}, events = {} }

	function frame:SetScript(name, handler)
		self.scripts[name] = handler
	end

	function frame:RegisterEvent(event)
		self.events[event] = true
	end

	function frame:RegisterUnitEvent(event)
		self.events[event] = true
	end

	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end

	function frame:CreateFontString()
		return NewFrame(frames)
	end

	function frame:CreateTexture()
		return NewFrame(frames)
	end

	--- Precisa devolver nil de verdade: quem chama compara com o pai desejado
	--- para decidir se reparenta.
	function frame:GetParent()
		return nil
	end

	--- Outro frame, e não um stub qualquer: quem pega o texto de um botão faz
	--- conta com a largura dele logo em seguida.
	function frame:GetFontString()
		return NewFrame(frames)
	end

	setmetatable(frame, {
		__index = function(_, key)
			if MEASURED[key] ~= nil then
				local value = MEASURED[key]

				return function()
					return value
				end
			end

			if type(key) == "number" then
				return nil
			end

			-- Chamável e indexável ao mesmo tempo: o cliente expõe campos que
			-- são frames dentro de frames, e `botao.Text:SetText()` precisa dos
			-- dois comportamentos no mesmo objeto.
			return Anything(key)
		end,
	})

	table.insert(frames, frame)

	return frame
end

--- Instala os globais e devolve o que o teste precisa para dirigir a carga.
---@return { frames: table[] }
function ClientStub.Install()
	local frames = {}

	local globals = {
		GetLocale = function()
			return "enUS"
		end,
		CreateFrame = function()
			return NewFrame(frames)
		end,
		CreateFont = function()
			return NewFrame(frames)
		end,
		GetTime = function()
			return 0
		end,
		UnitName = function()
			return "Tester"
		end,
		GetRealmName = function()
			return "Azralon"
		end,
		UnitExists = function()
			return false
		end,
		UnitIsUnit = function()
			return false
		end,
		InCombatLockdown = function()
			return false
		end,
		IsLoggedIn = function()
			return false
		end,
		UnitClass = function()
			return "Mage", "MAGE"
		end,
		RAID_CLASS_COLORS = { MAGE = { r = 0.4, g = 0.8, b = 0.9 } },
		STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF",
		issecretvalue = function()
			return false
		end,
		AbbreviateNumbers = function()
			return "1K"
		end,
		UnitHealth = function()
			return 100
		end,
		strtrim = function(text)
			return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
		end,
		LibStub = function()
			local library = Anything("Lib")

			function library:Register() end
			function library:List()
				return {}
			end
			function library:Fetch()
				return "Fonts\\FRIZQT__.TTF"
			end
			function library:GetDefault()
				return "Default"
			end
			function library:NewDataObject()
				return {}
			end
			function library:Show() end
			function library:Hide() end

			return library
		end,
		--- Sem o template, o addon deixa a fileira nativa em paz — que é o
		--- caminho que o teste de montagem deve exercitar fora do jogo.
		C_XMLUtil = {
			GetTemplateInfo = function()
				return nil
			end,
		},
		SlashCmdList = {},
		StaticPopupDialogs = {},
	}

	setmetatable(_G, {
		__index = function(_, key)
			if globals[key] ~= nil then
				return globals[key]
			end

			return Anything(key)
		end,
	})

	for name, value in pairs(globals) do
		if type(value) == "table" then
			rawset(_G, name, value)
		end
	end

	return { frames = frames }
end

return ClientStub
