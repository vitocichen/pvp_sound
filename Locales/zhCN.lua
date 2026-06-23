---@type string, Addon
local _, addon = ...
local L = addon.L

if GetLocale() ~= "zhCN" then
	return
end

L:SetStrings({
	-- General / Home
	["addon_description"] = "一款PVP语音播报插件，可以播报PVP战斗中的重要技能、防御技能、控制技能、读条监控和打断提醒等。",
	["Author: DK-姜世离（燃烧之刃）"] = "作者：DK-姜世离（燃烧之刃）",
	["General"] = "常规",

	-- Home page introduction
	["home_intro_1"] = "PVP Sound 实时监控敌方增益/减益/施法/被控制效果，通过TTS语音播报PvP中的重要技能。",
	["home_intro_tts_warning"] = "|cFFFF2020注：请关闭系统/其他插件的TTS语音播报，否则会造成重复和延时！！！|r",
	["home_intro_2"] = "支持六种播报类型：",
	["home_intro_3"] = "|cFF00FF00重要法术|r — 进攻性技能，如复仇之怒、自由之手、操控时间等。",
	["home_intro_4"] = "|cFF00BFFF防御法术|r — 防御性技能，如保护之手、暗影斗篷、无敌、冰箱等。",
	["home_intro_5"] = "|cFFFF6060友方被控|r — 施加在你或队友身上的控制技能（窒息、制裁、变羊、闷棍等）。",
	["home_intro_5b"] = "|cFFFFD100读条监控|r — 实时播报敌方施法/引导技能名称。",
	["home_intro_5c"] = "|cFFFFA500打断提醒|r — 当目标施法停止时播报打断成功。",
	["home_intro_5d"] = "|cFFFF69B4治疗被控|r — 当治疗被控时候播放提示音效。",
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
	["Voice Recommend Hint"] = "|cFFFFD100推荐 Xiaoxiao（实测 Huihui 会有播放乱序和延迟的BUG），教程如下：|r",
	["Voice Tutorial URL"] = "nga.178.com/read.php?tid=45648904",
	["Copy"] = "复制",
	["Copied"] = "已复制",
	["Speech Rate Recommend Hint"] = "|cFFFFD100推荐 Huihui 最低7，Xiaoxiao 最低5，否则会延迟播报|r",
	["Cast Interval"] = "读条播报间隔",

	-- Zone names
	["World"] = "野外",
	["Arena"] = "竞技场",
	["Battlegrounds"] = "战场",
	["PvE"] = "PvE",

	-- Zone settings
	["Enabled"] = "启用",
	["Enabled (Master)"] = "启用（总开关）",
	["Master switch: enable all announcements in this zone."] = "总开关：在此区域中启用所有语音播报。",
	["Enable announcements in this zone."] = "在此区域中启用语音播报。",

	-- Section 1: Important Spells
	["Important Spells Section"] = "重要技能语音",
	["Enable important and defensive spell announcements."] = "启用重要进攻技能和防御技能的语音播报。",
	["Important Monitor Range"] = "监控范围 |cFF00BFFF（建议选仅目标/焦点）|r",
	["Target/Focus Only Short"] = "仅目标/焦点",
	["Important Spells"] = "重要法术（进攻技能）",
	["Announce important (offensive) spell names via TTS when enemies cast them."] = "当敌人施放重要进攻技能时，用TTS语音播报技能名称。",
	["Defensive Spells"] = "防御法术",
	["Announce defensive spell names via TTS when enemies cast them."] = "当敌人施放防御技能时，用TTS语音播报技能名称。",
	["Only monitor your target and focus instead of all enemy nameplates."] = "仅监控你的目标和焦点，而不是所有敌方姓名板。",

	-- Section 2: CC Spells
	["CC Spells Section"] = "控制技能语音",
	["Enable CC spell announcements."] = "启用控制技能语音播报。",
	["CC Mode"] = "播报范围",
	["Announce CC on self or party via TTS."] = "当你或队友被控制时用TTS语音播报控制技能名称。",
	["Self Only"] = "仅自己",
	["Party Only"] = "仅队友",
	["Self + Party"] = "自己+队友",

	-- Section 3: Cast Bar
	["CastBar Section"] = "读条监控",
	["Announce enemy spell casts via TTS."] = "用TTS语音播报敌方施法。",
	["CastBar Range"] = "监控范围",
	["Choose which enemies' casts to announce."] = "选择播报哪些敌人的施法。",
	["Target Only"] = "仅目标",
	["Targeting Me"] = "仅对我施放",
	["All Enemies"] = "所有敌人",
	["Exclude Pets"] = "排除宠物",
	["Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts."] = "排除宠物和守护者的施法（如水元素），仅播报玩家施法。",
	["Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts."] = "排除宠物和守护者的打断（如水元素），仅播报玩家打断。",

	-- Section 4: Interrupt
	["Interrupt Section"] = "打断监控 |cFF00BFFF（只能判断目标施法是否停止，无法区分被打断还是自行取消）|r",
	["Announce via TTS when you successfully interrupt an enemy cast."] = "当目标被打断或停止施法时播报。",
	["Interrupted"] = "打断成功",
	["Interrupt Range"] = "监控范围",
	["Choose which enemies' interrupts to announce."] = "选择监控哪些敌人的施法中断。",
	["Target + Focus"] = "目标+焦点",

	-- Section 5: Healer CC
	["Healer CC Section"] = "治疗被控语音",
	["Announce via TTS when the enemy healer is crowd controlled."] = "当友方治疗被控制时，用TTS语音播报。",
	["Healer CC Mode"] = "播报方式",
	["TTS Mode"] = "TTS语音",
	["Sound File Mode"] = "自定义音效",
	["Healer CC TTS Text"] = "TTS播报文本",
	["The text to speak when enemy healer is CCed."] = "当友方治疗被控制时播报的文本。",
	["Healer CC Sound File"] = "音效文件",
	["Preview"] = "试听",

	-- Changelog tab
	["Changelog"] = "更新记录",
	["PVP Sound - What's New?"] = "PVP Sound — 更新内容",
	["Auto-enable Enemy Buffs"] = "自动开启姓名板「敌方增益」",
	["Auto-enable Enemy Buffs Tooltip"] = "进攻播报依赖系统姓名板的「敌方增益」显示。开启后插件会在登录/进场时自动把它打开（BetterBlizzPlates 等插件常会关掉它）。关闭本项则不再自动设置，需要你自己在暴雪界面里开启。",
	["changelog_v1.0.0"] = "|cFFFFD100v1.0.0|r — 初版本发布。",
	["changelog_v1.0.1"] = "|cFFFFD100v1.0.1|r — 新增野外/竞技场/战场/PvE场景区分。",
	["changelog_v1.0.2"] = "|cFFFFD100v1.0.2|r — 新增读条和打断监控。",
	["changelog_v1.0.3"] = "|cFFFFD100v1.0.3|r — 新增治疗被控监控。",
	["changelog_v1.0.5"] = "|cFFFFD100v1.0.5|r — 修复了读条重复播放的问题，新增多目标的打断成功监控。",
	["changelog_v1.0.13"] = "|cFFFFD100v1.0.13|r — 进攻播报改为读取姓名板内部的「重要增益」数据列表（与 Platynator 相同方式），不再依赖屏幕上的增益图标，也不再强制修改暴雪「敌方增益」设置。耐力/智力等无用常驻增益不会再被播报。",
	["changelog_v1.0.12"] = "|cFFFFD100v1.0.12|r — 升级被控语音模块，添加了仅队友选项，支持只播放队友的控制技能，适用于治疗职业。",
	["changelog_v1.0.11"] = "|cFFFFD100v1.0.11|r — 修复与 BetterBlizzPlates 等姓名板插件冲突：它们常会关掉系统的「敌方增益」显示，导致进攻播报失效。现在插件会在登录/进场时自动开启该显示（位域 nameplateEnemyPlayerAuraDisplay 的 Buffs 位）。可在设置里「自动开启姓名板敌方增益」关闭此行为。",
	["changelog_v1.0.10"] = "|cFFFFD100v1.0.10|r — 修复：①重要技能偶尔不播报（如法师镜像首次施放）——改用光环「新增事件」判定是否为新 buff，免疫光环编号复用与图标渲染时序问题，并加补扫兜底；②常驻增益（如德鲁伊全能）被姓名板2格上限挤出后回归时被重复播报（身上已有的 buff 一律视为旧的、永不播报，只播报你监视期间新出现的）；③读条/打断的「排除宠物」现在也能正确排除法师镜像、术士宝宝等守护者类单位，且即使你把它们设为目标也不会播报。",
	["changelog_v1.0.9"] = "|cFFFFD100v1.0.9|r — 适配12.0.7：暴雪移除了「重要」技能名单，进攻类无法再用光环数据精准识别。改为直接读取暴雪姓名板「敌方增益」已经精选好的 buff 图标来播报进攻技能，效果与系统姓名板一致；防御/控制播报不受影响。\n\n|cffff3030【必读】进攻播报依赖系统姓名板，请在暴雪原版界面设置里：①开启「显示敌方姓名板」（按 V 或在「界面-姓名板」里勾选）；②把姓名板的「敌方增益」勾上。否则进攻技能不会播报！|r",
	["changelog_v1.0.8"] = "|cFFFFD100v1.0.8|r — 真实目标施法监控仅支持检测「目标是我」的施法，焦点/鼠标指向施法受API限制无法实现过滤。",
	["changelog_v1.0.7"] = "|cFFFFD100v1.0.7|r — TTS语速调节范围扩大至-10~10，推荐Xiaoxiao最低5，Huihui最低7，否则会延时播报。",
	["changelog_v1.0.6"] = "|cFFFFD100v1.0.6|r — 新增读条/打断的「排除宠物」选项；适配Mac语音选择多列布局。",
	["changelog_v1.0.4"] = "|cFFFFD100v1.0.4|r — 修复了技能会重复播放的问题。",

	-- Donate
	["Donate"] = "打赏支持",
	["Donate Popup Title"] = "打赏支持",
	["Donate Popup Hint"] = "复制链接，在浏览器中打开即可扫码打赏：",
	["Donate Open Hint"] = "|cFF888888打不开？请尝试使用浏览器直接访问上方网址|r",

	-- Misc
	["Important"] = "重要",
	["Defensive"] = "防御",
	["Notification"] = "通知",
})
