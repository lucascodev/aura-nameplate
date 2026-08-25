local _, Addon = ...

local TARGET = "target"

--- Walks the same path the display walks, and says where it stops.
---
--- Every call is wrapped: the whole point is to run when something is already
--- going wrong, and a self-check that dies on the broken step reports nothing.
---@class Probe : DiagnosticsProbe
---@field private frames table<string, table> Os renderizadores, por rotulo.
---@field private displays table<string, table>
---@field private anchor NameplateAnchor
---@field private preferences Preferences
local Probe = {}
Probe.__index = Probe

local L = Addon.L

---@param parts { frames: table<string, table>, displays: table<string, table>, anchor: NameplateAnchor, preferences: Preferences }
---@return Probe
function Probe.New(parts)
	return setmetatable({
		frames = parts.frames,
		displays = parts.displays,
		anchor = parts.anchor,
		preferences = parts.preferences,
		portraits = parts.portraits,
		combatPlates = parts.combatPlates,
		windows = parts.windows,
		refreshFailures = parts.refreshFailures,
	}, Probe)
end

---@param lines DiagnosticLine[]
---@param label string
---@param value string
local function Add(lines, label, value)
	table.insert(lines, { label = label, value = value })
end

---@param isPresent any
---@return string
local function YesNo(isPresent)
	return isPresent and L.DIAG_YES or L.DIAG_NO
end

