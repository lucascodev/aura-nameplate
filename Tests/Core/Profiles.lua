return function(Addon, T)
	local CHARACTER = "Lucas - Azralon"
	local OTHER_CHARACTER = "Outro - Azralon"

	T.Suite("Profiles", function()
		T.Test("banco vazio nasce com o perfil padrao", function()
			local database = {}
			local profiles = Addon.Profiles.New(database, CHARACTER)

			T.Equals(profiles:CurrentName(), "Default")
			T.IsTrue(database.profiles.Default ~= nil)
		end)

		T.Test("o perfil atual traz as tabelas que ele possui", function()
			local profile = Addon.Profiles.New({}, CHARACTER):Current()

			T.Equals(type(profile.settings), "table")
			T.Equals(type(profile.floatingPosition), "table")
			T.Equals(type(profile.minimapButton), "table")
		end)

		T.Test("perfil salvo por versao antiga ganha a tabela que faltava", function()
			local database = { profiles = { Default = { settings = { iconWidth = 60 } } }, characters = {} }
			local profile = Addon.Profiles.New(database, CHARACTER):Current()

			T.Equals(profile.settings.iconWidth, 60, "o que ja existia fica")
			T.Equals(type(profile.floatingPosition), "table")
		end)

		T.Test("cada personagem aponta para o proprio perfil", function()
			local database = {}
			local mine = Addon.Profiles.New(database, CHARACTER)
			mine:Create("PvP")
			mine:Select("PvP")

			local theirs = Addon.Profiles.New(database, OTHER_CHARACTER)

			T.Equals(mine:CurrentName(), "PvP")
			T.Equals(theirs:CurrentName(), "Default")
		end)

		T.Test("criar nao sobrescreve um perfil que ja existe", function()
			local database = {}
			local profiles = Addon.Profiles.New(database, CHARACTER)
			profiles:Select("PvP")
			profiles:Current().settings.iconWidth = 80

			profiles:Create("PvP")

			T.Equals(profiles:Current().settings.iconWidth, 80)
		end)

		T.Test("copiar leva os valores, e nao a mesma tabela", function()
			local profiles = Addon.Profiles.New({}, CHARACTER)
			profiles:Current().settings.iconWidth = 80

			profiles:CopyCurrentTo("Copia")
			profiles:Select("Copia")
			profiles:Current().settings.iconWidth = 20

			profiles:Select("Default")
			T.Equals(profiles:Current().settings.iconWidth, 80)
		end)

		T.Test("os nomes saem ordenados", function()
			local profiles = Addon.Profiles.New({}, CHARACTER)
			profiles:Create("PvP")
			profiles:Create("Alvorada")

			local names = profiles:Names()

			T.Equals(names[1], "Alvorada")
			T.Equals(names[2], "Default")
			T.Equals(names[3], "PvP")
		end)

		T.Test("o perfil em uso nao pode ser apagado", function()
			local profiles = Addon.Profiles.New({}, CHARACTER)

			T.Equals(profiles:Delete("Default"), false)
			T.IsTrue(profiles:Current() ~= nil)
		end)

		T.Test("apagar solta os personagens que apontavam para ele", function()
			local database = {}
			local mine = Addon.Profiles.New(database, CHARACTER)
			mine:Create("PvP")

			local theirs = Addon.Profiles.New(database, OTHER_CHARACTER)
			theirs:Select("PvP")

			T.Equals(mine:Delete("PvP"), true)
			T.Equals(theirs:CurrentName(), "Default")
		end)

		--- Um personagem apontando para um perfil que sumiu precisa de algum
		--- lugar para escrever, senao a primeira preferencia salva estoura.
		T.Test("personagem apontando para perfil inexistente ganha um novo", function()
			local database = { profiles = {}, characters = { [CHARACTER] = "Sumiu" } }
			local profile = Addon.Profiles.New(database, CHARACTER):Current()

			T.Equals(type(profile.settings), "table")
		end)
	end)
end
