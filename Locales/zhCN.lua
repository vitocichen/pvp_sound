---@type string, Addon
local _, addon = ...
local L = addon.L

if GetLocale() ~= "zhCN" then
	return
end

L:SetStrings({
	-- General
	["PVP Sound - TTS voice announcements for PvP spells."] = "PVP Sound - PvP技能TTS语音播报。",
	["Author: DK-姜世离（燃烧之刃）"] = "作者：DK-姜世离（燃烧之刃）",
	["General"] = "常规",
	["Settings:"] = "设置：",
	["Enable in:"] = "启用于：",
	["World"] = "开放世界",
	["Arena"] = "竞技场",
	["Battlegrounds"] = "战场和团队",
	["PvE"] = "PvE",
	["Enable this module in the open world."] = "在开放世界中启用。",
	["Enable this module in arena."] = "在竞技场中启用。",
	["Enable this module in battlegrounds."] = "在战场中启用。",
	["Enable this module in PvE."] = "在PvE中启用。",
	["Reset"] = "重置",
	["Are you sure you wish to reset to factory settings?"] = "您确定要重置为出厂设置吗？",
	["Settings reset to default."] = "设置已重置为默认值。",
	["Can't apply settings during combat."] = "战斗中无法应用设置。",
	["Can't do that during combat."] = "战斗中无法执行该操作。",
	["Test"] = "测试",

	-- TTS
	["TTS Settings"] = "TTS语音设置",
	["Voice"] = "语音",
	["You must choose a voice in your language for this to work."] = "必须选择与你的语言匹配的语音才能使其生效。",
	["TTS Volume"] = "TTS音量",
	["TTS Speech Rate"] = "TTS语速",

	-- Announce categories
	["Announce Categories"] = "播报分类",
	["Important Spells"] = "重要法术（进攻技能）",
	["Announce important (offensive) spell names via TTS when enemies cast them."] = "当敌人施放重要进攻技能时，用TTS语音播报技能名称。",
	["Defensive Spells"] = "防御法术",
	["Announce defensive spell names via TTS when enemies cast them."] = "当敌人施放防御技能时，用TTS语音播报技能名称。",
	["Friendly CC"] = "友方被控",
	["Announce CC on self or party via TTS."] = "当你或队友被控制时用TTS语音播报控制技能名称。",
	["Off"] = "关闭",
	["Self Only"] = "仅自己",
	["Self + Party"] = "自己+队友",
	["Target/Focus Only"] = "仅目标/焦点",
	["Only monitor your target and focus in battlegrounds and the open world."] = "在战场和开放世界中仅监控你的目标和焦点。",

	-- Misc
	["Important"] = "重要",
	["Defensive"] = "防御",
	["Notification"] = "通知",
})
