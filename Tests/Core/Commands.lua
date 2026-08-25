return function(Addon, T, Support)
	local addonInfo = { title = "Aura Nameplate: GCD Tracker", brand = "Aura Nameplate", version = "9.9.9" }

	T.Suite("StatusCommand", function()
		T.Test("escreve titulo e versao no chat", function()
			local logger = Support.Logger()
			Addon.StatusCommand.New(logger, addonInfo):Run()

			T.Equals(#logger.infos, 1)
			T.IsTrue(logger.infos[1]:find("9.9.9", 1, true) ~= nil)
		end)
	end)

	T.Suite("HelpCommand", function()
		T.Test("escreve uma linha por comando", function()
			local logger = Support.Logger()
			local commands = {
				{ command = "/anp", description = "abre" },
				{ command = "/anp ajuda", description = "ajuda" },
			}

			Addon.HelpCommand.New(logger, commands):Run()

			T.Equals(#logger.infos, 2)
			T.IsTrue(logger.infos[1]:find("/anp", 1, true) ~= nil)
		end)

		T.Test("lista vazia nao escreve nada", function()
			local logger = Support.Logger()
			Addon.HelpCommand.New(logger, {}):Run()

			T.Equals(#logger.infos, 0)
		end)
	end)

	T.Suite("DiagnoseCommand", function()
		---@param lines table
		---@return table logger
		local function Run(lines)
			local logger = Support.Logger()

			Addon.DiagnoseCommand.New(logger, {
				Read = function()
					return lines
				end,
			}):Run()

			return logger
		end

		T.Test("escreve o titulo e uma linha por resposta", function()
			local logger = Run({
				{ label = "Alvo", value = "sim" },
				{ label = "Nameplate", value = "recusado pelo cliente" },
			})

			T.Equals(#logger.infos, 3, "titulo mais as duas linhas")
			T.Equals(logger.infos[1], Addon.L.DIAG_TITLE)
			T.IsTrue(logger.infos[3]:find("recusado", 1, true) ~= nil)
		end)

		--- Uma sonda que nao achou nada ainda tem de dizer que rodou, senao o
		--- comando parece nao existir.
		T.Test("sonda sem resposta ainda escreve o titulo", function()
			T.Equals(#Run({}).infos, 1)
		end)
	end)

	T.Suite("Startup", function()
		---@param announce boolean
		---@param hasNewLayout boolean?
		---@return table logger
		local function Run(announce, hasNewLayout)
			local logger = Support.Logger()
			local preferences = Addon.Preferences.New(
				{ { key = "announceOnLoad", default = announce } },
				{},
				function() end
			)

			Addon.Startup.New(logger, addonInfo, preferences, hasNewLayout):Run()

			return logger
		end

		T.Test("anuncia quando a preferencia esta ligada", function()
			T.Equals(#Run(true).infos, 1)
		end)

		T.Test("cala quando esta desligada", function()
			T.Equals(#Run(false).infos, 0)
		end)

		--- Reescrever configuracao salva em nome do jogador e' noticia mesmo
		--- para quem silenciou a saudacao.
		T.Test("avisa do layout refeito mesmo com o anuncio desligado", function()
			local logger = Run(false, true)

			T.Equals(#logger.infos, 1)
			T.Equals(logger.infos[1], Addon.L.LAYOUT_REFRESHED)
		end)
	end)
end
