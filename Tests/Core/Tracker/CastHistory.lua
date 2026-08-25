return function(Addon, T, Support)
	local PLAYER = Addon.CastHistory.PLAYER_SLOT

	---@param hold number
	---@return CastHistory
	local function History(hold)
		return Addon.CastHistory.New(function()
			return hold
		end)
	end

	T.Suite("CastHistory", function()
		T.Test("devolve o que foi gravado no slot", function()
			local history = History(5)
			history:Record(Support.Cast({ iconID = 100, castAt = 0 }))

			T.Equals(history:Newest({ PLAYER }, 1).iconID, 100)
		end)

		T.Test("slot sem nada devolve nil", function()
			T.Equals(History(5):Newest({ PLAYER }, 0), nil)
		end)

		T.Test("uma gravacao nova cobre a anterior do mesmo slot", function()
			local history = History(5)
			history:Record(Support.Cast({ iconID = 100, castAt = 0 }))
			history:Record(Support.Cast({ iconID = 200, castAt = 1 }))

			T.Equals(history:Newest({ PLAYER }, 1).iconID, 200)
		end)

		T.Test("passado o tempo de retencao, some", function()
			local history = History(4)
			history:Record(Support.Cast({ castAt = 0 }))

			T.IsTrue(history:Newest({ PLAYER }, 3.9) ~= nil)
			T.Equals(history:Newest({ PLAYER }, 4), nil, "o limite ja esta fora")
		end)

		T.Test("o tempo de retencao e lido a cada pergunta, nao na criacao", function()
			local hold = 2
			local history = Addon.CastHistory.New(function()
				return hold
			end)
			history:Record(Support.Cast({ castAt = 0 }))

			T.Equals(history:Newest({ PLAYER }, 3), nil)

			hold = 10
			history:Record(Support.Cast({ castAt = 0 }))
			T.IsTrue(history:Newest({ PLAYER }, 3) ~= nil)
		end)

		T.Test("entre varios slots vence o mais recente", function()
			local history = History(10)
			history:Record(Support.Cast({ slot = PLAYER, iconID = 100, castAt = 1 }))
			history:Record(Support.Cast({ slot = "nameplate1", iconID = 200, castAt = 2 }))

			T.Equals(history:Newest({ PLAYER, "nameplate1" }, 3).iconID, 200)
		end)

		T.Test("slot fora da pergunta nao concorre", function()
			local history = History(10)
			history:Record(Support.Cast({ slot = PLAYER, iconID = 100, castAt = 1 }))
			history:Record(Support.Cast({ slot = "nameplate1", iconID = 200, castAt = 2 }))

			T.Equals(history:Newest({ PLAYER }, 3).iconID, 100)
		end)

		T.Test("o vencido por expiracao nao segura o lugar do valido", function()
			local history = History(4)
			history:Record(Support.Cast({ slot = "nameplate1", iconID = 200, castAt = 0 }))
			history:Record(Support.Cast({ slot = PLAYER, iconID = 100, castAt = 3 }))

			T.Equals(history:Newest({ PLAYER, "nameplate1" }, 5).iconID, 100)
		end)

		T.Test("o expirado e descartado, e nao volta se o tempo de retencao crescer", function()
			local hold = 2
			local history = Addon.CastHistory.New(function()
				return hold
			end)
			history:Record(Support.Cast({ castAt = 0 }))
			history:Newest({ PLAYER }, 5)

			hold = 60
			T.Equals(history:Newest({ PLAYER }, 5), nil)
		end)

		T.Test("esquecer um slot nao mexe nos outros", function()
			local history = History(10)
			history:Record(Support.Cast({ slot = PLAYER, castAt = 0 }))
			history:Record(Support.Cast({ slot = "nameplate1", castAt = 0 }))

			history:Forget("nameplate1")

			T.Equals(history:Newest({ "nameplate1" }, 1), nil)
			T.IsTrue(history:Newest({ PLAYER }, 1) ~= nil)
		end)

		T.Test("limpar tira tudo", function()
			local history = History(10)
			history:Record(Support.Cast({ castAt = 0 }))
			history:Wipe()

			T.Equals(history:Newest({ PLAYER }, 1), nil)
		end)
	end)
end
