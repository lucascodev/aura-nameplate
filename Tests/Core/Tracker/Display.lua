return function(Addon, T, Support)
	local Keys = Addon.PreferenceKeys
	local PLAYER = Addon.CastHistory.PLAYER_SLOT

	---@param overrides table? Valores de preferencia por cima do padrao do catalogo.
	---@param parts table? Colaboradores por cima dos fakes.
	---@return table display
	---@return table parts
	local function Build(overrides, parts)
		parts = parts or {}
		parts.renderer = parts.renderer or Support.Renderer()
		parts.hosts = parts.hosts or Support.Hosts("nameplate1")
		parts.gameState = parts.gameState or Support.GameState()
		parts.preferences = Addon.Preferences.New(
			Addon.PreferenceCatalog,
			overrides or {},
			function() end
		)
		parts.history = parts.history or Addon.CastHistory.New(function()
			return parts.preferences:Get(Keys.HOLD_DURATION)
		end)

		local display = Addon.IconDisplay.New({
			history = parts.history,
			renderer = parts.renderer,
			preferences = parts.preferences,
			hosts = parts.hosts,
			cooldowns = parts.cooldowns or Support.Cooldowns(),
			appearance = Support.AppearanceSources(),
			gameState = parts.gameState,
		})

		return display, parts
	end

	T.Suite("IconDisplay", function()
		T.Test("sem magia gravada, esconde e nao desenha nada", function()
			local display, parts = Build()
			display:Refresh()

			T.Equals(parts.renderer.shown, false)
			T.Equals(parts.renderer.iconID, nil)
		end)

		T.Test("com magia do jogador, desenha o icone dela", function()
			local display, parts = Build()
			parts.history:Record(Support.Cast({ iconID = 777, castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.shown, true)
			T.Equals(parts.renderer.iconID, 777)
		end)

		T.Test("a magia desenhada chega ao renderizador, para o tooltip", function()
			local display, parts = Build()
			parts.history:Record(Support.Cast({ iconID = 777, spellID = 42, castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.spellID, 42)
		end)

		T.Test("o cooldown lido chega ao renderizador sem ser inspecionado", function()
			local reading = { start = 12, duration = 1.5 }
			local display, parts = Build(nil, { cooldowns = Support.Cooldowns(reading) })
			parts.history:Record(Support.Cast({ castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.reading, reading)
		end)

		T.Test("prende no frame do host, com o ponto que a ancora manda", function()
			local display, parts = Build({ [Keys.ANCHOR_POINT] = "bottom", [Keys.OFFSET_Y] = -8 })
			parts.history:Record(Support.Cast({ castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.attachedTo, parts.hosts.host.frame)
			T.Equals(parts.renderer.placement.point, "TOP")
			T.Equals(parts.renderer.placement.y, -8)
		end)

		T.Test("sem nameplate no ar, esconde mesmo tendo magia", function()
			local display, parts = Build(nil, { hosts = Support.Hosts(nil) })
			parts.history:Record(Support.Cast({ castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.shown, false)
		end)

		T.Test("desligado no painel, esconde", function()
			local display, parts = Build({ [Keys.ENABLED] = false })
			parts.history:Record(Support.Cast({ castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.shown, false)
		end)

		T.Test("passado o tempo de retencao, esconde sozinho", function()
			local display, parts = Build({ [Keys.HOLD_DURATION] = 3 })
			parts.history:Record(Support.Cast({ castAt = 0 }))

			parts.gameState.now = 10
			display:Refresh()

			T.Equals(parts.renderer.shown, false)
		end)

		--- O interruptor de outras unidades e a unica coisa que decide se o slot
		--- do nameplate entra na disputa. Desligado, uma magia gravada por ele
		--- nao pode aparecer nem sendo a mais recente.
		T.Test("com outras unidades desligado, so a magia do jogador conta", function()
			local display, parts = Build({ [Keys.TRACK_OTHER_UNITS] = false })
			parts.history:Record(Support.Cast({ slot = PLAYER, iconID = 100, castAt = 0 }))
			parts.history:Record(Support.Cast({ slot = "nameplate1", iconID = 200, castAt = 1 }))

			display:Refresh()

			T.Equals(parts.renderer.iconID, 100)
		end)

		T.Test("com outras unidades ligado, vence a mais recente das duas", function()
			local display, parts = Build({ [Keys.TRACK_OTHER_UNITS] = true })
			parts.history:Record(Support.Cast({ slot = PLAYER, iconID = 100, castAt = 0 }))
			parts.history:Record(Support.Cast({ slot = "nameplate1", iconID = 200, castAt = 1 }))

			display:Refresh()

			T.Equals(parts.renderer.iconID, 200)
		end)

		T.Test("a fonte chega resolvida, com o contorno traduzido", function()
			local display, parts = Build({
				[Keys.FONT_NAME] = "Inter",
				[Keys.FONT_SIZE] = 18,
				[Keys.FONT_FLAG] = "none",
			})
			parts.history:Record(Support.Cast({ castAt = 0 }))

			display:Refresh()

			T.Equals(parts.renderer.font.path, "Inter")
			T.Equals(parts.renderer.font.size, 18)
			T.Equals(parts.renderer.font.flag, "", "none vira string vazia para a API da fonte")
		end)

		T.Test("o teste desenha mesmo sem magia gravada e fora de combate", function()
			local display, parts = Build({ [Keys.VISIBILITY_MODE] = Addon.VisibilityModes.COMBAT })
			parts.gameState.isInCombat = false

			display:SetTesting(Support.Cast({ iconID = 42 }), { start = 0, duration = 1.5 })

			T.Equals(parts.renderer.shown, true)
			T.Equals(parts.renderer.iconID, 42)
		end)

		T.Test("encerrar o teste devolve o controle a magia gravada", function()
			local display, parts = Build()
			display:SetTesting(Support.Cast({ iconID = 42 }))

			display:SetTesting(nil)

			T.Equals(display:IsTesting(), false)
			T.Equals(parts.renderer.shown, false)
		end)
	end)
end
