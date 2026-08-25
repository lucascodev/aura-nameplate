return function(Addon, T)
	local Modes = Addon.VisibilityModes

	---@param overrides table?
	---@return boolean
	local function IsShown(overrides)
		local state = {
			isEnabled = true,
			mode = Modes.ALWAYS,
			hasCast = true,
			hasHost = true,
			hasTarget = true,
			isInCombat = true,
			isTesting = false,
		}

		for key, value in pairs(overrides or {}) do
			state[key] = value
		end

		return Addon.IconVisibility.IsShown(state)
	end

	T.Suite("IconVisibility", function()
		T.Test("com tudo no lugar, aparece", function()
			T.Equals(IsShown(), true)
		end)

		T.Test("desligado nao aparece", function()
			T.Equals(IsShown({ isEnabled = false }), false)
		end)

		T.Test("sem magia gravada nao aparece", function()
			T.Equals(IsShown({ hasCast = false }), false)
		end)

		T.Test("sem onde se pendurar nao aparece", function()
			T.Equals(IsShown({ hasHost = false }), false)
		end)

		T.Test("so em combate: fora dele, some", function()
			T.Equals(IsShown({ mode = Modes.COMBAT, isInCombat = false }), false)
			T.Equals(IsShown({ mode = Modes.COMBAT, isInCombat = true }), true)
		end)

		T.Test("so com alvo: sem alvo, some", function()
			T.Equals(IsShown({ mode = Modes.TARGET, hasTarget = false }), false)
			T.Equals(IsShown({ mode = Modes.TARGET, hasTarget = true }), true)
		end)

		T.Test("sempre ignora combate e alvo", function()
			T.Equals(IsShown({ mode = Modes.ALWAYS, isInCombat = false, hasTarget = false }), true)
		end)

		T.Test("modo desconhecido cai no sempre em vez de sumir", function()
			T.Equals(IsShown({ mode = "modo_que_nao_existe", isInCombat = false }), true)
		end)

		--- Quem digitou o comando de teste esta alinhando o icone: recusar por
		--- estar fora de combate, ou por nao ter lancado nada, so faria a pessoa
		--- achar que o addon nao funciona.
		T.Test("o teste passa por cima de desligado, sem magia e fora de combate", function()
			T.Equals(
				IsShown({
					isTesting = true,
					isEnabled = false,
					hasCast = false,
					mode = Modes.COMBAT,
					isInCombat = false,
					hasTarget = false,
				}),
				true
			)
		end)

		T.Test("nem o teste desenha sem onde se pendurar", function()
			T.Equals(IsShown({ isTesting = true, hasHost = false }), false)
		end)
	end)
end
