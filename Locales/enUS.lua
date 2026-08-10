---@type string, Addon
local _, addon = ...
local L = addon.L

L:SetDefaultStrings({
	["addon_description"] = "A PvP voice alert addon that announces important combat spells and plays custom sound effects.",
	["Author: DK-姜世离（燃烧之刃）"] = "Author: DK-姜世离（燃烧之刃）",
	["General"] = "General",

	["home_intro_1"] = "PVP Sound plays voice alerts when enemies gain buffs, and when you/teammates get debuffs. On 12.1 the engine plays them via AddAuraSound.",
	["home_intro_voice_warning"] = "|cFF00FF00Voice packs|r live under Media\\<pack name>\\ (built-in packs or your own folder).",
	["home_intro_enemy_buffs"] = "Spell checkboxes are global. Zone tab toggles buff / debuff / healer-CC per zone and sets monitor ranges.",
	["home_intro_7"] = "|cFFFFD100/pvpsound|r or |cFFFFD100/ps|r opens settings. |cFFFFD100/ps test|r previews Ice Block. |cFFFFD100/pvpsdiag|r shows registrations.",
	["Reset"] = "Reset",
	["Are you sure you wish to reset to factory settings?"] = "Are you sure you wish to reset to factory settings?",
	["Settings reset to default."] = "Settings reset to default.",
	["Can't do that during combat."] = "Can't do that during combat.",
	["Test"] = "Test",
	["Add"] = "Add",

	["Sound Settings"] = "Sound Settings",
	["Voice Pack Hint"] = "Put .ogg/.mp3 clips in Media\\<pack name>\\. Use a built-in pack, or create a folder and Add its name below.",
	["Voice Pack Select"] = "Voice Pack",
	["Custom Voice Pack"] = "Add custom pack",
	["voice_pack_added"] = "Registered voice pack: %s (put clips in Media\\%s\\).",
	["voice_pack_add_failed"] = "Invalid pack name. Use a folder name under Media\\ with no path separators.",
	["voice_pack_reload_hint"] = "Re-open this settings page (or /reload) to refresh the dropdown list.",
	["Output Channel"] = "Output Channel",
	["channel_Master"] = "Master",
	["channel_SFX"] = "SFX",
	["channel_Ambience"] = "Ambience",
	["channel_Dialog"] = "Dialog",
	["channel_Music"] = "Music",
	["Copy"] = "Copy",
	["Copied"] = "Copied",

	["Zones"] = "Zones",
	["zones_intro"] = "Enable enemy buff, debuff, and healer-in-CC alerts per zone, each with its own monitor range where applicable.",
	["Enable"] = "Enable",
	["Enable Buff Alerts"] = "Enable buff alerts",
	["Enable Debuff Alerts"] = "Enable debuff alerts",
	["Enable Healer CC Alerts"] = "Enable healer CC alerts",
	["Enable enemy buff voice alerts in this zone."] = "Enable enemy buff voice alerts in this zone.",
	["Enable self-debuff voice alerts in this zone."] = "Enable debuff voice alerts in this zone.",
	["Enable healer-in-CC voice alerts in this zone."] = "Play an alert when a party/raid healer is crowd-controlled (MiniAuras-style full CC list).",
	["Monitor Range"] = "Monitor Range",
	["Monitor Target Focus"] = "Target + Focus enemies",
	["Monitor Everyone"] = "All enemies",
	["Target/Focus Only Short"] = "Target + Focus enemies",
	["Only monitor your target and focus instead of all enemy nameplates."] = "Only monitor enemy target and focus. Uncheck to watch every enemy nameplate.",

	["World"] = "World",
	["Arena"] = "Arena",
	["Battlegrounds"] = "Battlegrounds",
	["PvE"] = "PvE",

	["Death Knight"] = "Death Knight",
	["Demon Hunter"] = "Demon Hunter",
	["Druid"] = "Druid",
	["Evoker"] = "Evoker",
	["Hunter"] = "Hunter",
	["Mage"] = "Mage",
	["Monk"] = "Monk",
	["Paladin"] = "Paladin",
	["Priest"] = "Priest",
	["Rogue"] = "Rogue",
	["Shaman"] = "Shaman",
	["Warlock"] = "Warlock",
	["Warrior"] = "Warrior",
	["Other"] = "Other",

	["Spells"] = "Spells",
	["General Spells"] = "General Spells",
	["Class Spells"] = "Class Spells",
	["Self CC"] = "Debuff",
	["Enable Self CC"] = "Announce debuffs",
	["Self CC Scope"] = "Debuff alert scope",
	["Self CC Scope Self"] = "Self",
	["Self CC Scope Party"] = "Self + teammates",
	["selfcc_master_tooltip"] = "Watch yourself, or yourself plus party/raid teammates. Plays when a checked debuff lands.",
	["selfcc_tab_intro"] = "Pick debuffs by class. When that effect lands on you, it announces. Includes Storm Bolt, Intimidating Shout, Deathmark, etc.",
	["Class"] = "Class",
	["spells_tab_intro"] = "Play debuff alerts, e.g. Hammer of Justice / Storm Bolt / Intimidating Shout / Deathmark.",
	["class_spells_intro"] = "%s — check spells to announce. Clicking on enables and previews the clip.",
	["spell_toggle_tooltip"] = "spellID %d → %s",
	["Select All"] = "Select All",
	["Select None"] = "Select None",
	["spell_group_buffs"] = "Buff",
	["spell_group_debuffs"] = "Debuff",
	["spell_group_debuffs_general"] = "Debuff",

	["Changelog"] = "Changelog",
	["PVP Sound - What's New?"] = "PVP Sound - What's New?",
	["changelog_v4.1.0"] = "|cFFFFD100v4.1.0|r — Voice pack picker (Media\\包名). Bundled 夏一可 + 夏一可1.5x. Custom folders supported.",
	["changelog_v4.0.1"] = "|cFFFFD100v4.0.1|r — Debuffs: announce when effects land on you (player via AddAuraSound). Warrior Storm Bolt / Intimidating Shout included.",
	["changelog_v4.0.0"] = "|cFFFFD100v4.0.0|r — 12.1 rewrite: AddAuraSound + GladiatorlosSA voices. Zones are on/off only; spells are chosen globally by class (buff / debuff).",
	["changelog_v2.0.3"] = "|cFFFFD100v2.0.3|r — Previous TTS-era release.",

	["Donate"] = "Donate",
	["Donate Popup Title"] = "Support PVP Sound",
	["Donate Popup Hint"] = "Copy the link and open in your browser to donate:",
	["Donate Open Hint"] = "|cFF888888Can't open? Try visiting the URL above in your browser|r",

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
