local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Quais placas o jogo desenha.
---
--- Não é preferência de aparência: são as chaves do próprio cliente, as mesmas
--- de Opções → Nomes. O addon decora a placa que existe, e decorar o que o jogo
--- não desenha não leva a lugar nenhum — "o addon não mostra a vida" e "o jogo
--- não faz a placa" têm a mesma cara na tela.
---
--- Só o par vive aqui. Ler e escrever CVar é do adaptador, e é por isso que a
--- regra pode ser conferida sem abrir o cliente.
---@class PlateVisibility
local PlateVisibility = {}

--- Cada ligação carrega uma lista de nomes, do atual para o antigo.
---
--- Não é excesso de zelo: `nameplateShowFriends` virou `nameplateShowFriendlyPlayers`
--- e o interruptor virou enfeite em silêncio — a leitura devolvia nil e nada
--- explicava por quê. Com a lista, um nome que muda custa uma entrada, e o
--- cliente antigo continua atendido pelo nome que ele conhece.
---@type { key: string, cvars: string[] }[]
PlateVisibility.Bindings = {
	{
		key = Keys.PLATES_FRIENDLY_PLAYERS,
		cvars = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" },
	},
	{ key = Keys.PLATES_FRIENDLY_NPCS, cvars = { "nameplateShowFriendlyNpcs" } },
	{
		key = Keys.PLATES_FRIENDLY_PETS,
		cvars = { "nameplateShowFriendlyPlayerPets", "nameplateShowFriendlyPets" },
	},
	{
		key = Keys.PLATES_FRIENDLY_TOTEMS,
		cvars = { "nameplateShowFriendlyPlayerTotems", "nameplateShowFriendlyTotems" },
	},
	{
		key = Keys.PLATES_FRIENDLY_GUARDIANS,
		cvars = { "nameplateShowFriendlyPlayerGuardians", "nameplateShowFriendlyGuardians" },
	},
	{
		key = Keys.PLATES_FRIENDLY_NAMES_ONLY,
		cvars = { "nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateShowOnlyNames" },
	},
	{ key = Keys.PLATES_ENEMIES, cvars = { "nameplateShowEnemies" } },
	{ key = Keys.PLATES_ENEMY_MINIONS, cvars = { "nameplateShowEnemyMinions" } },
	{ key = Keys.PLATES_ENEMY_MINUS, cvars = { "nameplateShowEnemyMinus" } },
	{ key = Keys.PLATES_ENEMY_PETS, cvars = { "nameplateShowEnemyPets" } },
	{ key = Keys.PLATES_ENEMY_TOTEMS, cvars = { "nameplateShowEnemyTotems" } },
	{ key = Keys.PLATES_ENEMY_GUARDIANS, cvars = { "nameplateShowEnemyGuardians" } },
	{ key = Keys.PLATES_ALWAYS, cvars = { "nameplateShowAll" } },
	{ key = Keys.PLATES_SELF, cvars = { "nameplateShowSelf" } },
	-- Nao e' um "Show", mas e' o mesmo contrato: um booleano do cliente.
	{ key = Keys.PLATES_STACKED, cvars = { "nameplateMotion" } },
}

--- As chaves que desenham aliado, e so' elas: sao as que saem da frente quando
--- o jogador pede tela limpa em combate.
local FRIENDLY_KEYS = {
	[Keys.PLATES_FRIENDLY_PLAYERS] = true,
	[Keys.PLATES_FRIENDLY_NPCS] = true,
	[Keys.PLATES_FRIENDLY_PETS] = true,
	[Keys.PLATES_FRIENDLY_TOTEMS] = true,
	[Keys.PLATES_FRIENDLY_GUARDIANS] = true,
}

--- Apaga as placas aliadas no cliente sem tocar nas preferencias: o que o
--- jogador escolheu continua salvo, e volta inteiro com Apply.
---@param write fun(cvars: string[], isOn: boolean)
function PlateVisibility.HideFriendly(write)
	for _, binding in ipairs(PlateVisibility.Bindings) do
		if FRIENDLY_KEYS[binding.key] then
			write(binding.cvars, false)
		end
	end
end

--- Marca no perfil, e não uma versão: semear acontece uma vez e nunca mais, ao
--- contrário do baseline de layout, que volta a cada arranjo novo de fábrica.
local SEEDED_FIELD = "hasSeededPlates"

--- A primeira vez, o que o jogo já tem vira o que nós temos.
---
--- Sem isto o addon chegaria sobrescrevendo a configuração do jogador com os
--- padrões do catálogo, que são nossos e não dele. Quem instala não deveria ver
--- as próprias nameplates mudarem sozinhas.
---@param preferences Preferences
---@param profile table
---@param read fun(cvars: string[]): boolean?
---@return boolean hasSeeded
function PlateVisibility.SeedOnce(preferences, profile, read)
	if profile[SEEDED_FIELD] then
		return false
	end

	profile[SEEDED_FIELD] = true

	for _, binding in ipairs(PlateVisibility.Bindings) do
		local current = read(binding.cvars)

		-- Uma chave que este cliente não tem devolve nil, e gravar isso trocaria
		-- o padrão do catálogo por nada.
		if current ~= nil then
			preferences:Set(binding.key, current)
		end
	end

	return true
end

--- Escreve todas de uma vez. Repetir é barato: quem escreve compara antes.
---@param preferences Preferences
---@param write fun(cvars: string[], isOn: boolean)
function PlateVisibility.Apply(preferences, write)
	for _, binding in ipairs(PlateVisibility.Bindings) do
		write(binding.cvars, preferences:Get(binding.key) == true)
	end
end

--- Se a chave mexida é uma das nossas. Redesenhar não basta para elas: o efeito
--- só existe depois de o cliente ser avisado.
---@param key string
---@return boolean
function PlateVisibility.Owns(key)
	for _, binding in ipairs(PlateVisibility.Bindings) do
		if binding.key == key then
			return true
		end
	end

	return false
end

Addon.PlateVisibility = PlateVisibility
