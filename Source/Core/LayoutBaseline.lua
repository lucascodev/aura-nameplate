local _, Addon = ...

local Keys = Addon.PreferenceKeys

--- Um layout de fábrica que já foi publicado uma vez.
---
--- Enquanto o addon ainda está sendo desenhado, mudar um padrão não alcança
--- quem já tem perfil salvo: o valor antigo continua gravado e só sai com um
--- "Padrões" manual — clicado na hora certa, depois de recarregar o código
--- novo. Quem clica antes pega o padrão anterior e perde o próprio ajuste.
---
--- A versão resolve isso: quando o número aqui sobe, as chaves de layout
--- voltam ao padrão uma única vez, e o perfil passa a carregar o número novo.
--- Nada disso é silencioso — quem aplica avisa no chat.
---@class LayoutBaseline
local LayoutBaseline = {}

--- Sobe de um sempre que os padrões de posicionamento mudarem de propósito.
LayoutBaseline.VERSION = 2

--- Só o que posiciona, dimensiona ou veste. Preferências de comportamento
--- ficam de fora: elas são escolha de jogo, não de arranjo na tela.
LayoutBaseline.KEYS = {
	Keys.ANCHOR_POINT,
	Keys.OFFSET_X,
	Keys.OFFSET_Y,
	Keys.ICON_WIDTH,
	Keys.ICON_HEIGHT,
	Keys.HEALTH_ANCHOR_POINT,
	Keys.HEALTH_OFFSET_X,
	Keys.HEALTH_OFFSET_Y,
	Keys.HEALTH_FONT_SIZE,
	Keys.HEALTH_TEXT_FORMAT,
	Keys.NAME_ABOVE_BAR,
	Keys.NAME_BACKDROP,
	Keys.NAME_BACKDROP_OPACITY,
	Keys.NAME_BACKDROP_HEIGHT,
	Keys.OWN_AURAS,
	Keys.AURA_ANCHOR_POINT,
	Keys.AURA_OFFSET_X,
	Keys.AURA_OFFSET_Y,
	Keys.AURA_FILTER,
	Keys.AURA_ICON_SIZE,
	Keys.AURA_ICON_SPACING,
	Keys.AURA_MAX_COUNT,
}

---@param storedVersion number?
---@return boolean
function LayoutBaseline.IsOutdated(storedVersion)
	return (tonumber(storedVersion) or 0) < LayoutBaseline.VERSION
end

--- Devolve o layout ao padrão e carimba o perfil, de uma vez só. Devolve se
--- houve mudança, para quem chamou poder contar ao jogador.
---@param preferences Preferences
---@param profile table
---@return boolean hasApplied
function LayoutBaseline.Apply(preferences, profile)
	if not LayoutBaseline.IsOutdated(profile.layoutVersion) then
		return false
	end

	preferences:Reset(LayoutBaseline.KEYS)
	profile.layoutVersion = LayoutBaseline.VERSION

	return true
end

Addon.LayoutBaseline = LayoutBaseline
