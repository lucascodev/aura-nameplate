local _, Addon = ...

--- As chaves de nameplate do cliente, lidas e escritas.
---
--- Parte delas o jogo tranca em combate, e escrever ali não devolve erro — dá
--- silêncio, e a opção parece não funcionar. O que não pôde ser escrito espera
--- o fim da luta em vez de se perder.
---@class PlateCVars
local PlateCVars = {}

---@type table<string, boolean>
local pending = {}
---@type table?
local waiter
--- Nome resolvido por lista de candidatos; `false` marca "nenhum serve".
---@type table<table, string|false>
local resolved = setmetatable({}, { __mode = "k" })

---@type string?
local failure

---@param cvar string
---@param isOn boolean
---@return boolean hasLanded
local function Put(cvar, isOn)
	-- Comparar antes de escrever: o cliente reage a toda escrita, e reescrever o
	-- que já está lá remontaria as placas da tela sem motivo.
	local ok, current = pcall(C_CVar.GetCVarBool, cvar)

	if ok and current == isOn then
		return true
	end

	-- Recusa tem duas caras: o erro, e o false educado. As duas ficam
	-- registradas — recusa engolida é interruptor parecendo quebrado.
	local wrote, accepted = pcall(C_CVar.SetCVar, cvar, isOn and "1" or "0")

	if not wrote then
		failure = ("%s: %s"):format(cvar, tostring(accepted))
		return false
	end

	if accepted == false then
		failure = ("%s: refused"):format(cvar)
		return false
	end

	return true
end

--- A última escrita que o cliente recusou, para o autoteste.
---@return string?
function PlateCVars.LastFailure()
	return failure
end

local function Flush()
	for cvar, isOn in pairs(pending) do
		Put(cvar, isOn)
		pending[cvar] = nil
	end
end

--- Um ouvinte só, criado quando a primeira escrita esbarra no combate e
--- desligado assim que a fila sai. Registrado o tempo todo, ele acordaria a cada
--- luta encerrada para não fazer nada.
local function WaitForPeace()
	waiter = waiter or CreateFrame("Frame")

	waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
	waiter:SetScript("OnEvent", function(frame)
		frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		Flush()
	end)
end

--- Um cliente que não conheça a chave devolve nil, e nil não é "desligado".
---@param cvar string
---@return boolean?
local function Ask(cvar)
	local ok, value = pcall(C_CVar.GetCVarBool, cvar)

	if not ok or value == nil then
		return nil
	end

	return value == true
end

--- O primeiro nome que este cliente conhece, entre os que a ligação oferece.
---
--- Resolvido uma vez e guardado, inclusive a ausência: sem isso toda escrita
--- pagaria a busca de novo, e a resposta não muda durante a sessão.
---@param cvars string[]
---@return string?
function PlateCVars.NameOf(cvars)
	local answer = resolved[cvars]

	if answer ~= nil then
		return answer or nil
	end

	for _, cvar in ipairs(cvars) do
		if Ask(cvar) ~= nil then
			resolved[cvars] = cvar

			return cvar
		end
	end

	resolved[cvars] = false

	return nil
end

---@param cvars string[]
---@return boolean?
function PlateCVars.Read(cvars)
	local cvar = PlateCVars.NameOf(cvars)

	-- Sem atalho com `and/or`: uma chave que existe e esta' desligada responde
	-- false, e false viraria nil, que significa "o cliente nao tem esta chave".
	-- A semeadura tomaria o padrao do catalogo e ligaria o que estava desligado.
	if not cvar then
		return nil
	end

	return Ask(cvar)
end

--- Escreve tentando primeiro: a maioria das chaves de placa aceita mudanca em
--- pleno combate, e adivinhar que vai falhar adiaria o que podia acontecer
--- agora. So' o que o cliente recusou de fato espera o fim da luta.
---@param cvars string[]
---@param isOn boolean
function PlateCVars.Write(cvars, isOn)
	local cvar = PlateCVars.NameOf(cvars)

	if not cvar then
		return
	end

	if not Put(cvar, isOn) and InCombatLockdown() then
		pending[cvar] = isOn
		WaitForPeace()
	end
end

Addon.PlateCVars = PlateCVars
