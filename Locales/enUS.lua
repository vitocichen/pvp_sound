---@type string, Addon
local _, addon = ...
local L = addon.L

L:SetDefaultStrings({
	-- General / Home
	["addon_description"] = "A PvP TTS addon that announces defensive cooldowns, important buff abilities, and crowd control spells during PvP combat.",
	["Author: DK-姜世离（燃烧之刃）"] = "Author: DK-姜世离（燃烧之刃）",
	["General"] = "General",

	-- Home page introduction
	["home_intro_1"] = "PVP Sound monitors enemy buffs/debuffs and CC effects, using Text-to-Speech (TTS) to announce important PvP spells in real time.",
	["home_intro_2"] = "It supports three announcement categories:",
	["home_intro_3"] = "|cFF00FF00Important Spells|r - Offensive abilities such as Avenging Wrath, Blessing of Freedom, Alter Time, etc.",
	["home_intro_4"] = "|cFF00BFFFDefensive Spells|r - Defensive cooldowns such as Blessing of Protection, Cloak of Shadows, Divine Shield, Ice Block, etc.",
	["home_intro_5"] = "|cFFFF6060Friendly CC|r - Crowd control effects applied to you or your party (Asphyxiate, Hammer of Justice, Polymorph, Sap, etc.).",
	["home_intro_6"] = "Each zone type (World, Arena, Battlegrounds, PvE) has independent settings — configure them in the tabs above.",
	["home_intro_7"] = "Use |cFFFFD100/pvpsound|r or |cFFFFD100/ps|r to open this panel, or |cFFFFD100/ps test|r to test TTS output.",
	["Reset"] = "Reset",
	["Are you sure you wish to reset to factory settings?"] = "Are you sure you wish to reset to factory settings?",
	["Settings reset to default."] = "Settings reset to default.",
	["Can't do that during combat."] = "Can't do that during combat.",
	["Test"] = "Test",

	-- TTS
	["TTS Settings"] = "TTS Settings",
	["Voice"] = "Voice",
	["You must choose a voice in your language for this to work."] = "You must choose a voice in your language for this to work.",
	["TTS Volume"] = "TTS Volume",
	["TTS Speech Rate"] = "TTS Speech Rate",

	-- Zone names
	["World"] = "World",
	["Arena"] = "Arena",
	["Battlegrounds"] = "Battlegrounds",
	["PvE"] = "PvE",

	-- Zone settings
	["Enabled"] = "Enabled",
	["Enable announcements in this zone."] = "Enable announcements in this zone.",
	["Important Spells"] = "Important Spells",
	["Announce important (offensive) spell names via TTS when enemies cast them."] = "Announce important (offensive) spell names via TTS when enemies cast them.",
	["Defensive Spells"] = "Defensive Spells",
	["Announce defensive spell names via TTS when enemies cast them."] = "Announce defensive spell names via TTS when enemies cast them.",
	["Friendly CC"] = "Friendly CC",
	["Announce CC on self or party via TTS."] = "Announce CC on self or party via TTS.",
	["Off"] = "Off",
	["Self Only"] = "Self Only",
	["Self + Party"] = "Self + Party",
	["Target Cast Bar"] = "Target Cast Bar",
	["Announce your target's spell casts via TTS."] = "Announce your target's spell casts via TTS.",
	["Target/Focus Only"] = "Target/Focus Only",
	["Only monitor your target and focus instead of all enemy nameplates."] = "Only monitor your target and focus instead of all enemy nameplates.",

	-- Misc
	["Important"] = "Important",
	["Defensive"] = "Defensive",
	["Notification"] = "Notification",
})

if GetLocale() == "enUS" or GetLocale() == "enGB" then
	for key, value in pairs(addon.L) do
		if type(value) == "string" then
			L:SetString(key, value)
		end
	end
end
