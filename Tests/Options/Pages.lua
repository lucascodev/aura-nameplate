return function(Addon, T)
	local PAGE_FILES = {
		appearance = "Source/Options/AppearancePanel.lua",
		behaviour = "Source/Options/BehaviourPanel.lua",
		health = "Source/Options/HealthPanel.lua",
		plates = "Source/Options/PlatesPanel.lua",
		windows = "Source/Options/WindowsPanel.lua",
	}

	---@param path string
	---@return string
	local function Source(path)
		local file = assert(io.open(path, "r"))
		local text = file:read("*a")
		file:close()

		return text
	end

	---@param key string
	---@return string constant
	local function ConstantFor(key)
		for constant, value in pairs(Addon.PreferenceKeys) do
			if value == key then
				return constant
			end
		end

		error(key .. " sem constante em PreferenceKeys")
	end

	T.Suite("OptionsPages", function()
		T.Test("toda preferencia com painel aparece exatamente na pagina dela", function()
			local sources = {}

			for panel, path in pairs(PAGE_FILES) do
				sources[panel] = Source(path)
			end

			for _, preference in ipairs(Addon.PreferenceCatalog) do
				if preference.panel then
					local constant = ConstantFor(preference.key)
					local pattern = "Keys%." .. constant .. "%f[%W]"

					T.IsTrue(
						sources[preference.panel] ~= nil,
						preference.key .. " aponta para painel desconhecido " .. tostring(preference.panel)
					)

					for panel, source in pairs(sources) do
						local isHome = panel == preference.panel
						local isThere = source:find(pattern) ~= nil

						T.IsTrue(
							isThere == isHome,
							("%s deveria morar so em %s"):format(preference.key, preference.panel)
						)
					end
				end
			end
		end)

		T.Test("preferencia sem painel e raiz booleana", function()
			for _, preference in ipairs(Addon.PreferenceLookup.Roots(Addon.PreferenceCatalog)) do
				T.Equals(preference.kind, "boolean", preference.key)
			end
		end)
	end)
end
