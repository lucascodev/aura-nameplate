--- Fakes e construtores compartilhados pelas suítes.
---
--- Todos são tabelas simples: o Core recebe colaboradores por injeção, então
--- não há framework de mock envolvido.

local Support = {}

---@param overrides table?
---@return CastEvent
function Support.Cast(overrides)
	local cast = {
		slot = "player",
		iconID = 135808,
		castAt = 0,
	}

	for key, value in pairs(overrides or {}) do
		cast[key] = value
	end

	return cast
end

--- Logger que guarda o que recebeu, para o teste conferir o aviso.
---@return table
function Support.Logger()
	return {
		infos = {},
		warnings = {},
		Info = function(self, message)
			table.insert(self.infos, message)
		end,
		Warn = function(self, message)
			table.insert(self.warnings, message)
		end,
	}
end

--- IconRenderer que anota o que foi pedido, sem desenhar nada.
---@return table
function Support.Renderer()
	return {
		shown = nil,
		iconID = nil,
		reading = nil,
		appearance = nil,
		font = nil,
		attachedTo = nil,
		placement = nil,
		SetIcon = function(self, iconID, spellID)
			self.iconID = iconID
			self.spellID = spellID
		end,
		SetCooldown = function(self, reading)
			self.reading = reading
		end,
		SetAppearance = function(self, appearance)
			self.appearance = appearance
		end,
		SetFont = function(self, path, size, flag)
			self.font = { path = path, size = size, flag = flag }
		end,
		Attach = function(self, host, placement)
			self.attachedTo = host
			self.placement = placement
		end,
		SetShown = function(self, isShown)
			self.shown = isShown
		end,
	}
end

--- TextRenderer que anota o que foi pedido, sem desenhar nada.
---@return table
function Support.TextRenderer()
	return {
		shown = nil,
		text = nil,
		appearance = nil,
		font = nil,
		attachedTo = nil,
		placement = nil,
		--- A ordem importa: um FontString sem fonte estoura ao receber texto.
		calls = {},
		SetText = function(self, reading)
			table.insert(self.calls, "SetText")
			self.reading = reading
			self.text = reading.primary
			self.secondary = reading.secondary
		end,
		SetAppearance = function(self, appearance)
			table.insert(self.calls, "SetAppearance")
			self.appearance = appearance
		end,
		SetFont = function(self, path, size, flag)
			table.insert(self.calls, "SetFont")
			self.font = { path = path, size = size, flag = flag }
		end,
		Attach = function(self, host, placement)
			self.attachedTo = host
			self.placement = placement
		end,
		SetShown = function(self, isShown)
			self.shown = isShown
		end,
	}
end

--- HealthSource que devolve o que recebeu, para o teste ver a unidade e o
--- formato que chegaram sem precisar do cliente.
---@param text any?
---@param secondary string?
---@return table
function Support.HealthSource(text, secondary)
	local source = { calls = {} }

	function source.Text(unit, format)
		table.insert(source.calls, { unit = unit, format = format })

		if text == nil then
			return nil
		end

		return { primary = text, secondary = secondary }
	end

	return source
end

--- HostSource sobre um host fixo. O campo fica exposto para um teste conseguir
--- tirar o nameplate do ar no meio do caminho.
---@param unit string?
---@return table
function Support.Hosts(unit)
	local hosts = { host = unit and { frame = { name = "frame" }, unit = unit } or nil }

	function hosts:Current()
		return self.host
	end

	--- O mesmo host, por padrao. Um teste que precise separar o nameplate da
	--- posicao livre sobrescreve este campo.
	hosts.nameplate = hosts.host

	function hosts:Nameplate()
		return self.nameplate
	end

	--- A lista ampla: por padrao a mesma placa unica, para o caso comum. Um
	--- teste que queira varias sobrescreve o campo.
	hosts.plates = hosts.host and { hosts.host } or {}

	function hosts:Nameplates()
		return self.plates
	end

	return hosts
end

--- Constroi um host de nameplate avulso, para os testes de varias placas.
---@param unit string
---@return NameplateHost
function Support.Host(unit)
	return { frame = { name = unit }, unit = unit }
end

--- TextRendererPool que entrega um TextRenderer por unidade e guarda todos,
--- para o teste conferir quem foi desenhado e quem foi escondido.
---@return table
function Support.RendererPool()
	local pool = { renderers = {}, hidden = {} }

	function pool:Acquire(unit)
		self.renderers[unit] = self.renderers[unit] or Support.TextRenderer()

		return self.renderers[unit]
	end

	function pool:HideOthers(kept)
		for unit, renderer in pairs(self.renderers) do
			if not kept[unit] then
				renderer:SetShown(false)
				self.hidden[unit] = true
			end
		end
	end

	--- Atalho para o caso de uma placa so'.
	---@return table?
	function pool:Only()
		for _, renderer in pairs(self.renderers) do
			return renderer
		end

		return nil
	end

	return pool
end

--- CooldownSource que devolve sempre a mesma leitura.
---@param reading table?
---@return table
function Support.Cooldowns(reading)
	return {
		Read = function()
			return reading or { start = 0, duration = 1.5 }
		end,
	}
end

--- AppearanceSources que devolve o nome recebido, para o teste ver o que
--- chegou sem precisar de acervo de mídia.
---@return AppearanceSources
function Support.AppearanceSources()
	return {
		Font = function(name)
			return name
		end,
	}
end

--- O estado fica em campos, e não preso na chamada, para um teste conseguir
--- entrar em combate ou perder o alvo no meio do caminho.
---@param overrides table?
---@return table
function Support.GameState(overrides)
	local state = { hasTarget = true, isInCombat = true, now = 0 }

	for key, value in pairs(overrides or {}) do
		state[key] = value
	end

	function state.HasTarget()
		return state.hasTarget
	end

	function state.IsInCombat()
		return state.isInCombat
	end

	function state.Now()
		return state.now
	end

	return state
end

return Support
