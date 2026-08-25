local _, Addon = ...

local NAMEPLATE_TOKEN = "^nameplate%d+$"

--- Where the unit token hides, in the order worth trying. The base plate stopped
--- publishing it directly, so the frame the client builds on top of it is asked
--- next.
local TOKEN_FIELDS = { "namePlateUnitToken", "unit", "displayedUnit" }

--- The frame the client actually draws the bar into, best first. Hanging off the
--- bar rather than the plate is what makes an offset mean something: the plate
--- is a container whose size has little to do with what is on screen.
local ANCHOR_FIELDS = {
	"HealthBarsContainer",
	"healthBarsContainer",
	"healthBar",
	"HealthBar",
}

--- Finds the nameplate a unit is wearing, and the piece of it worth hanging from.
---
--- Forbidden frames are refused rather than touched: the client marks a frame
--- that way when an addon has no business writing to it, and calling anything
--- on one raises an error.
---@class NameplateRegistry
local NameplateRegistry = {}

---@param value any
---@return boolean
local function IsFrame(value)
	return type(value) == "table" and type(value.GetObjectType) == "function"
end

--- A token the client classified is no token at all here: it cannot be matched
--- against a pattern, and matching is how we know it names a nameplate.
---@param value any
---@return string?
local function AsToken(value)
	if type(value) ~= "string" or Addon.Secrets.Is(value) then
		return nil
	end

	return value:match(NAMEPLATE_TOKEN) and value or nil
end

---@param frames table[]
---@return string?
local function FindToken(frames)
	for _, frame in ipairs(frames) do
		for _, field in ipairs(TOKEN_FIELDS) do
			local token = AsToken(frame[field])

			if token then
				return token
			end
		end
	end

	return nil
end

---@param plate table
---@return table[]
local function Candidates(plate)
	local frames = { plate }

	for _, field in ipairs({ "UnitFrame", "unitFrame" }) do
		if IsFrame(plate[field]) then
			table.insert(frames, plate[field])
		end
	end

	return frames
end

---@param frames table[]
---@return table
local function FindAnchor(frames)
	-- Backwards: the unit frame comes after the plate in the list, and its bar
	-- is the closest thing to what the player actually sees.
	for index = #frames, 1, -1 do
		for _, field in ipairs(ANCHOR_FIELDS) do
			if IsFrame(frames[index][field]) then
				return frames[index][field]
			end
		end
	end

	return frames[#frames]
end

--- Onde o cliente guarda os icones de aura da placa, em ordem de tentativa. O
--- nome do campo mudou entre versoes, e nenhum deles e' garantido — daí a busca
--- por nome logo abaixo, para quando a lista errar de novo.
local AURA_FIELDS = { "AurasFrame", "BuffFrame", "buffFrame", "AuraContainer", "auraContainer" }

--- Como um campo de aura se chama, sem depender de acertar o nome exato.
local AURA_WORDS = { "aura", "buff", "debuff" }

--- O nome que funcionou, lembrado entre chamadas.
---
--- Varrer os ~35 campos de uma placa e' barato uma vez e caro a cada
--- redesenho, com uma dezena de placas na tela e dez redesenhos por segundo.
--- O cliente nao renomeia campo no meio da sessao, entao a primeira resposta
--- vale para o resto dela.
local discoveredField

--- O conteiner, quando existe e quando o cliente permite tocar nele. Os botoes
--- de aura viram proibidos sempre que as auras sao secretas, e chamar qualquer
--- coisa num frame proibido levanta erro — entao a recusa e' checada aqui, uma
--- vez, em vez de estourar la' na frente.
---@param name string
---@return boolean
local function SoundsLikeAura(name)
	local lowered = name:lower()

	for _, word in ipairs(AURA_WORDS) do
		if lowered:find(word, 1, true) then
			return true
		end
	end

	return false
end

--- Procura, pelo nome, um campo que o cliente tenha rebatizado. Só roda até
--- achar: a partir daí o nome fica lembrado.
---@param frame table
---@return string?
local function DiscoverField(frame)
	local found

	-- pcall porque percorrer um frame do cliente pode esbarrar num campo que
	-- ele recusa, e uma recusa aqui derrubaria o desenho inteiro.
	pcall(function()
		for field, value in pairs(frame) do
			if type(field) == "string" and SoundsLikeAura(field) and IsFrame(value) then
				found = field
				return
			end
		end
	end)

	return found
end

---@param frame table
---@param field string?
---@return table?
local function Usable(frame, field)
	local container = field and frame[field]

	if IsFrame(container) and not container:IsForbidden() then
		return container
	end

	return nil
end

---@param frames table[]
---@return table?
local function FindAuras(frames)
	for index = #frames, 1, -1 do
		local frame = frames[index]
		local container = Usable(frame, discoveredField)

		if container then
			return container
		end

		for _, field in ipairs(AURA_FIELDS) do
			container = Usable(frame, field)

			if container then
				discoveredField = field
				return container
			end
		end

		local field = DiscoverField(frame)
		container = Usable(frame, field)

		if container then
			discoveredField = field
			return container
		end
	end

	return nil
end

---@param value any
---@return boolean
local function IsFontString(value)
	return IsFrame(value) and value:GetObjectType() == "FontString"
end

--- O nome que o cliente desenha na placa, quando ele existe e esta' onde se
--- espera. Nao achar nao e' erro: so' significa que nao ha nada para mover.
---@param frames table[]
---@return table?
local function FindName(frames)
	for index = #frames, 1, -1 do
		if IsFontString(frames[index].name) then
			return frames[index].name
		end
	end

	return nil
end

--- Se dois tokens nomeiam a mesma unidade.
---
--- A resposta pode vir classificada quando a identidade da unidade e' secreta,
--- e aí a única leitura honesta e' "nao sei" — dizer que sim colaria o icone na
--- placa errada.
---@param unit string
---@param other string
---@return boolean
function NameplateRegistry.IsSameUnit(unit, other)
	local isSame = UnitIsUnit(unit, other)

	if Addon.Secrets.Is(isSame) then
		return false
	end

	return isSame == true
end

---@param unit string
---@return NameplateHost?
function NameplateRegistry.ForUnit(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)

	if not IsFrame(plate) or plate:IsForbidden() then
		return nil
	end

	local frames = Candidates(plate)

	-- Falling back to the token we asked with: the plate is right there and the
	-- unit is the same one either way. Only the cast history loses out, since
	-- its slots are keyed by the nameplate token.
	return {
		frame = FindAnchor(frames),
		unit = FindToken(frames) or unit,
		name = FindName(frames),
		auras = FindAuras(frames),
	}
end

Addon.NameplateRegistry = NameplateRegistry
