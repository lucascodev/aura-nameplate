return function(Addon, T)
	local PlateVisibility = Addon.PlateVisibility
	local Keys = Addon.PreferenceKeys

	---@param settings table
	---@return Preferences
	local function Preferences(settings)
		return Addon.Preferences.New(Addon.PreferenceCatalog, settings, function() end)
	end

	--- Responde so' pelos nomes que conhece, como um cliente de verdade: os
	--- outros voltam nil, e nil nao e' "desligado".
	---@param answers table<string, boolean>
	---@return fun(cvars: string[]): boolean?
	local function Client(answers)
		return function(cvars)
			for _, cvar in ipairs(cvars) do
				if answers[cvar] ~= nil then
					return answers[cvar]
				end
			end

			return nil
		end
	end

	T.Suite("PlateVisibility", function()
		T.Test("toda ligacao aponta para uma preferencia que existe", function()
			for _, binding in ipairs(PlateVisibility.Bindings) do
				T.IsTrue(
					Addon.PreferenceLookup.Find(Addon.PreferenceCatalog, binding.key) ~= nil,
					binding.key .. " nao esta no catalogo"
				)
			end
		end)

		--- Uma lista vazia nunca resolveria nome nenhum, e o interruptor viraria
		--- enfeite sem nada dizendo por que.
		T.Test("toda ligacao oferece ao menos um nome de chave", function()
			for _, binding in ipairs(PlateVisibility.Bindings) do
				T.IsTrue(
					type(binding.cvars) == "table" and #binding.cvars > 0,
					binding.key .. " sem nome de chave"
				)
			end
		end)

		--- Um nome que mudou de versao custa uma entrada na lista; o cliente
		--- antigo continua atendido pelo nome que ele conhece.
		T.Test("um cliente que so conhece o nome antigo ainda e semeado", function()
			local settings = {}

			PlateVisibility.SeedOnce(Preferences(settings), {}, Client({
				nameplateShowFriends = false,
			}))

			T.Equals(settings[Keys.PLATES_FRIENDLY_PLAYERS], false)
		end)

		--- Sem isto o addon chegaria trocando as nameplates de quem instalou
		--- pelos padroes do catalogo, que sao nossos e nao dele.
		T.Test("semear traz o que o jogo ja tem", function()
			local settings = {}
			local profile = {}

			PlateVisibility.SeedOnce(Preferences(settings), profile, Client({
				nameplateShowFriendlyPlayers = true,
				nameplateShowEnemies = false,
			}))

			T.Equals(settings[Keys.PLATES_FRIENDLY_PLAYERS], true)
			T.Equals(settings[Keys.PLATES_ENEMIES], false)
		end)

		--- Uma chave que este cliente nao conhece devolve nil, e gravar nil
		--- trocaria o padrao do catalogo por nada.
		T.Test("chave desconhecida pelo cliente mantem o padrao do catalogo", function()
			local settings = {}
			local preference = Addon.PreferenceLookup.Find(
				Addon.PreferenceCatalog,
				Keys.PLATES_FRIENDLY_PLAYERS
			)

			PlateVisibility.SeedOnce(Preferences(settings), {}, Client({}))

			T.Equals(settings[Keys.PLATES_FRIENDLY_PLAYERS], preference.default)
		end)

		T.Test("semear acontece uma vez so", function()
			local settings = {}
			local profile = {}
			local preferences = Preferences(settings)

			T.Equals(PlateVisibility.SeedOnce(preferences, profile, Client({
				nameplateShowFriendlyPlayers = true,
			})), true)

			T.Equals(PlateVisibility.SeedOnce(preferences, profile, Client({
				nameplateShowFriendlyPlayers = false,
			})), false)

			T.Equals(settings[Keys.PLATES_FRIENDLY_PLAYERS], true)
		end)

		T.Test("aplicar escreve uma chave por ligacao", function()
			local written = {}

			-- Valores postos de proposito, e nao os padroes do catalogo: o teste
			-- afirma que Apply escreve a escolha salva, seja ela qual for.
			PlateVisibility.Apply(Preferences({
				[Keys.PLATES_ENEMIES] = false,
				[Keys.PLATES_FRIENDLY_PLAYERS] = true,
			}), function(cvars, isOn)
				written[cvars[1]] = isOn
			end)

			T.Equals(written.nameplateShowEnemies, false)
			T.Equals(written.nameplateShowFriendlyPlayers, true)
		end)

		--- O silencio de combate apaga so aliado: apagar inimigo junto deixaria
		--- a tela vazia exatamente quando ela mais importa.
		T.Test("esconder aliados nao toca nas chaves inimigas", function()
			local written = {}

			PlateVisibility.HideFriendly(function(cvars, isOn)
				written[cvars[1]] = isOn
			end)

			T.Equals(written.nameplateShowFriendlyPlayers, false)
			T.Equals(written.nameplateShowFriendlyNpcs, false)
			T.Equals(written.nameplateShowEnemies, nil)
			T.Equals(written.nameplateShowSelf, nil)
			T.Equals(written.nameplateMotion, nil)
		end)

		T.Test("reconhece as chaves que manda, e so elas", function()
			T.Equals(PlateVisibility.Owns(Keys.PLATES_SELF), true)
			T.Equals(PlateVisibility.Owns(Keys.HEALTH_COLOR), false)
		end)
	end)
end
