return function(_, T, _, Harness)
	--- Ports/ guarda so contratos de tipo, lidos pelo language server: nada no
	--- .toc os carrega, e o empacotador os descarta.
	local NOT_SHIPPED = "^Source/Ports/"

	--- A suite roda no CI, em Linux, e na maquina de quem escreve, em Windows.
	--- Nenhum dos dois lista diretorio pelo Lua padrao, entao cada um responde
	--- com o comando que tem, e a saida e normalizada logo em seguida.
	local IS_WINDOWS = package.config:sub(1, 1) == "\\"

	---@return string
	local function ListCommand()
		if IS_WINDOWS then
			return "dir /b /s Source\\*.lua Locales\\*.lua"
		end

		return 'find Source Locales -name "*.lua" -type f'
	end

	--- O dir do Windows responde com caminho absoluto; o find, com relativo.
	---@param line string
	---@return string?
	local function Relative(line)
		local path = line:gsub("\\", "/"):gsub("^%./", "")

		return path:match("(Source/.*)$") or path:match("(Locales/.*)$")
	end

	---@return string[]
	local function WrittenFiles()
		local paths = {}
		local listing = assert(io.popen(ListCommand()))

		for line in listing:lines() do
			local path = Relative(line)

			if path and not path:match(NOT_SHIPPED) then
				table.insert(paths, path)
			end
		end

		listing:close()

		return paths
	end

	---@param paths string[]
	---@return table<string, boolean>
	local function AsSet(paths)
		local set = {}

		for _, path in ipairs(paths) do
			set[path] = true
		end

		return set
	end

	T.Suite("Package", function()
		local listed = Harness.RuntimeFiles()

		--- Um arquivo no .toc que nao existe no disco quebra a carga no cliente
		--- do jogador, sem nenhuma pista do motivo.
		T.Test("todo arquivo do .toc existe no disco", function()
			for _, path in ipairs(listed) do
				local file = io.open(path, "r")

				T.IsTrue(file ~= nil, path .. " esta no .toc e nao existe")

				if file then
					file:close()
				end
			end
		end)

		--- E o contrario: um arquivo escrito e nunca registrado simplesmente
		--- nao carrega, o que parece um recurso que nunca foi escrito.
		T.Test("todo arquivo escrito esta no .toc", function()
			local inToc = AsSet(listed)

			for _, path in ipairs(WrittenFiles()) do
				T.IsTrue(inToc[path], path .. " foi escrito e nao esta no .toc")
			end
		end)

		T.Test("nenhum arquivo aparece duas vezes no .toc", function()
			local seen = {}

			for _, path in ipairs(listed) do
				T.IsTrue(not seen[path], path .. " esta listado duas vezes")
				seen[path] = true
			end
		end)
	end)
end
