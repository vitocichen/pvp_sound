---@type string, Addon
local _, addon = ...

-- Potion clips play via AddAuraSound (enemy buffs). Honesty /yell watches
-- player auras with GetPlayerAuraBySpellID using these hardcoded IDs.
addon.Data.Consumables = {
	List = {
		{ zh = "生命药水", en = "Health Potion", itemID = 241304, spellID = 1234768, file = "silvermoonPotion.ogg" },
		{ zh = "复苏血清", en = "Refreshing Serum", itemID = 241306, spellID = 1236590, file = "refreshingSerum.ogg" },
		{ zh = "阿曼尼提取物", en = "Amani Extract", spellID = 1263074, file = "amaniExtract.ogg" },
		{ zh = "鲁莽药水", en = "Potion of Recklessness", itemID = 241288, spellID = 1236994, file = "recklessPotion.ogg" },
		{ zh = "恣意饮剂药水", en = "Abandon Potion", itemID = 241292, spellID = 1236998, file = "rampantAbandon.ogg" },
		{ zh = "狂热药水", en = "Potion of Zealotry", itemID = 241296, spellID = 1238443, file = "zealotryPotion.ogg" },
		{ zh = "生命药水", en = "Health Potion", itemID = 271883, spellID = 1295247, file = "concentratedSilvermoon.ogg" },
		{ zh = "圣光潜力", en = "Light's Potential", spellID = 1236616, file = "lightsPotential.ogg" },
		{ zh = "圣光之护", en = "Light's Preservation", spellID = 1235568, file = "lightsPreservation.ogg" },
		{ zh = "浓态光泽", en = "Viscous Gloss", spellID = 1295132, file = "viscousGloss.ogg" },
		{ zh = "治疗药水", en = "Healing Potion", itemID = 244839, spellID = 1238009, file = "algariHealingPotion.ogg" },
		{ zh = "猎豹药水", en = "Cheetah Potion", itemID = 212268, spellID = 431941, file = "rebornCheetahPotion.ogg" },
	},
	Spells = {
		[1234768] = { zh = "生命药水", en = "Health Potion" },
		[1236590] = { zh = "复苏血清", en = "Refreshing Serum" },
		[1263074] = { zh = "阿曼尼提取物", en = "Amani Extract" },
		[1236994] = { zh = "鲁莽药水", en = "Potion of Recklessness" },
		[1236998] = { zh = "恣意饮剂药水", en = "Abandon Potion" },
		[1238443] = { zh = "狂热药水", en = "Potion of Zealotry" },
		[1295247] = { zh = "生命药水", en = "Health Potion" },
		[1236616] = { zh = "圣光潜力", en = "Light's Potential" },
		[1235568] = { zh = "圣光之护", en = "Light's Preservation" },
		[1295132] = { zh = "浓态光泽", en = "Viscous Gloss" },
		[1238009] = { zh = "治疗药水", en = "Healing Potion" },
		[431941] = { zh = "猎豹药水", en = "Cheetah Potion" },
	},
	Items = {
		[241304] = { zh = "生命药水", en = "Health Potion" },
		[241305] = { zh = "生命药水", en = "Health Potion" },
		[241306] = { zh = "复苏血清", en = "Refreshing Serum" },
		[241307] = { zh = "复苏血清", en = "Refreshing Serum" },
		[241288] = { zh = "鲁莽药水", en = "Potion of Recklessness" },
		[241292] = { zh = "恣意饮剂药水", en = "Abandon Potion" },
		[241296] = { zh = "狂热药水", en = "Potion of Zealotry" },
		[271883] = { zh = "生命药水", en = "Health Potion" },
		[271884] = { zh = "生命药水", en = "Health Potion" },
		[244839] = { zh = "治疗药水", en = "Healing Potion" },
		[212268] = { zh = "猎豹药水", en = "Cheetah Potion" },
	},
}
