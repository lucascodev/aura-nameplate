return function(Addon, T)
	local Layout = Addon.IconLayout
	local CLASS_COLOR = { red = 0.78, green = 0.61, blue = 0.43 }

	---@param overrides table?
	---@return table
	local function Settings(overrides)
		local settings = {
			width = 42,
			height = 42,
			alphaPercent = 100,
			borderThickness = 1,
			borderHex = "0A0A0A",
			showSwipe = true,
			showTimerText = true,
		}

		for key, value in pairs(overrides or {}) do
			settings[key] = value
		end

		return settings
	end

	T.Suite("IconLayout.Placement", function()
		T.Test("o lado escolhido vira o par de pontos", function()
			local placement = Layout.Placement("bottom", 0, 0)

			T.Equals(placement.point, "TOP")
			T.Equals(placement.relativePoint, "BOTTOM")
		end)

		T.Test("os deslocamentos passam sem serem tocados", function()
			local placement = Layout.Placement("top", -12, 30)

			T.Equals(placement.x, -12)
			T.Equals(placement.y, 30)
		end)
	end)

	T.Suite("IconLayout.Appearance", function()
		T.Test("a opacidade em porcentagem vira fracao", function()
			T.Near(Layout.Appearance(Settings({ alphaPercent = 60 })).alpha, 0.6, 0.001)
		end)

		T.Test("cheia e um, nao cem", function()
			T.Equals(Layout.Appearance(Settings()).alpha, 1)
		end)

		T.Test("a borda vem do hexadecimal salvo", function()
			local appearance = Layout.Appearance(Settings({ borderHex = "FF0000" }))

			T.Equals(appearance.borderColor.red, 1)
			T.Equals(appearance.borderColor.green, 0)
			T.Equals(appearance.borderColor.blue, 0)
		end)

		T.Test("tamanho e espessura chegam como foram salvos", function()
			local appearance = Layout.Appearance(
				Settings({ width = 64, height = 32, borderThickness = 3 })
			)

			T.Equals(appearance.width, 64)
			T.Equals(appearance.height, 32)
			T.Equals(appearance.borderThickness, 3)
		end)

		T.Test("os interruptores chegam ao renderizador como booleano, nunca como nil", function()
			local appearance = Layout.Appearance(
				Settings({ showSwipe = false, showTimerText = true }),
				CLASS_COLOR
			)

			T.Equals(appearance.showSwipe, false)
			T.Equals(appearance.showTimerText, true)
			T.Equals(type(appearance.showSwipe), "boolean")
		end)
	end)
end
