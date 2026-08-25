local _, Addon = ...

local KILO = 1e3
local MEGA = 1e6

--- Onde o K deixa de caber: cem milhões. Abaixo disso a vida é escrita em K por
--- maior que seja — "1,5M" esconde a diferença entre 1,5M e 1,6M, e essa
--- diferença é exatamente o que se está olhando numa barra de vida.
local MEGA_THRESHOLD = 1e8

--- As regras, da maior faixa para a menor, na forma que o cliente entende.
---
--- `significandDivisor` é a divisão que produz a parte inteira e
--- `fractionDivisor` é a potência de dez das casas decimais — os dois em um
--- porque não queremos casa nenhuma: 1500K, e não 1,5K.
local BREAKPOINTS = {
	{
		breakpoint = MEGA_THRESHOLD,
		abbreviation = "M",
		significandDivisor = MEGA,
		fractionDivisor = 1,
		abbreviationIsGlobal = false,
	},
	{
		breakpoint = KILO,
		abbreviation = "K",
		significandDivisor = KILO,
		fractionDivisor = 1,
		abbreviationIsGlobal = false,
	},
}

--- Um número comum, e a resposta que ele tem que dar. Serve para provar que a
--- configuração não só foi aceita como está valendo: um cliente que a ignorasse
--- em silêncio devolveria "2M" aqui e nós acharíamos que estava tudo certo.
local PROBE_VALUE = 1500000
local PROBE_EXPECTED = "1500K"

--- A vida escrita em K muito além de onde o jogo pararia.
---
--- A conta não pode ser nossa. Dividir a vida por mil é aritmética sobre um
--- valor classificado, e o formatador de regras do cliente — que faria a conta
--- — só aceita valor classificado em execução não contaminada, ou seja, nunca
--- vindo de um addon. `AbbreviateNumbers` é a exceção: ele aceita classificado
--- de qualquer origem, e aceita também uma configuração de faixas. As faixas
--- são nossas, a conta é dele, e o número não é lido por ninguém aqui.
---@class HealthAbbreviation
local HealthAbbreviation = {}

--- O segundo argumento que o cliente aceitou, quando aceitou.
---@type any
local argument
---@type string?
local failure

---@return any?
local function BuildConfig()
	if not CreateAbbreviateConfig then
		failure = Addon.L.DIAG_NO_ABBREVIATE_CONFIG
		return nil
	end

	local ok, config = pcall(CreateAbbreviateConfig, BREAKPOINTS)

	if not ok then
		failure = tostring(config)
		return nil
	end

	return config
end

--- Duas formas de entregar a configuração: a direta, e a embrulhada numa tabela
--- que carrega as faixas junto. Não deu para confirmar qual delas o cliente quer
--- sem abrir o jogo, então as duas são provadas com um número comum e a que
--- devolver a resposta certa fica. Provar custa duas chamadas, uma vez.
---@param config any
---@return any[]
local function Candidates(config)
	return { config, { config = config, breakpoints = BREAKPOINTS } }
end

--- Resolvida na primeira vida escrita, e guardada. Uma configuração por leitura
--- seria um objeto novo a cada quadro em que alguém toma dano.
---@return any?
local function Resolve()
	if argument ~= nil or failure then
		return argument
	end

	local config = BuildConfig()

	if not config then
		return nil
	end

	for _, candidate in ipairs(Candidates(config)) do
		local ok, text = pcall(AbbreviateNumbers, PROBE_VALUE, candidate)

		if ok and text == PROBE_EXPECTED then
			argument = candidate

			return argument
		end
	end

	failure = Addon.L.DIAG_ABBREVIATE_REFUSED

	return nil
end

--- Escreve o número. Sem as nossas faixas, cai no abreviador cru do jogo: o K
--- parar em um milhão é pior do que a linha de vida sumir.
---@param value any Vida crua, possivelmente classificada.
---@return unknown
function HealthAbbreviation.Of(value)
	local resolved = Resolve()

	if not resolved then
		return AbbreviateNumbers(value)
	end

	return AbbreviateNumbers(value, resolved)
end

--- Por qual caminho a vida está sendo escrita, para o autoteste.
---@return string
function HealthAbbreviation.Describe()
	Resolve()

	if failure then
		return ("%s (%s)"):format(Addon.L.DIAG_FALLBACK, failure)
	end

	return ("%s (%s)"):format(Addon.L.DIAG_OWN_RULES, PROBE_EXPECTED)
end

Addon.HealthAbbreviation = HealthAbbreviation
