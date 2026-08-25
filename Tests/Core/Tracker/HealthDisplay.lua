return function(Addon, T, Support)
	local Keys = Addon.PreferenceKeys
	local Formats = Addon.HealthFormats

	---@param overrides table? Valores de preferencia por cima do padrao do catalogo.
	---@param parts table? Colaboradores por cima dos fakes.
	---@return table display
	---@return table parts
	local function Build(overrides, parts)
		parts = parts or {}
		parts.pool = parts.pool or Support.RendererPool()
		parts.hosts = parts.hosts or Support.Hosts("nameplate1")
		parts.health = parts.health or Support.HealthSource("85%")
		parts.gameState = parts.gameState or Support.GameState()
		parts.preferences = Addon.Preferences.New(
			Addon.PreferenceCatalog,
			overrides or {},
			function() end
		)

		local display = Addon.HealthDisplay.New({
			renderers = parts.pool,
			preferences = parts.preferences,
			hosts = parts.hosts,
			health = parts.health,
			appearance = Support.AppearanceSources(),
			gameState = parts.gameState,
		})

		return display, parts
	end

	--- O renderizador da placa unica que quase todos os casos usam.
	---@param parts table
	---@return table
	local function Only(parts)
		return parts.pool:Acquire("nameplate1")
	end

	--- Com um renderizador por placa, "escondido" deixou de ser um campo: e'
	--- nao ter sido desenhado nesta rodada.
	---@param parts table
	---@return boolean
	local function IsShowing(parts)
		local renderer = parts.pool.renderers["nameplate1"]

		return renderer ~= nil and renderer.shown == true
	end

	T.Suite("HealthDisplay", function()
		T.Test("escreve o que a fonte de vida devolveu", function()
			local display, parts = Build()
			display:Refresh()

			T.Equals(IsShowing(parts), true)
			T.Equals(Only(parts).text, "85%")
		end)

		T.Test("pergunta pela unidade do nameplate, no formato escolhido", function()
			local display, parts = Build({ [Keys.HEALTH_TEXT_FORMAT] = Formats.ABBREVIATED })
			display:Refresh()

			T.Equals(parts.health.calls[1].unit, "nameplate1")
			T.Equals(parts.health.calls[1].format, Formats.ABBREVIATED)
		end)

		--- A posicao livre nao tem unidade atras dela, entao nao ha vida para
		--- ler: o texto so acompanha nameplate de verdade.
		T.Test("sem nameplate, esconde e nem chega a perguntar", function()
			local hosts = Support.Hosts("nameplate1")
			hosts.plates = {}

			local display, parts = Build(nil, { hosts = hosts })
			display:Refresh()

			T.Equals(IsShowing(parts), false)
			T.Equals(#parts.health.calls, 0)
		end)

		T.Test("o interruptor de vida esconde so esta linha", function()
			local display, parts = Build({ [Keys.HEALTH_TEXT_ENABLED] = false })
			display:Refresh()

			T.Equals(IsShowing(parts), false)
		end)

		T.Test("o interruptor geral tambem esconde", function()
			local display, parts = Build({ [Keys.ENABLED] = false })
			display:Refresh()

			T.Equals(IsShowing(parts), false)
		end)

		T.Test("segue o modo de exibicao proprio", function()
			local display, parts = Build({
				[Keys.HEALTH_VISIBILITY_MODE] = Addon.VisibilityModes.COMBAT,
			})
			parts.gameState.isInCombat = false

			display:Refresh()

			T.Equals(IsShowing(parts), false)
		end)

		--- O icone e a vida aparecem em momentos diferentes. Amarrar a vida ao
		--- modo do icone fazia a leitura sumir no instante em que a luta acabava,
		--- que e justamente quando ainda se quer conferir quanto sobrou.
		T.Test("o modo do icone nao esconde a vida", function()
			local display, parts = Build({
				[Keys.VISIBILITY_MODE] = Addon.VisibilityModes.COMBAT,
				[Keys.HEALTH_VISIBILITY_MODE] = Addon.VisibilityModes.ALWAYS,
			})
			parts.gameState.isInCombat = false

			display:Refresh()

			T.Equals(IsShowing(parts), true)
		end)

		T.Test("por padrao aparece fora de combate, so por ter alvo", function()
			local display, parts = Build()
			parts.gameState.isInCombat = false

			display:Refresh()

			T.Equals(IsShowing(parts), true)
		end)

		--- Diferente do icone: a vida nao espera magia nenhuma para aparecer.
		T.Test("aparece sem nenhuma magia ter sido lancada", function()
			local display, parts = Build()
			display:Refresh()

			T.Equals(IsShowing(parts), true)
		end)

		--- O valor da vida e classificado pelo cliente: compará-lo, medi-lo ou
		--- testá-lo como booleano derruba a execução. Aqui ele chega como algo
		--- que nem sequer é string, e o teste passa exatamente porque o Core se
		--- limita a repassá-lo. Se alguém voltar a escrever `text ~= ""` ou
		--- `#text`, esta suíte quebra antes do jogo.
		T.Test("o valor da vida atravessa sem ser tocado", function()
			local opaque = setmetatable({}, {
				__eq = function()
					error("o Core comparou o valor da vida")
				end,
				__len = function()
					error("o Core mediu o valor da vida")
				end,
			})

			local display, parts = Build(nil, { health = Support.HealthSource(opaque) })
			display:Refresh()

			T.Equals(IsShowing(parts), true)
			T.Equals(Only(parts).text, opaque, "chegou ao renderizador do jeito que saiu")
		end)

		--- O motivo desta camada existir: a vida aparece em tudo que tem placa,
		--- nao so' no que o jogador clicou.
		T.Test("desenha uma linha por nameplate na tela", function()
			local hosts = Support.Hosts("nameplate1")
			hosts.plates = {
				Support.Host("nameplate1"),
				Support.Host("nameplate2"),
				Support.Host("nameplate3"),
			}

			local display, parts = Build(nil, { hosts = hosts })
			display:Refresh()

			for _, unit in ipairs({ "nameplate1", "nameplate2", "nameplate3" }) do
				T.Equals(parts.pool.renderers[unit].shown, true, unit .. " ficou de fora")
			end
		end)

		T.Test("cada linha se prende ao frame da propria placa", function()
			local hosts = Support.Hosts("nameplate1")
			hosts.plates = { Support.Host("nameplate1"), Support.Host("nameplate2") }

			local display, parts = Build(nil, { hosts = hosts })
			display:Refresh()

			T.Equals(parts.pool.renderers.nameplate1.attachedTo, hosts.plates[1].frame)
			T.Equals(parts.pool.renderers.nameplate2.attachedTo, hosts.plates[2].frame)
		end)

		--- Uma placa que sai de cena nao avisa o renderizador dela. Sem esconder
		--- por omissao, a linha ficaria na tela e seguiria a proxima unidade que
		--- reaproveitasse aquela placa.
		T.Test("a placa que saiu de cena tem a linha escondida", function()
			local hosts = Support.Hosts("nameplate1")
			hosts.plates = { Support.Host("nameplate1"), Support.Host("nameplate2") }

			local display, parts = Build(nil, { hosts = hosts })
			display:Refresh()

			hosts.plates = { Support.Host("nameplate1") }
			display:Refresh()

			T.Equals(parts.pool.renderers.nameplate1.shown, true)
			T.Equals(parts.pool.renderers.nameplate2.shown, false)
		end)

		T.Test("a mesma placa reaproveita o renderizador dela", function()
			local display, parts = Build()

			display:Refresh()
			local first = parts.pool.renderers.nameplate1

			display:Refresh()

			T.Equals(parts.pool.renderers.nameplate1, first, "nao pode nascer um por refresh")
		end)

		--- A barra tem duas pontas: a porcentagem encosta na esquerda e o numero
		--- absoluto na direita. Concatenar as duas num texto so' desperdicaria
		--- a largura inteira do meio.
		T.Test("as duas partes chegam separadas ao renderizador", function()
			local display, parts = Build(nil, { health = Support.HealthSource("85%", "330k") })
			display:Refresh()

			T.Equals(Only(parts).reading.primary, "85%")
			T.Equals(Only(parts).reading.secondary, "330k")
		end)

		--- Ocupar a barra e' a unica leitura possivel de "dentro dela", e o
		--- renderizador precisa saber disso: medir a largura do nameplate e'
		--- proibido, entao ele estica ancorando as duas bordas.
		T.Test("dentro da barra a colocacao manda ocupar a largura dela", function()
			local display, parts = Build({ [Keys.HEALTH_ANCHOR_POINT] = "center" })
			display:Refresh()

			T.Equals(Only(parts).placement.spansHost, true)
		end)

		T.Test("fora da barra a colocacao continua sendo um ponto so", function()
			local display, parts = Build({ [Keys.HEALTH_ANCHOR_POINT] = "bottom" })
			display:Refresh()

			T.Equals(Only(parts).placement.spansHost, false)
		end)

		T.Test("fonte de vida sem resposta esconde em vez de escrever nada", function()
			local display, parts = Build(nil, { health = Support.HealthSource(nil) })
			display:Refresh()

			T.Equals(IsShowing(parts), false)
		end)

		T.Test("prende no frame do nameplate, com a ancora e o deslocamento dela", function()
			local display, parts = Build({
				[Keys.HEALTH_ANCHOR_POINT] = "left",
				[Keys.HEALTH_OFFSET_X] = -6,
			})
			display:Refresh()

			T.Equals(Only(parts).attachedTo, parts.hosts.host.frame)
			T.Equals(Only(parts).placement.point, "RIGHT")
			T.Equals(Only(parts).placement.relativePoint, "LEFT")
			T.Equals(Only(parts).placement.x, -6)
		end)

		--- Custou uma sessao inteira de depuracao: escrever num FontString que
		--- ainda nao tem fonte levanta "Font not set", o Refresh morre antes do
		--- SetShown e o texto nunca aparece — sempre, porque o SetFont que
		--- consertaria vinha depois e nunca era alcancado.
		T.Test("veste a fonte antes de escrever o texto", function()
			local display, parts = Build()
			display:Refresh()

			local fontAt, textAt

			for index, call in ipairs(Only(parts).calls) do
				fontAt = fontAt or (call == "SetFont" and index or nil)
				textAt = textAt or (call == "SetText" and index or nil)
			end

			T.IsTrue(fontAt ~= nil, "a fonte nunca foi definida")
			T.IsTrue(textAt ~= nil, "o texto nunca foi escrito")
			T.IsTrue(fontAt < textAt, "SetFont tem de vir antes de SetText")
		end)

		T.Test("usa o tamanho de fonte proprio e a fonte compartilhada", function()
			local display, parts = Build({
				[Keys.FONT_NAME] = "Inter",
				[Keys.HEALTH_FONT_SIZE] = 20,
				[Keys.FONT_SIZE] = 9,
			})
			display:Refresh()

			T.Equals(Only(parts).font.path, "Inter")
			T.Equals(Only(parts).font.size, 20, "o tamanho do icone nao vale aqui")
		end)

		T.Test("a cor vem do hexadecimal salvo", function()
			local display, parts = Build({ [Keys.HEALTH_COLOR] = "FF0000" })
			display:Refresh()

			T.Equals(Only(parts).appearance.color.red, 1)
			T.Equals(Only(parts).appearance.color.green, 0)
		end)

		T.Test("o teste escreve a amostra mesmo fora de combate", function()
			local display, parts = Build({ [Keys.VISIBILITY_MODE] = Addon.VisibilityModes.COMBAT })
			parts.gameState.isInCombat = false

			display:SetTesting({ primary = "85%", secondary = "330k" })

			T.Equals(IsShowing(parts), true)
			T.Equals(Only(parts).text, "85%")
			T.Equals(Only(parts).secondary, "330k")
		end)

		--- Ligar o teste nao pode ressuscitar uma linha que a pessoa desligou.
		T.Test("o teste respeita o interruptor de vida", function()
			local display, parts = Build({ [Keys.HEALTH_TEXT_ENABLED] = false })

			display:SetTesting({ primary = "85%", secondary = "330k" })

			T.Equals(IsShowing(parts), false)
		end)

		T.Test("encerrar o teste devolve o controle a leitura de verdade", function()
			local display, parts = Build()
			display:SetTesting({ primary = "85%", secondary = "330k" })

			display:SetTesting(nil)

			T.Equals(Only(parts).text, "85%")
		end)
	end)
end
