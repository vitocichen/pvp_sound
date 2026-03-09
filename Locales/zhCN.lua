---@type string, Addon
local _, addon = ...
local L = addon.L

if GetLocale() ~= "zhCN" then
	return
end

L:SetStrings({
	-- General / Home
	["addon_description"] = "一款PVP语音播报插件，可以播报PVP战斗中的防御技能/重要buff技能/控制技能语音等。",
	["Author: DK-姜世离（燃烧之刃）"] = "作者：DK-姜世离（燃烧之刃）",
	["General"] = "常规",

	-- Home page introduction
	["home_intro_1"] = "PVP Sound 实时监控敌方增益/减益效果/被控制效果，通过TTS语音播报PvP中的重要技能。",
	["home_intro_2"] = "支持三种播报类型：",
	["home_intro_3"] = "|cFF00FF00重要法术|r — 进攻性技能，如复仇之怒、自由之手、操控时间等。",
	["home_intro_4"] = "|cFF00BFFF防御法术|r — 防御性技能，如保护之手、暗影斗篷、无敌、冰箱等。",
	["home_intro_5"] = "|cFFFF6060友方被控|r — 施加在你或队友身上的控制技能（窒息、制裁、变羊、闷棍等）。",
	["home_intro_6"] = "每种区域（野外、竞技场、战场、PvE）都有独立的设置 — 请在上方的标签页中分别配置。",
	["home_intro_7"] = "输入 |cFFFFD100/pvpsound|r 或 |cFFFFD100/ps|r 打开设置面板，|cFFFFD100/ps test|r 可测试TTS语音输出。",
	["Reset"] = "重置",
	["Are you sure you wish to reset to factory settings?"] = "您确定要重置为出厂设置吗？",
	["Settings reset to default."] = "设置已重置为默认值。",
	["Can't do that during combat."] = "战斗中无法执行该操作。",
	["Test"] = "测试",

	-- TTS
	["TTS Settings"] = "TTS语音设置",
	["Voice"] = "语音",
	["You must choose a voice in your language for this to work."] = "必须选择与你的语言匹配的语音才能使其生效。",
	["TTS Volume"] = "TTS音量",
	["TTS Speech Rate"] = "TTS语速",

	-- Zone names
	["World"] = "野外",
	["Arena"] = "竞技场",
	["Battlegrounds"] = "战场",
	["PvE"] = "PvE",

	-- Zone settings
	["Enabled"] = "启用",
	["Enable announcements in this zone."] = "在此区域中启用语音播报。",
	["Important Spells"] = "重要法术（进攻技能）",
	["Announce important (offensive) spell names via TTS when enemies cast them."] = "当敌人施放重要进攻技能时，用TTS语音播报技能名称。",
	["Defensive Spells"] = "防御法术",
	["Announce defensive spell names via TTS when enemies cast them."] = "当敌人施放防御技能时，用TTS语音播报技能名称。",
	["Friendly CC"] = "友方被控",
	["Announce CC on self or party via TTS."] = "当你或队友被控制时用TTS语音播报控制技能名称。",
	["Off"] = "关闭",
	["Self Only"] = "仅自己",
	["Self + Party"] = "自己+队友",
	["Target Cast Bar"] = "目标读条播报",
	["Announce your target's spell casts via TTS."] = "当目标施放非瞬发法术时，用TTS语音播报法术名称。",
	["Target/Focus Only"] = "仅目标/焦点",
	["Only monitor your target and focus instead of all enemy nameplates."] = "仅监控你的目标和焦点，而不是所有敌方姓名板。",

	-- Misc
	["Important"] = "重要",
	["Defensive"] = "防御",
	["Notification"] = "通知",
})
