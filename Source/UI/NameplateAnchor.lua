local _, Addon = ...

local Keys = Addon.PreferenceKeys
local TARGET = "target"
local PLAYER = "player"

--- Decides what the icon hangs from: the nameplate of the unit being followed,
--- the free-floating spot, or nothing.
---
--- HostSource port. Keeping the three answers behind one call is what lets the
--- display ask a single question instead of learning about targets, plates and
--- fallbacks in turn.
---
--- Answering also puts the free spot in step: it is sized and made grabbable
--- exactly when it is the one carrying the icon. Splitting that out would mean
--- a second call every caller had to remember to make.
---@class NameplateAnchor : HostSource
---@field private preferences Preferences
---@field private floating FloatingAnchor
---@field private tracker NameplateTracker
---@field private isForced boolean
local NameplateAnchor = {}
NameplateAnchor.__index = NameplateAnchor

---@param preferences Preferences
---@param floating FloatingAnchor
---@param tracker NameplateTracker
---@return NameplateAnchor
function NameplateAnchor.New(preferences, floating, tracker)
	return setmetatable({
		preferences = preferences,
		floating = floating,
		tracker = tracker,
		isForced = false,
	}, NameplateAnchor)
end

--- Test mode needs somewhere to draw even with nothing targeted, without
--- turning the player's fallback preference on behind their back.
---@param isForced boolean
function NameplateAnchor:ForceFloating(isForced)
	self.isForced = isForced
end

--- Every plate on screen that this addon is allowed to draw on.
---@return NameplateHost[]
function NameplateAnchor:Nameplates()
	local allowed = {}

	for _, host in ipairs(self.tracker:Hosts()) do
		if self:AllowsUnit(host.unit) then
			table.insert(allowed, host)
		end
	end

	return allowed
end

--- Whether a unit may carry anything at all.
---
--- Quem é, e não o que dá para fazer com ele agora. `UnitCanAttack` respondia a
--- outra pergunta: dentro de uma capital ninguém é atacável, e o filtro apagava
--- o addon em placas de inimigos de verdade junto com as dos aliados. Quem é
--- aliado continua aliado dentro da cidade, e é isso que a opção promete.
---
--- The client can classify who a unit is, and then it cannot say whether they
--- are an enemy. Refusing to draw on the strength of an answer that was never
--- given would make the icon vanish exactly where it matters most, so an
--- unanswered question counts as yes.
---@private
---@param unit string
---@return boolean
function NameplateAnchor:AllowsUnit(unit)
	-- A propria placa so existe porque o jogador a ligou; recusa-la por
	-- "aliado" seria vetar exatamente o que ele pediu. Ela recebe o mesmo
	-- tratamento das placas inimigas: vida escrita, nas mesmas opcoes.
	local isSelf = UnitIsUnit(unit, PLAYER)

	if not Addon.Secrets.Is(isSelf) and isSelf == true then
		return true
	end

	if self.preferences:Get(Keys.SHOW_ON_FRIENDLY) then
		return true
	end

	local isFriend = UnitIsFriend(PLAYER, unit)

	if Addon.Secrets.Is(isFriend) then
		return true
	end

	return isFriend ~= true
end

--- The target's plate, or nothing. Never the free spot: a caller asking for a
--- nameplate wants the unit behind it, and the free spot has none.
---
--- Asking the client for the plate of "target" is the direct route, and it
--- stopped answering: the tokens those APIs accept were narrowed. So when it
--- comes back empty the plates already being tracked are searched instead —
--- they arrived by event, keyed by their own token, and one of them is the
--- target.
---@return NameplateHost?
function NameplateAnchor:Nameplate()
	if not UnitExists(TARGET) or not self:AllowsUnit(TARGET) then
		return nil
	end

	local direct = Addon.NameplateRegistry.ForUnit(TARGET)

	if direct then
		return direct
	end

	for _, host in ipairs(self.tracker:Hosts()) do
		if Addon.NameplateRegistry.IsSameUnit(host.unit, TARGET) then
			return host
		end
	end

	return nil
end

---@return NameplateHost?
function NameplateAnchor:Current()
	local plate = self:Nameplate()

	-- The free spot is only grabbable while it is the one holding the icon:
	-- leaving it on screen beside a nameplate that already has the icon just
	-- gives the player two things to aim at.
	if plate then
		self.floating:SetEditable(false)
		return plate
	end

	if not self.isForced and not self.preferences:Get(Keys.FLOATING_FALLBACK) then
		self.floating:SetEditable(false)
		return nil
	end

	self.floating:SetSize(
		self.preferences:Get(Keys.ICON_WIDTH),
		self.preferences:Get(Keys.ICON_HEIGHT)
	)
	self.floating:SetEditable(self.isForced)

	return self.floating:Host()
end

Addon.NameplateAnchor = NameplateAnchor
