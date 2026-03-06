---@type string, Addon
local _, addon = ...
local L = addon.L

L:SetDefaultStrings({
	-- General
	["PVP Sound - TTS voice announcements for PvP spells."] = "PVP Sound - TTS voice announcements for PvP spells.",
	["Author: DK-姜世离（燃烧之刃）"] = "Author: DK-姜世离（燃烧之刃）",
	["General"] = "General",
	["Settings:"] = "Settings:",
	["Enable in:"] = "Enable in:",
	["World"] = "World",
	["Arena"] = "Arena",
	["Battlegrounds"] = "Battlegrounds",
	["PvE"] = "PvE",
	["Enable this module in the open world."] = "Enable this module in the open world.",
	["Enable this module in arena."] = "Enable this module in arena.",
	["Enable this module in battlegrounds."] = "Enable this module in battlegrounds.",
	["Enable this module in PvE."] = "Enable this module in PvE.",
	["Reset"] = "Reset",
	["Are you sure you wish to reset to factory settings?"] = "Are you sure you wish to reset to factory settings?",
	["Settings reset to default."] = "Settings reset to default.",
	["Can't apply settings during combat."] = "Can't apply settings during combat.",
	["Can't do that during combat."] = "Can't do that during combat.",
	["Test"] = "Test",

	-- TTS
	["TTS Settings"] = "TTS Settings",
	["Voice"] = "Voice",
	["You must choose a voice in your language for this to work."] = "You must choose a voice in your language for this to work.",
	["TTS Volume"] = "TTS Volume",
	["TTS Speech Rate"] = "TTS Speech Rate",

	-- Announce categories
	["Announce Categories"] = "Announce Categories",
	["Important Spells"] = "Important Spells",
	["Announce important (offensive) spell names via TTS when enemies cast them."] = "Announce important (offensive) spell names via TTS when enemies cast them.",
	["Defensive Spells"] = "Defensive Spells",
	["Announce defensive spell names via TTS when enemies cast them."] = "Announce defensive spell names via TTS when enemies cast them.",
	["Friendly CC"] = "Friendly CC",
	["Announce CC on self or party via TTS."] = "Announce CC on self or party via TTS.",
	["Off"] = "Off",
	["Self Only"] = "Self Only",
	["Self + Party"] = "Self + Party",
	["Target/Focus Only"] = "Target/Focus Only",
	["Only monitor your target and focus in battlegrounds and the open world."] = "Only monitor your target and focus in battlegrounds and the open world.",

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
