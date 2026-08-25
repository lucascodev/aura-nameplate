local _, Addon = ...

--- The texture of a spell, when the client is willing to say.
---@class SpellIcon
local SpellIcon = {}

--- Stands in for a spell in test mode, where there is no cast to read.
SpellIcon.SAMPLE = [[Interface\Icons\Spell_Nature_TimeStop]]

--- Both the id and the texture it resolves to are checked: a spell can be
--- readable while its icon is not, and handing a secret to SetTexture is an
--- error, not a blank square.
---@param spellID any
---@return number?
function SpellIcon.For(spellID)
	if spellID == nil or Addon.Secrets.Is(spellID) then
		return nil
	end

	local info = C_Spell.GetSpellInfo(spellID)

	if not info or Addon.Secrets.Is(info.iconID) then
		return nil
	end

	return info.iconID
end

Addon.SpellIcon = SpellIcon
