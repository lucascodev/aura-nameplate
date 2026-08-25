return function(Addon, T)
	local FirstRun = Addon.FirstRun

	T.Suite("FirstRun", function()
		T.Test("instalacao nova pede a apresentacao", function()
			T.Equals(FirstRun.New({}):ShouldGreet(), true)
		end)

		T.Test("dispensada, nao pede mais", function()
			local database = {}
			local firstRun = FirstRun.New(database)

			firstRun:Remember(true)

			T.Equals(firstRun:ShouldGreet(), false)
			T.Equals(firstRun:IsDismissed(), true)
		end)

		--- Desmarcar a caixa e' um pedido tao valido quanto marcar: a janela
		--- volta no proximo login em vez de sumir para sempre.
		T.Test("desmarcada de volta, pede outra vez", function()
			local database = {}
			local firstRun = FirstRun.New(database)

			firstRun:Remember(true)
			firstRun:Remember(false)

			T.Equals(firstRun:ShouldGreet(), true)
		end)

		--- A decisao mora na raiz, e nao no perfil ativo: quem cria um perfil de
		--- raide nao esta instalando o addon de novo.
		T.Test("a decisao fica na raiz do banco, fora dos perfis", function()
			local database = { profiles = {} }

			FirstRun.New(database):Remember(true)

			T.Equals(database.welcome.isDismissed, true)
			T.Equals(next(database.profiles), nil)
		end)

		T.Test("uma segunda leitura enxerga o que a primeira gravou", function()
			local database = {}

			FirstRun.New(database):Remember(true)

			T.Equals(FirstRun.New(database):ShouldGreet(), false)
		end)
	end)
end
