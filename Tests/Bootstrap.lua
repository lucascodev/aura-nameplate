return function(_, T, _, Harness)
	local ADDON_NAME = "AuraNameplate"
	local ClientStub = dofile("Tests/ClientStub.lua")

	--- Carrega todo arquivo que o jogo carrega, na ordem do .toc, e devolve o
	--- frame que espera pelo ADDON_LOADED.
	---@param client table
	---@return table? loader
	local function LoadEverything(client)
		local addon = {}

		for _, path in ipairs(Harness.RuntimeFiles()) do
			local chunk = assert(loadfile(path), path)

			chunk(ADDON_NAME, addon)
		end

		for _, frame in ipairs(client.frames) do
			if frame.events.ADDON_LOADED and frame.scripts.OnEvent then
				return frame
			end
		end

		return nil
	end

	T.Suite("Bootstrap", function()
		--- O composition root é o único arquivo que conhece todo mundo, e é onde
		--- uma ordem de linhas errada aparece: uma preferência que muda durante a
		--- montagem dispara um redesenho que encontra metade dos objetos ainda
		--- nil. Nenhum teste de unidade alcança isso — só montar de verdade.
		T.Test("monta e inicia sem estourar", function()
			_G.AuraNameplateDB = {}

			local client = ClientStub.Install()
			local loader = LoadEverything(client)

			T.IsTrue(loader ~= nil, "nenhum frame esperando por ADDON_LOADED")

			local built, failure = pcall(loader.scripts.OnEvent, loader, "ADDON_LOADED", ADDON_NAME)
			T.IsTrue(built, "Build() estourou: " .. tostring(failure))

			local started, startFailure = pcall(loader.scripts.OnEvent, loader, "PLAYER_LOGIN")
			T.IsTrue(started, "Start() estourou: " .. tostring(startFailure))
		end)

		--- O baseline de layout reescreve preferências durante a montagem, que é
		--- exatamente o instante em que os objetos de desenho ainda não existem.
		T.Test("um layout desatualizado nao derruba a montagem", function()
			_G.AuraNameplateDB = {
				profiles = {
					Default = {
						settings = { anchorPoint = "top", offsetX = 99 },
						floatingPosition = {},
						minimapButton = {},
					},
				},
				characters = {},
			}

			local client = ClientStub.Install()
			local loader = LoadEverything(client)
			local built, failure = pcall(loader.scripts.OnEvent, loader, "ADDON_LOADED", ADDON_NAME)

			T.IsTrue(built, "Build() estourou com perfil antigo: " .. tostring(failure))

			local settings = _G.AuraNameplateDB.profiles.Default.settings
			T.Equals(settings.anchorPoint, "left", "o baseline devia ter reposicionado o icone")
			T.Equals(settings.offsetX, -7)
		end)
	end)
end
