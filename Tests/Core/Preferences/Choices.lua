return function(Addon, T)
	---@param list PreferenceChoice[]
	---@param id string
	---@return boolean
	local function Has(list, id)
		for _, choice in ipairs(list) do
			if choice.id == id then
				return true
			end
		end

		return false
	end

	T.Suite("FontFlags", function()
		T.Test("nenhum vira string vazia, que e o que a fonte espera", function()
			T.Equals(Addon.FontFlags.Resolve("none"), "")
		end)

		T.Test("os demais passam adiante sem traducao", function()
			T.Equals(Addon.FontFlags.Resolve("OUTLINE"), "OUTLINE")
			T.Equals(Addon.FontFlags.Resolve("MONOCHROME,OUTLINE"), "MONOCHROME,OUTLINE")
		end)

		T.Test("a lista oferece a opcao nenhum", function()
			T.IsTrue(Has(Addon.FontFlags.Choices, "none"))
		end)
	end)

	T.Suite("AnchorPoints", function()
		T.Test("cada lado vira o par que poe o icone ao lado, nao por cima", function()
			T.Equals(Addon.AnchorPoints.Resolve("top").point, "BOTTOM")
			T.Equals(Addon.AnchorPoints.Resolve("top").relativePoint, "TOP")
			T.Equals(Addon.AnchorPoints.Resolve("left").point, "RIGHT")
			T.Equals(Addon.AnchorPoints.Resolve("left").relativePoint, "LEFT")
		end)

		T.Test("o centro e o unico que casa ponto com ponto", function()
			local center = Addon.AnchorPoints.Resolve("center")

			T.Equals(center.point, "CENTER")
			T.Equals(center.relativePoint, "CENTER")
		end)

		T.Test("id salvo por uma versao que oferecia outro lado nao derruba o layout", function()
			local fallback = Addon.AnchorPoints.Resolve("lado_que_nao_existe")

			T.Equals(fallback.point, "BOTTOM")
			T.Equals(fallback.relativePoint, "TOP")
		end)

		--- Uma fileira de auras cresce de lado conforme icones entram. Presa pelo
		--- centro, cada aura nova empurraria a fileira inteira; presa por uma
		--- borda, ela cresce a partir dali e o que ja' estava fica parado.
		T.Test("a variante por borda prende num canto, nao no meio", function()
			local below = Addon.AnchorPoints.ResolveTrailing("bottom")

			T.Equals(below.point, "TOPRIGHT")
			T.Equals(below.relativePoint, "BOTTOMRIGHT")
		end)

		T.Test("id desconhecido na variante por borda cai em abaixo", function()
			local fallback = Addon.AnchorPoints.ResolveTrailing("lado_que_nao_existe")

			T.Equals(fallback.point, "TOPRIGHT")
		end)

		T.Test("toda opcao da lista tem as duas geometrias declaradas", function()
			for _, choice in ipairs(Addon.AnchorPoints.Choices) do
				local trailing = Addon.AnchorPoints.ResolveTrailing(choice.id)

				T.IsTrue(type(trailing.point) == "string", choice.id .. " sem ponto por borda")
			end
		end)

		T.Test("toda opcao da lista tem geometria declarada", function()
			for _, choice in ipairs(Addon.AnchorPoints.Choices) do
				local anchor = Addon.AnchorPoints.Resolve(choice.id)

				T.IsTrue(type(anchor.point) == "string", choice.id .. " sem ponto")
				T.IsTrue(type(anchor.relativePoint) == "string", choice.id .. " sem ponto relativo")
			end
		end)
	end)

	T.Suite("HealthFormats", function()
		T.Test("os tres formatos estao na lista", function()
			local formats = Addon.HealthFormats

			T.IsTrue(Has(formats.Choices, formats.PERCENT))
			T.IsTrue(Has(formats.Choices, formats.ABBREVIATED))
			T.IsTrue(Has(formats.Choices, formats.BOTH))
		end)
	end)

	T.Suite("AuraFilters", function()
		--- O id e' a string que o cliente entende, e nao um apelido nosso: quem
		--- monta a fileira repassa sem traduzir. Um apelido aqui exigiria um
		--- mapa la' adiante, e dois lugares para errar.
		T.Test("o id e o proprio filtro do cliente", function()
			T.Equals(Addon.AuraFilters.OWN_DEBUFFS, "HARMFUL|PLAYER")
			T.Equals(Addon.AuraFilters.ALL_BUFFS, "HELPFUL")
		end)

		T.Test("os quatro filtros estao na lista", function()
			local filters = Addon.AuraFilters

			T.IsTrue(Has(filters.Choices, filters.OWN_DEBUFFS))
			T.IsTrue(Has(filters.Choices, filters.ALL_DEBUFFS))
			T.IsTrue(Has(filters.Choices, filters.OWN_BUFFS))
			T.IsTrue(Has(filters.Choices, filters.ALL_BUFFS))
		end)
	end)

	T.Suite("VisibilityModes", function()
		T.Test("os tres modos estao na lista", function()
			local modes = Addon.VisibilityModes

			T.IsTrue(Has(modes.Choices, modes.ALWAYS))
			T.IsTrue(Has(modes.Choices, modes.COMBAT))
			T.IsTrue(Has(modes.Choices, modes.TARGET))
		end)
	end)
end
