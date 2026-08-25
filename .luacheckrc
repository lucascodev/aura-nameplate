std = "lua51"
max_line_length = false

exclude_files = {
	"Libs/",
	"dist/",
	"Tests/",
}

ignore = {
	-- Mixins e objetos recebem self sem sempre usar.
	"212/self",
}

-- Written by the addon: the saved variables table, the binding strings the
-- client reads, and the two handlers Bindings.xml calls.
globals = {
	"AuraNameplateDB",
	"AuraNameplate_OpenOptions",
	"AuraNameplate_Toggle",
	"BINDING_HEADER_AURANAMEPLATE",
	"BINDING_NAME_AURANAMEPLATE_OPTIONS",
	"BINDING_NAME_AURANAMEPLATE_TOGGLE",
	"SlashCmdList",
	"StaticPopupDialogs",
}

-- Read from the game.
read_globals = {
	"ACCEPT",
	"AbbreviateNumbers",
	"AnchorUtil",
	"AuraContainerSortDirection",
	"AuraContainerSortMethod",
	"_G",
	"C_AddOns",
	"C_NamePlate",
	"C_Spell",
	"C_XMLUtil",
	"C_Timer",
	"CANCEL",
	"ColorPickerFrame",
	"CreateFont",
	"CreateColor",
	"CreateFrame",
	"CurveConstants",
	"DEFAULT_CHAT_FRAME",
	"GameFontNormal",
	"GetLocale",
	"GetRealmName",
	"GetTime",
	"InCombatLockdown",
	"IsLoggedIn",
	"LibStub",
	"MinimalSliderWithSteppersMixin",
	"NO",
	"RAID_CLASS_COLORS",
	"ReloadUI",
	"STANDARD_TEXT_FONT",
	"Settings",
	"StaticPopup_Show",
	"UIParent",
	"UnitCanAttack",
	"UnitClass",
	"UnitExists",
	"UnitIsUnit",
	"UnitHealth",
	"UnitHealthPercent",
	"UnitName",
	"YES",
	"issecretvalue",
	"strtrim",
}
