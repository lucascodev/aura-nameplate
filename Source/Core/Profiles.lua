local _, Addon = ...

--- Fixed on purpose: it is a SavedVariables key, and translating it would make
--- the profile disappear when the player changed the client language.
local DEFAULT_NAME = "Default"

--- Tables a profile owns besides its settings. Named here so creation and
--- completion cannot drift apart.
local PROFILE_TABLES = {
	"floatingPosition",
	"minimapButton",
	"windowPositions",
}

--- Named sets of settings, with one active per character.
---
--- Holds the raw SavedVariables table and nothing else, no game API, so the
--- whole thing is testable outside the client.
---@class Profiles
---@field private database table
---@field private characterKey string
local Profiles = {}
Profiles.__index = Profiles

---@return table
local function NewProfile()
	local profile = { settings = {} }

	for _, name in ipairs(PROFILE_TABLES) do
		profile[name] = {}
	end

	return profile
end

---@param database table The SavedVariables root.
---@param characterKey string
---@return Profiles
function Profiles.New(database, characterKey)
	database.profiles = database.profiles or { [DEFAULT_NAME] = NewProfile() }
	database.characters = database.characters or {}

	return setmetatable({
		database = database,
		characterKey = characterKey,
	}, Profiles)
end

---@return string
function Profiles:CurrentName()
	return self.database.characters[self.characterKey] or DEFAULT_NAME
end

--- A profile saved by an earlier version may be missing a table added later:
--- it starts empty on first read, without touching what was already there.
---@param profile table
local function Complete(profile)
	profile.settings = profile.settings or {}

	for _, name in ipairs(PROFILE_TABLES) do
		if type(profile[name]) ~= "table" then
			profile[name] = {}
		end
	end
end

--- The active profile, created on demand so a character pointed at a deleted
--- profile still gets somewhere to write instead of erroring.
---@return table
function Profiles:Current()
	local name = self:CurrentName()

	if not self.database.profiles[name] then
		self.database.profiles[name] = NewProfile()
	end

	Complete(self.database.profiles[name])

	return self.database.profiles[name]
end

---@return string[]
function Profiles:Names()
	local names = {}

	for name in pairs(self.database.profiles) do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

---@param name string
function Profiles:Select(name)
	self.database.characters[self.characterKey] = name
end

--- A new profile starts empty, which means every preference falls back to its
--- default, the same state a fresh install has.
---@param name string
function Profiles:Create(name)
	if self.database.profiles[name] then
		return
	end

	self.database.profiles[name] = NewProfile()
end

---@param source table
---@return table
local function DeepCopy(source)
	local copy = {}

	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and DeepCopy(value) or value
	end

	return copy
end

---@param name string
function Profiles:CopyCurrentTo(name)
	self.database.profiles[name] = DeepCopy(self:Current())
end

--- The active profile is never removed: a character must always have somewhere
--- to write, and deleting what you are standing on is a trap.
---@param name string
---@return boolean removed
function Profiles:Delete(name)
	if name == self:CurrentName() then
		return false
	end

	self.database.profiles[name] = nil

	for characterKey, profileName in pairs(self.database.characters) do
		if profileName == name then
			self.database.characters[characterKey] = nil
		end
	end

	return true
end

Addon.Profiles = Profiles
