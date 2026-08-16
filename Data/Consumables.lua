---@type string, Addon
local _, addon = ...

-- Watch by spellID and itemID. Midnight often hides UNIT_SPELLCAST_SUCCEEDED
-- spell IDs; item/spell cooldown APIs still accept our hardcoded numbers.
addon.Data.Consumables = {
	List = {
		{ zh = "银月城生命药水", en = "Silvermoon Health Potion", itemID = 241304, spellID = 1234768 },
		{ zh = "复苏血清", en = "Refreshing Serum", itemID = 241306, spellID = 1236590 },
		{ zh = "阿曼尼提取物", en = "Amani Extract", spellID = 1263074 },
		{ zh = "鲁莽药水", en = "Potion of Recklessness", itemID = 241288, spellID = 1236994 },
		{ zh = "狂放恣意饮剂", en = "Draught of Rampant Abandon", itemID = 241292, spellID = 1236998 },
		{ zh = "狂热药水", en = "Potion of Zealotry", itemID = 241296, spellID = 1238443 },
		{ zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion", itemID = 271883, spellID = 1295247 },
		{ zh = "圣光潜力", en = "Light's Potential", spellID = 1236616 },
		{ zh = "圣光之护", en = "Light's Preservation", spellID = 1235568 },
		{ zh = "浓态光泽", en = "Viscous Gloss", spellID = 1295132 },
		{ zh = "焕生治疗药水", en = "Algari Healing Potion", itemID = 244839, spellID = 1238009 },
		{ zh = "重生猎豹药水", en = "Reborn Cheetah Potion", itemID = 212268, spellID = 431941 },
	},
	Spells = {
		[1234768] = { zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		[1236590] = { zh = "复苏血清", en = "Refreshing Serum" },
		[1263074] = { zh = "阿曼尼提取物", en = "Amani Extract" },
		[1236994] = { zh = "鲁莽药水", en = "Potion of Recklessness" },
		[1236998] = { zh = "狂放恣意饮剂", en = "Draught of Rampant Abandon" },
		[1238443] = { zh = "狂热药水", en = "Potion of Zealotry" },
		[1295247] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
		[1236616] = { zh = "圣光潜力", en = "Light's Potential" },
		[1235568] = { zh = "圣光之护", en = "Light's Preservation" },
		[1295132] = { zh = "浓态光泽", en = "Viscous Gloss" },
		[1238009] = { zh = "焕生治疗药水", en = "Algari Healing Potion" },
		[431941] = { zh = "重生猎豹药水", en = "Reborn Cheetah Potion" },
	},
	Items = {
		[241304] = { zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		[241305] = { zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		[241306] = { zh = "复苏血清", en = "Refreshing Serum" },
		[241307] = { zh = "复苏血清", en = "Refreshing Serum" },
		[241288] = { zh = "鲁莽药水", en = "Potion of Recklessness" },
		[241292] = { zh = "狂放恣意饮剂", en = "Draught of Rampant Abandon" },
		[241296] = { zh = "狂热药水", en = "Potion of Zealotry" },
		[271883] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
		[271884] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
		[244839] = { zh = "焕生治疗药水", en = "Algari Healing Potion" },
		[212268] = { zh = "重生猎豹药水", en = "Reborn Cheetah Potion" },
	},
}
