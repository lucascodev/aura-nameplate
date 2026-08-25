local _, Addon = ...

--- Um botão da nossa fileira de auras.
---
--- O contêiner do cliente entrega o botão vazio. Ele preenche os dados — que
--- são classificados, e por isso nenhum addon consegue lê-los — mas as regiões
--- que desenham são nossas, e é preciso registrá-las nele para que tenha o que
--- preencher. Sem isso o botão nasce sem tamanho e sem nada dentro: a fileira
--- existe, o autoteste a encontra, e a tela continua vazia.
---@class AuraIcon
local AuraIcon = {}

--- O arquivo do ícone traz uma borda que o jogo recorta ao desenhar.
local TRIM = 0.08

--- Metade do ícone deixa o número legível sem cobrir a arte.
local TEXT_SCALE = 0.5
local MINIMUM_TEXT_SIZE = 8

--- Segundos inteiros até o fim; abaixo de um segundo a aura já saiu.
local DURATION_RULE = { threshold = 0, step = 1, format = "%d" }

---@param size number
---@return number
local function TextSize(size)
	return math.max(MINIMUM_TEXT_SIZE, math.floor(size * TEXT_SCALE))
end

--- O formatador é do cliente e é o mesmo para todo botão: um por ícone seria
--- desperdício, e a regra não muda de um para o outro.
local durationFormatter

---@return table?
local function DurationFormatter()
	if durationFormatter then
		return durationFormatter
	end

	if not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter then
		return nil
	end

	durationFormatter = C_StringUtil.CreateNumericRuleFormatter()
	durationFormatter:AddBreakpoint(DURATION_RULE)

	return durationFormatter
end

--- A arte da aura, recortada.
---@param button table
local function AddIcon(button)
	local icon = button:CreateTexture(nil, "ARTWORK")

	icon:SetAllPoints(button)
	icon:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
	button:SetIcon(icon)
end

--- A varredura que mostra quanto falta sem precisar ler o número.
---@param button table
local function AddSweep(button)
	local sweep = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")

	sweep:SetAllPoints(button)
	sweep:SetDrawBling(false)
	sweep:SetDrawEdge(false)
	-- O número é o nosso, desenhado por cima; o do cooldown seria um segundo
	-- relógio no mesmo ícone.
	sweep:SetHideCountdownNumbers(true)
	sweep:SetReverse(true)
	button:SetDurationCooldown(sweep)
end

---@param button table
---@param font AuraIconFont
local function AddDuration(button, font)
	local text = button:CreateFontString(nil, "OVERLAY")

	text:SetFont(font.path, font.size, font.flags)
	text:SetPoint("CENTER", button, "CENTER")

	button:SetDurationText(text, { textFormatter = DurationFormatter() })
end

---@param button table
---@param font AuraIconFont
local function AddStacks(button, font)
	local text = button:CreateFontString(nil, "OVERLAY")

	text:SetFont(font.path, font.size, font.flags)
	text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")

	button:SetApplicationCount(text)
end

--- De onde o tooltip nasce. À direita do ícone, e não sobre a placa, que é o
--- que se está tentando ler.
local TOOLTIP_ANCHOR = "ANCHOR_RIGHT"

--- Passar o mouse abre os detalhes; clicar continua sendo da placa atrás.
---
--- São dois interruptores, e não um: `SetMouseClickEnabled(false)` com
--- `SetMouseMotionEnabled(true)` deixa o botão ver o mouse passar sem
--- interceptar o clique — senão selecionar o alvo viraria acertar o ícone.
---
--- O tooltip é desenhado pelo cliente. Os dados da aura são classificados, e
--- montá-lo aqui não seria só trabalhoso: seria impossível. Por isso o que se
--- configura é onde ele aparece, não o que ele diz.
---@param button table
local function AcceptHover(button)
	button:EnableMouse(true)
	button:SetMouseClickEnabled(false)
	button:SetMouseMotionEnabled(true)

	-- Nameplate é o que mais se olha justamente em combate; esconder o tooltip
	-- lá seria escondê-lo quando ele serve.
	button:SetHideTooltipInCombat(false)
	button:SetTooltipAnchorPoint(TOOLTIP_ANCHOR, 0, 0)
end

---@class AuraIconFont
---@field path string
---@field size number
---@field flags string

--- Monta um botão que o contêiner acabou de criar.
---@param button table
---@param size number
---@param font { path: string, flags: string }
function AuraIcon.Build(button, size, font)
	local scaled = { path = font.path, size = TextSize(size), flags = font.flags }

	button:SetSize(size, size)

	AcceptHover(button)
	AddIcon(button)
	AddSweep(button)
	AddDuration(button, scaled)
	AddStacks(button, scaled)
end

Addon.AuraIcon = AuraIcon
