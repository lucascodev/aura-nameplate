local _, Addon = ...

--- The one place allowed to ask the client whether a value has been classified.
---
--- Values the game marks as secret cannot be compared, measured or used as a
--- table key: doing any of that raises a Lua error on the spot. Asking here
--- first is what turns "the game hid this" into an icon that simply does not
--- appear, instead of an error in the player's chat.
---@class Secrets
local Secrets = {}

--- The check arrived with the combat information restrictions. On a client
--- that predates it nothing is secret, and answering false is what keeps the
--- addon loading there instead of erroring at file scope.
local IsSecretValue = issecretvalue

---@param value any
---@return boolean
function Secrets.Is(value)
	if not IsSecretValue then
		return false
	end

	return IsSecretValue(value) == true
end

Addon.Secrets = Secrets