--- Names every client function this addon leans on that is recent enough to be
--- missing. One of them absent explains an empty screen on its own.
---@param lines DiagnosticLine[]
local function ReadApi(lines)
	local names = {
		"C_NamePlate",
		"UnitHealthPercent",
		"CurveConstants",
		"AbbreviateNumbers",
		"issecretvalue",
	}
	local missing = {}

	for _, name in ipairs(names) do
		if _G[name] == nil then
			table.insert(missing, name)
		end
	end

	Add(lines, L.DIAG_API, #missing == 0 and L.DIAG_ALL_PRESENT or table.concat(missing, ", "))
end

--- Um valor que pode ser classificado, escrito sem nunca ser testado.
---@param value any
---@return string
local function Guarded(value)
	if Addon.Secrets.Is(value) then
		return "?"
	end

	return tostring(value == true)
end

--- O nome da fase, quando o alvo esta em outra.
---
--- E o suspeito certo para "alvo existe, placa nao": um jogador em outra
--- fase/shard aparece com (*) no nome, pode ser mirado, mas nao esta de fato
--- neste mundo — e o jogo nao cria placa para quem nao esta. Nenhum addon
--- desenha nada nesse caso.
---@return string
local function PhaseOf()
	if not UnitPhaseReason then
		return L.DIAG_MISSING
	end

	local ok, reason = pcall(UnitPhaseReason, TARGET)

	if not ok then
		return L.DIAG_ERROR
	end

	if reason == nil then
		return L.DIAG_SAME_PHASE
	end

	if Addon.Secrets.Is(reason) then
		return "?"
	end

	for name, value in pairs(Enum and Enum.PhaseReason or {}) do
		if value == reason then
			return name
		end
	end

	return tostring(reason)
end

--- Um valor de qualquer tipo, escrito sem ser testado: "?" para classificado,
--- "-" para ausente.
---@param ok boolean
---@param value any
---@return string
local function Plain(ok, value)
	if not ok then
		return L.DIAG_ERROR
	end

	if value == nil then
		return "-"
	end

	if Addon.Secrets.Is(value) then
		return "?"
	end

	return tostring(value)
end

--- Quem o alvo e, nos eixos que decidem se ele tem placa.
---
--- A faccao e a reacao entram porque "aliado=false" sozinho ainda deixa duvida:
--- um jogador da faccao oposta num santuario nao e' aliado nem atacavel, e cai
--- entre as duas categorias de placa que o cliente oferece.
---@param lines DiagnosticLine[]
local function ReadTargetProfile(lines)
	local _, isPlayer = pcall(UnitIsPlayer, TARGET)
	local _, isFriend = pcall(UnitIsFriend, "player", TARGET)
	local okFaction, faction = pcall(UnitFactionGroup, TARGET)
	local okReaction, reaction = pcall(UnitReaction, "player", TARGET)
	local _, inParty = pcall(UnitInParty, TARGET)

	Add(lines, L.DIAG_TARGET_PROFILE, (L.DIAG_TARGET_PROFILE_VALUE):format(
		Guarded(isPlayer),
		Guarded(isFriend),
		Plain(okFaction, faction),
		Plain(okReaction, reaction),
		Guarded(inParty),
		PhaseOf()
	))
end

--- The plate, and the reason there is none. "Refused" and "the unit has no
--- plate" look the same to the display and mean very different things.
---@param lines DiagnosticLine[]
---@return table? plate
local function ReadNameplate(lines)
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, TARGET)

	if not ok then
		Add(lines, L.DIAG_NAMEPLATE, ("%s (%s)"):format(L.DIAG_ERROR, tostring(plate)))
		return nil
	end

	if not plate then
		Add(lines, L.DIAG_NAMEPLATE, L.DIAG_NO)
		return nil
	end

	local asked, isForbidden = pcall(plate.IsForbidden, plate)

	if not asked then
		Add(lines, L.DIAG_NAMEPLATE, ("%s (%s)"):format(L.DIAG_ERROR, tostring(isForbidden)))
		return nil
	end

	if isForbidden == true then
		Add(lines, L.DIAG_NAMEPLATE, L.DIAG_FORBIDDEN)
		return nil
	end

	Add(lines, L.DIAG_NAMEPLATE, L.DIAG_YES)
	Add(lines, L.DIAG_UNIT, tostring(plate.namePlateUnitToken or L.DIAG_MISSING))

	-- Sem achar o nome nao ha' o que levantar, e a opcao vira silencio: e' a
	-- diferenca entre "movi e o cliente moveu de volta" e "nunca movi nada".
	local host = Addon.NameplateRegistry.ForUnit(TARGET)

	Add(lines, L.DIAG_NAME_FOUND, host and host.name and L.DIAG_YES or L.DIAG_NO)

	-- Achar o conteiner de auras falha em silencio de dois jeitos bem
	-- diferentes: o campo nao existe nesta versao, ou existe e o cliente
	-- recusa. A correcao de cada um e' outra.
	Add(lines, L.DIAG_AURAS_FOUND, host and host.auras and L.DIAG_YES or L.DIAG_NO)

	-- "Achei o conteiner" e "ha' aura para ver" sao coisas diferentes, e as
	-- falhas correspondentes sao opostas: uma e' nao ter movido, a outra e' ter
	-- movido para onde nao se ve. Sem o estado, as duas parecem iguais na tela.
	if host and host.auras then
		local ok, shown = pcall(host.auras.IsShown, host.auras)
		local _, children = pcall(host.auras.GetNumChildren, host.auras)

		Add(lines, L.DIAG_AURAS_STATE, ("%s, %s %s"):format(
			ok and (shown and L.DIAG_YES or L.DIAG_HIDDEN) or L.DIAG_ERROR,
			tostring(type(children) == "number" and children or 0),
			L.DIAG_AURA_CHILDREN
		))
	end

	return plate
end

--- The value itself is never printed. It is very likely classified, and the
--- only thing worth knowing here is whether something came back at all.
---@param lines DiagnosticLine[]
local function ReadHealth(lines)
	local ok, reading = pcall(
		Addon.UnitHealthReading.Text,
		TARGET,
		Addon.HealthFormats.PERCENT
	)

	if not ok then
		Add(lines, L.DIAG_HEALTH, ("%s (%s)"):format(L.DIAG_ERROR, tostring(reading)))
		return
	end

	if reading == nil then
		Add(lines, L.DIAG_HEALTH, L.DIAG_NO)
		return
	end

	local isSecret = Addon.Secrets.Is(reading.text)

	Add(lines, L.DIAG_HEALTH, isSecret and L.DIAG_SECRET or L.DIAG_READABLE)
