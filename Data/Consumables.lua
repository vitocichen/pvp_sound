---@type string, Addon
local _, addon = ...

-- Watch by spellID and itemID. Midnight often hides UNIT_SPELLCAST_SUCCEEDED
-- spell IDs; item/spell cooldown APIs still accept our hardcoded numbers.
addon.Data.Consumables = {
	-- Unique names for the read-only General Spells list (always on).
	List = {
		{ zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		{ zh = "基础活力药水", en = "Refreshing Serum" },
		{ zh = "阿曼尼提取物", en = "Amani Extract" },
		{ zh = "鲁莽药水", en = "Reckless Potion" },
		{ zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
		{ zh = "圣光潜力", en = "Light's Potential" },
		{ zh = "圣光之护", en = "Light's Preservation" },
		{ zh = "浓态光泽", en = "Viscous Gloss" },
	},
	Spells = {
		[1234768] = { zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		[1263074] = { zh = "阿曼尼提取物", en = "Amani Extract" },
		[1236994] = { zh = "鲁莽药水", en = "Reckless Potion" },
		[1295247] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
		[1236616] = { zh = "圣光潜力", en = "Light's Potential" },
		[1235568] = { zh = "圣光之护", en = "Light's Preservation" },
		[1295132] = { zh = "浓态光泽", en = "Viscous Gloss" },
	},
	Items = {
		[241304] = { zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		[241305] = { zh = "银月城生命药水", en = "Silvermoon Health Potion" },
		[241306] = { zh = "基础活力药水", en = "Refreshing Serum" },
		[241307] = { zh = "基础活力药水", en = "Refreshing Serum" },
		[271883] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
		[271884] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Health Potion" },
	},
}
