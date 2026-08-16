---@type string, Addon
local _, addon = ...

-- PvP consumables that do not apply a visible aura. Detect via player
-- UNIT_SPELLCAST_SUCCEEDED (same event as interrupt-kick), not UNIT_AURA.
addon.Data.Consumables = {
	[1234768] = { zh = "银月城生命药水", en = "Silvermoon Potion of Life" },
	[1263074] = { zh = "阿曼尼提取物", en = "Amani Extract" },
	[1236994] = { zh = "鲁莽药水", en = "Reckless Potion" },
	[1295247] = { zh = "浓缩银月城生命药水", en = "Concentrated Silvermoon Potion of Life" },
	[1236616] = { zh = "圣光潜力", en = "Holy Potential" },
	[1235568] = { zh = "圣光之护", en = "Holy Protection" },
	[1295132] = { zh = "浓态光泽", en = "Viscous Gloss" },
}