end

--- Where a frame ended up. Marked visible with no coordinate means the anchor
--- never took hold, which is a different fault from the rule deciding to hide.
---@param lines DiagnosticLine[]
---@param label string
---@param frame table
local function ReadFrame(lines, label, frame)
	local ok, state = pcall(frame.Inspect, frame)

	if not ok then
		Add(lines, label, ("%s (%s)"):format(L.DIAG_ERROR, tostring(state)))
		return
	end

	if not state.isShown then
		Add(lines, label, L.DIAG_HIDDEN)
		return
	end

	if not state.isMeasurable then
		Add(lines, label, L.DIAG_RESTRICTED)
		return
	end

	if not state.left or not state.top then
		Add(lines, label, L.DIAG_NO_POSITION)
		return
	end

	Add(lines, label, ("%s  x=%d y=%d w=%d"):format(
		L.DIAG_DRAWN,
		state.left,
		state.top,
		state.width
	))
end

--- The plate's own numbers, to compare against ours: an icon sitting far from
--- the plate it is anchored to says the two are being measured on different
--- scales.
---@param lines DiagnosticLine[]
---@param plate table
local function ReadPlate(lines, plate)
	local ok, left = pcall(plate.GetLeft, plate)
	local _, top = pcall(plate.GetTop, plate)

	if not ok then
		Add(lines, L.DIAG_PLATE_AT, L.DIAG_RESTRICTED)
		return
	end

	if not left or not top then
		Add(lines, L.DIAG_PLATE_AT, L.DIAG_NO_POSITION)
		return
	end

	Add(lines, L.DIAG_PLATE_AT, ("x=%d y=%d"):format(left, top))
end

--- A pergunta que o display faz, feita ao mesmo objeto que ele pergunta. A
--- checagem da API sozinha nao serve: entre ela e o desenho ainda ha a regra de
--- alvo aliado e a recusa do frame.
---@param lines DiagnosticLine[]
local function ReadHost(lines, anchor)
	local ok, host = pcall(anchor.Nameplate, anchor)

	if not ok then
		Add(lines, L.DIAG_HOST, ("%s (%s)"):format(L.DIAG_ERROR, tostring(host)))
		return
	end

	Add(lines, L.DIAG_HOST, host and L.DIAG_YES or L.DIAG_NO)
end

--- O que um conteiner de auras pode se chamar, sem depender de eu acertar o
--- nome exato: qualquer campo cujo nome mencione uma destas palavras.
local AURA_WORDS = { "aura", "buff", "debuff" }

---@param value any
---@return boolean
local function LooksLikeFrame(value)
	return type(value) == "table" and type(value.GetObjectType) == "function"
end

--- Enumera os frames que a placa carrega, em vez de conferir uma lista de
--- nomes que eu tenha adivinhado.
---
--- Chutar nomes de campo so' responde "nao achei" — nunca diz onde procurar. Um
--- campo que o cliente renomeou entre versoes e' invisivel de qualquer outro
--- jeito, e enumerar e' o unico caminho que sobra.
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

---@param lines DiagnosticLine[]
---@param plate table?
local function ReadPlateFields(lines, plate)
	if not plate then
		return
	end

	local total = 0
	local candidates = {}
	local owners = { plate = plate, UnitFrame = plate.UnitFrame, unitFrame = plate.unitFrame }

	for owner, frame in pairs(owners) do
		if type(frame) == "table" then
			-- pcall porque percorrer um frame do cliente pode esbarrar num
			-- campo que ele recusa, e o autoteste nao pode morrer por isso.
			pcall(function()
				for field, value in pairs(frame) do
					if LooksLikeFrame(value) then
						total = total + 1

						if SoundsLikeAura(tostring(field)) then
							table.insert(candidates, owner .. "." .. tostring(field))
						end
					end
				end
			end)
		end
	end

	table.sort(candidates)

	-- Contar o total importa: uma lista vazia so' significa alguma coisa se
	-- ficar claro quantos campos foram olhados para chegar nela.
	Add(lines, L.DIAG_PLATE_FIELDS, ("%s (%d %s)"):format(
		#candidates > 0 and table.concat(candidates, " ") or L.DIAG_NO,
		total,
		L.DIAG_FIELDS_SCANNED
	))
