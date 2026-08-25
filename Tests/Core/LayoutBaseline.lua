return function(Addon, T)
	local Baseline = Addon.LayoutBaseline
	local Keys = Addon.PreferenceKeys

	---@param settings table
	---@return Preferences
	local function Preferences(settings)
		return Addon.Preferences.New(Addon.PreferenceCatalog, settings, function() end)
	end

	T.Suite("LayoutBaseline", function()
		T.Test("perfil sem carimbo esta desatualizado", function()
			T.Equals(Baseline.IsOutdated(nil), true)
		end)

		T.Test("carimbo da versao atual esta em dia", function()
			T.Equals(Baseline.IsOutdated(Baseline.VERSION), false)
		end)

		T.Test("carimbo anterior esta desatualizado", function()
			T.Equals(Baseline.IsOutdated(Baseline.VERSION - 1), true)
		end)

		--- Um perfil de versao antiga guarda o valor que era padrao naquela
		--- epoca. Sem isto ele fica preso nele para sempre, e so' sai com um
		--- clique manual dado na hora exata.
		T.Test("aplica devolve as chaves de layout ao padrao e carimba", function()
			local settings = { [Keys.ANCHOR_POINT] = "top", [Keys.OFFSET_X] = 99 }
			local profile = { settings = settings }

			T.Equals(Baseline.Apply(Preferences(settings), profile), true)

			local catalog = Addon.PreferenceLookup
			T.Equals(settings[Keys.ANCHOR_POINT], catalog.Find(Addon.PreferenceCatalog, Keys.ANCHOR_POINT).default)
			T.Equals(settings[Keys.OFFSET_X], catalog.Find(Addon.PreferenceCatalog, Keys.OFFSET_X).default)
			T.Equals(profile.layoutVersion, Baseline.VERSION)
		end)

		T.Test("aplicar de novo nao mexe em nada", function()
			local settings = {}
			local profile = { settings = settings }

			Baseline.Apply(Preferences(settings), profile)
			settings[Keys.OFFSET_X] = 99

			T.Equals(Baseline.Apply(Preferences(settings), profile), false)
			T.Equals(settings[Keys.OFFSET_X], 99, "ajuste feito depois tem de sobreviver")
		end)

		--- Arranjo na tela e' uma coisa; escolha de jogo e' outra. Um baseline
		--- que reescrevesse "quando mostrar" ou "seguir outras unidades" estaria
		--- desfazendo decisao, nao corrigindo posicao.
		T.Test("nao toca em preferencia de comportamento", function()
			local settings = {
				[Keys.VISIBILITY_MODE] = "always",
				[Keys.TRACK_OTHER_UNITS] = true,
				[Keys.HOLD_DURATION] = 12,
			}
			local profile = { settings = settings }

			Baseline.Apply(Preferences(settings), profile)

			T.Equals(settings[Keys.VISIBILITY_MODE], "always")
			T.Equals(settings[Keys.TRACK_OTHER_UNITS], true)
			T.Equals(settings[Keys.HOLD_DURATION], 12)
		end)

		T.Test("toda chave listada existe no catalogo", function()
			for _, key in ipairs(Baseline.KEYS) do
				Addon.PreferenceLookup.Find(Addon.PreferenceCatalog, key)
			end
		end)
	end)
end
