---@type string, Addon
local _, addon = ...
local L = addon.L

L:SetDefaultStrings({
	-- General / Home
	["addon_description"] = "A PvP TTS addon that announces important spells, defensive cooldowns, crowd control, enemy cast bars, and interrupt alerts during PvP combat.",
	["Author: DK-姜世离（燃烧之刃）"] = "Author: DK-姜世离（燃烧之刃）",
	["General"] = "General",

	-- Home page introduction
	["home_intro_1"] = "PVP Sound monitors enemy buffs/debuffs, casts, and CC effects, using Text-to-Speech (TTS) to announce important PvP spells in real time.",
	["home_intro_tts_warning"] = "|cFFFF2020NOTE: Please disable system/other addon TTS voice, otherwise it will cause duplicate and delay!!!|r",
	["home_intro_2"] = "It supports six announcement categories:",
	["home_intro_3"] = "|cFF00FF00Important Spells|r - Offensive abilities such as Avenging Wrath, Blessing of Freedom, Alter Time, etc.",
	["home_intro_4"] = "|cFF00BFFFDefensive Spells|r - Defensive cooldowns such as Blessing of Protection, Cloak of Shadows, Divine Shield, Ice Block, etc.",
	["home_intro_5"] = "|cFFFF6060Friendly CC|r - Crowd control effects applied to you or your party (Asphyxiate, Hammer of Justice, Polymorph, Sap, etc.).",
	["home_intro_5b"] = "|cFFFFD100Cast Bar|r - Announces enemy spell casts and channels in real time.",
	["home_intro_5c"] = "|cFFFFA500Interrupt Alert|r - Announces when your target's cast is stopped.",
	["home_intro_5d"] = "|cFFFF69B4Healer CC|r - Plays an alert sound when the healer is crowd controlled.",
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
	["Voice Recommend Hint"] = "|cFFFFD100Recommend: Xiaoxiao (Huihui has playback order and delay bugs). Tutorial:|r",
	["Voice Tutorial URL"] = "nga.178.com/read.php?tid=45648904",
	["Copy"] = "Copy",
	["Copied"] = "Copied",
	["Speech Rate Recommend Hint"] = "|cFFFFD100Recommend: Huihui min 7, Xiaoxiao min 5, or TTS may be delayed|r",
	["Cast Interval"] = "Cast Interval",

	-- Zone names
	["World"] = "World",
	["Arena"] = "Arena",
	["Battlegrounds"] = "Battlegrounds",
	["PvE"] = "PvE",

	-- Zone settings
	["Enabled"] = "Enabled",
	["Enabled (Master)"] = "Enabled (Master Switch)",
	["Master switch: enable all announcements in this zone."] = "Master switch: enable all announcements in this zone.",
	["Enable announcements in this zone."] = "Enable announcements in this zone.",

	-- Section 1: Important Spells
	["Important Spells Section"] = "Important Spells",
	["Enable important and defensive spell announcements."] = "Enable important and defensive spell announcements.",
	["Important Monitor Range"] = "Monitor Range |cFF00BFFF(Recommend: Target/Focus)|r",
	["Target/Focus Only Short"] = "Target/Focus Only",
	["Important Spells"] = "Important Spells",
	["Announce important (offensive) spell names via TTS when enemies cast them."] = "Announce important (offensive) spell names via TTS when enemies cast them.",
	["Defensive Spells"] = "Defensive Spells",
	["Announce defensive spell names via TTS when enemies cast them."] = "Announce defensive spell names via TTS when enemies cast them.",
	["Only monitor your target and focus instead of all enemy nameplates."] = "Only monitor your target and focus instead of all enemy nameplates.",

	-- Section 2: CC Spells
	["CC Spells Section"] = "CC Spells",
	["Enable CC spell announcements."] = "Enable CC spell announcements.",
	["CC Mode"] = "Mode",
	["Announce CC on self or party via TTS."] = "Announce CC on self or party via TTS.",
	["Self Only"] = "Self Only",
	["Self + Party"] = "Self + Party",

	-- Section 3: Cast Bar
	["CastBar Section"] = "Cast Bar",
	["Announce enemy spell casts via TTS."] = "Announce enemy spell casts via TTS.",
	["CastBar Range"] = "Range",
	["Choose which enemies' casts to announce."] = "Choose which enemies' casts to announce.",
	["Target Only"] = "Target Only",
	["Targeting Me"] = "Targeting Me",
	["All Enemies"] = "All Enemies",
	["Exclude Pets"] = "Exclude Pets",
	["Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts."] = "Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts.",
	["Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts."] = "Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts.",

	-- Section 4: Interrupt
	["Interrupt Section"] = "Interrupt Alert |cFF00BFFF(Detects cast stop only, not actual interrupt)|r",
	["Announce via TTS when you successfully interrupt an enemy cast."] = "Announces when your target is interrupted or stops casting.",
	["Interrupted"] = "Interrupted",
	["Interrupt Range"] = "Range",
	["Choose which enemies' interrupts to announce."] = "Choose which enemies' interrupts to announce.",
	["Target + Focus"] = "Target + Focus",

	-- Section 5: Healer CC
	["Healer CC Section"] = "Healer CC",
	["Announce via TTS when the enemy healer is crowd controlled."] = "Announce via TTS when the friendly healer is crowd controlled.",
	["Healer CC Mode"] = "Alert Mode",
	["TTS Mode"] = "TTS Voice",
	["Sound File Mode"] = "Sound File",
	["Healer CC TTS Text"] = "TTS Text",
	["The text to speak when enemy healer is CCed."] = "The text to speak when the friendly healer is CCed.",
	["Healer CC Sound File"] = "Sound File",
	["Preview"] = "Preview",

	-- Changelog tab
	["Changelog"] = "Changelog",
	["changelog_v1.0.0"] = "|cFFFFD100v1.0.0|r — Initial release.",
	["changelog_v1.0.1"] = "|cFFFFD100v1.0.1|r — Added World / Arena / Battlegrounds / PvE zone detection.",
	["changelog_v1.0.2"] = "|cFFFFD100v1.0.2|r — Added Cast Bar and Interrupt monitoring.",
	["changelog_v1.0.3"] = "|cFFFFD100v1.0.3|r — Added Healer CC monitoring.",
	["changelog_v1.0.5"] = "|cFFFFD100v1.0.5|r — Fixed cast bar duplicate announcements; added multi-target interrupt alert monitoring.",
	["changelog_v1.0.7"] = "|cFFFFD100v1.0.7|r — Expanded TTS speech rate range to -10~10. Recommend Xiaoxiao min 5, Huihui min 7, or TTS may be delayed.",
	["changelog_v1.0.6"] = "|cFFFFD100v1.0.6|r — Added 'Exclude Pets' option for Cast Bar and Interrupt; adapted voice dropdown layout for Mac.",
	["changelog_v1.0.4"] = "|cFFFFD100v1.0.4|r — Fixed an issue where spell announcements could be played repeatedly.",

	-- Donate
	["Donate"] = "Donate",
	["Donate Popup Title"] = "Support PVP Sound",
	["Donate Popup Hint"] = "Copy the link and open in your browser to donate:",
	["Donate Open Hint"] = "|cFF888888Can't open? Find donate.html in the addon folder and double-click it|r",

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