end

--- Quantas placas o addon esta' desenhando. Desde que ha uma linha de vida por
--- nameplate, "o frame esta' visivel?" deixou de ter resposta unica.
---@param lines DiagnosticLine[]
local function ReadPlateCount(lines, anchor)
	local ok, hosts = pcall(anchor.Nameplates, anchor)

	if not ok then
		Add(lines, L.DIAG_PLATES, ("%s (%s)"):format(L.DIAG_ERROR, tostring(hosts)))
		return
	end

	Add(lines, L.DIAG_PLATES, tostring(#hosts))
end

--- Os interruptores que podem esconder tudo sem nada estar quebrado.
---@param lines DiagnosticLine[]
---@param preferences Preferences
local function ReadSettings(lines, preferences)
	local Keys = Addon.PreferenceKeys

	Add(lines, L.DIAG_SETTINGS, ("%s=%s  %s=%s  %s=%s  %s=%s"):format(
		Keys.ENABLED, tostring(preferences:Get(Keys.ENABLED)),
		Keys.HEALTH_TEXT_ENABLED, tostring(preferences:Get(Keys.HEALTH_TEXT_ENABLED)),
		Keys.HEALTH_VISIBILITY_MODE, tostring(preferences:Get(Keys.HEALTH_VISIBILITY_MODE)),
		Keys.SHOW_ON_FRIENDLY, tostring(preferences:Get(Keys.SHOW_ON_FRIENDLY))
	))
end

--- Todo nome de chave de nameplate que este cliente conhece de verdade.
---
--- A lista das nossas veio de outro addon e de outra versao; um nome que mudou
--- devolve nil na leitura e o interruptor vira enfeite, sem nada explicando por
--- que. Enumerar e' o unico jeito de saber, e o cliente sabe responder.
---@return string[]
local function KnownPlateCVars()
	if not ConsoleGetAllCommands then
		return { L.DIAG_MISSING }
	end

	local ok, commands = pcall(ConsoleGetAllCommands)

	if not ok or type(commands) ~= "table" then
		return { L.DIAG_ERROR }
	end

	local found = {}

	for _, entry in ipairs(commands) do
		local name = type(entry) == "table" and entry.command or nil

		if type(name) == "string" then
			local lowered = name:lower()

			-- Alem dos "Show": o empilhamento vive em outra familia de nomes,
			-- e um filtro estreito esconderia o sucessor de um nome renomeado.
			if lowered:find("nameplateshow", 1, true)
				or (lowered:find("nameplate", 1, true) and (
					lowered:find("motion", 1, true)
					or lowered:find("stack", 1, true)
					or lowered:find("overlap", 1, true)
				))
			then
				table.insert(found, name)
			end
		end
	end

	table.sort(found)

	return found
end

--- Quais das nossas o cliente nao conhece. Uma so' ja' explica um interruptor
--- que nao faz nada.
---@param lines DiagnosticLine[]
local function ReadOurPlateCVars(lines)
	local unknown = {}

	for _, binding in ipairs(Addon.PlateVisibility.Bindings) do
		if Addon.PlateCVars.NameOf(binding.cvars) == nil then
			table.insert(unknown, binding.cvars[1])
		end
	end

	Add(
		lines,
		L.DIAG_PLATE_CVARS_UNKNOWN,
		#unknown == 0 and L.DIAG_ALL_PRESENT or table.concat(unknown, ", ")
	)
	Add(lines, L.DIAG_PLATE_CVARS_KNOWN, table.concat(KnownPlateCVars(), ", "))
end

--- As chaves do jogo, que nao sao as nossas — pelo nome que ESTE cliente
--- conhece, e com o valor que esta valendo agora.
---
--- Duas causas com a mesma cara na tela: sem a do jogo nao existe placa nenhuma
--- para desenhar, e sem a nossa existe placa e nos e' que nao desenhamos. Os
--- nomes sao resolvidos, nunca fixos: ler o nome de outra versao imprimiria
--- nil para uma chave viva sob outro nome.
---@param lines DiagnosticLine[]
local function ReadClientPlates(lines)
	local parts = {}

	for _, binding in ipairs(Addon.PlateVisibility.Bindings) do
		local name = Addon.PlateCVars.NameOf(binding.cvars)

		if name then
			table.insert(
				parts,
				("%s=%s"):format(name, tostring(Addon.PlateCVars.Read(binding.cvars)))
			)
		end
	end

	Add(lines, L.DIAG_CLIENT_PLATES, table.concat(parts, "  "))
end

--- A placa pessoal, se o rastreador a enxerga.
---
--- Ela chega pelo mesmo evento das outras, com token proprio de nameplate, mas
--- e' um template diferente — e pode ser proibida ou nao ter a barra onde o
--- registro procura. "O jogo criou e nos nao achamos" e "o jogo nem criou" sao
--- consertos opostos.
---@param lines DiagnosticLine[]
---@param anchor NameplateAnchor
local function ReadOwnPlate(lines, anchor)
	local ok, hosts = pcall(anchor.Nameplates, anchor)

	if not ok then
		Add(lines, L.DIAG_OWN_PLATE, ("%s (%s)"):format(L.DIAG_ERROR, tostring(hosts)))
		return
	end

	for _, host in ipairs(hosts) do
		local asked, isSelf = pcall(UnitIsUnit, host.unit, "player")

		if asked and not Addon.Secrets.Is(isSelf) and isSelf == true then
			Add(lines, L.DIAG_OWN_PLATE, ("%s (%s)"):format(L.DIAG_YES, tostring(host.unit)))
			return
		end
	end

	Add(lines, L.DIAG_OWN_PLATE, L.DIAG_NO)
end

--- Quantos rostos a ultima passada desenhou, e o erro quando houve um.
---@param lines DiagnosticLine[]
---@param portraits table?
local function ReadPortraits(lines, portraits)
	if not portraits then
		return
	end

	local state = portraits:Inspect()

	Add(lines, L.DIAG_PORTRAITS, state.failure
		and ("%s (%s)"):format(L.DIAG_ERROR, state.failure)
		or tostring(state.count))
end

--- O sumico de aliados: interruptor, ultima acao e a recusa mais recente do
--- cliente. Em combate com o interruptor ligado, as chaves aliadas da linha
--- acima devem estar em false; em true, a escrita nao pegou e a recusa diz
--- por que.
---@param lines DiagnosticLine[]
---@param preferences Preferences
---@param combatPlates table?
local function ReadCombatPlates(lines, preferences, combatPlates)
	if not combatPlates then
		return
	end

	Add(lines, L.DIAG_COMBAT_PLATES, ("%s=%s  lastAction=%s  refused=%s"):format(
		Addon.PreferenceKeys.HIDE_FRIENDLY_IN_COMBAT,
		tostring(preferences:Get(Addon.PreferenceKeys.HIDE_FRIENDLY_IN_COMBAT)),
		combatPlates:LastAction(),
		tostring(Addon.PlateCVars.LastFailure())
	))
end

--- O estado dos veus sobre os quadros da Blizzard.
---@param lines DiagnosticLine[]
---@param windows table?
local function ReadWindows(lines, windows)
	if not windows then
		return
	end

	local failure = windows:LastPaintFailure()

	Add(lines, L.DIAG_WINDOWS, table.concat(windows:InspectVeils(), "  ")
		.. (failure and ("  erro=%s"):format(failure) or ""))
end

--- A corrente de redesenho, estagio por estagio: o primeiro "erro" explica
--- todo "nada atualiza".
---@param lines DiagnosticLine[]
---@param failures table<string, string>?
local function ReadPipeline(lines, failures)
	if not failures then
		return
	end

	local parts = {}

	for _, name in ipairs({ "names", "portraits", "windows", "auras", "icon", "health" }) do
		table.insert(parts, ("%s=%s"):format(name, failures[name] or "ok"))
	end

	Add(lines, L.DIAG_PIPELINE, table.concat(parts, "  "))
end

--- A ultima pergunta possivel: manda desenhar agora e ve o que acontece.
---
--- Um frame escondido com a regra mandando mostrar so pode significar que o
--- desenho morreu no meio, e o erro nao chega a lugar nenhum porque o cliente
--- vem com os erros de Lua desligados. Aqui ele e' capturado e escrito.
---@param lines DiagnosticLine[]
---@param label string
---@param display table
local function ReadRefresh(lines, label, display)
	local ok, failure = pcall(display.Refresh, display)

	Add(lines, label, ok and L.DIAG_YES or ("%s (%s)"):format(L.DIAG_ERROR, tostring(failure)))
end

--- Se a nossa fileira desenhou, e o que a impediu quando nao.
---@param lines DiagnosticLine[]
---@param auras table
local function ReadOwnAuras(lines, auras)
	if not auras then
		return
	end

	local supported = Addon.OwnAuras.IsSupported()

	if not supported then
		Add(lines, L.DIAG_OWN_AURAS, L.DIAG_NO_TEMPLATE)
		return
	end

	local ok, failure = pcall(auras.Refresh, auras)

	if not ok then
		Add(lines, L.DIAG_OWN_AURAS, ("%s (%s)"):format(L.DIAG_ERROR, tostring(failure)))
		return
	end

	local captured = auras:LastFailure()

	Add(lines, L.DIAG_OWN_AURAS, captured and ("%s (%s)"):format(L.DIAG_ERROR, captured) or L.DIAG_YES)
end

---@return DiagnosticLine[]
function Probe:Read()
	local lines = {}

	ReadApi(lines)
	Add(lines, L.DIAG_HEALTH_FORMAT, Addon.HealthAbbreviation.Describe())
	Add(lines, L.DIAG_TARGET, YesNo(UnitExists(TARGET)))

	if not UnitExists(TARGET) then
		return lines
	end

	ReadTargetProfile(lines)

	local plate = ReadNameplate(lines)

	if plate then
		ReadHealth(lines)
		ReadPlate(lines, plate)
	end

	-- A varredura usa a placa que o display encontrou, e nao a consulta direta:
	-- e' justamente quando a direta falha que saber o que a placa tem importa.
	local host = self.anchor:Nameplate()

	ReadPlateFields(lines, plate or (host and host.frame and host.frame:GetParent()))
	ReadHost(lines, self.anchor)
	ReadPlateCount(lines, self.anchor)
	ReadSettings(lines, self.preferences)
	ReadClientPlates(lines)
	ReadOurPlateCVars(lines)
	ReadOwnPlate(lines, self.anchor)
	ReadPortraits(lines, self.portraits)
	ReadCombatPlates(lines, self.preferences, self.combatPlates)
	ReadWindows(lines, self.windows)
	ReadPipeline(lines, self.refreshFailures)

	ReadRefresh(lines, L.DIAG_HEALTH_REFRESH, self.displays.health)
	ReadOwnAuras(lines, self.displays.auras)
	ReadFrame(lines, L.DIAG_ICON_FRAME, self.frames.icon)

	return lines
end

Addon.Probe = Probe
