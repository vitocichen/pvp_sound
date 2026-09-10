---@type string, Addon
local _, addon = ...

-- Enemy interrupt clips for arena: MiniCC 5.40.0 KickData + this addon's ogg names.
-- SpecId = nil SpellId means that spec has no interrupt (not shown in the UI list).
---@class EnemyKicks
local M = {}
addon.Data.EnemyKicks = M

-- UI list: kick-only clips. Solar Beam / Silence stay on Self CC (they are also debuffs).
M.List = {
	{ Id = 2139,   File = "Counterspell.ogg", Label = "法术反制" },
	{ Id = 47528,  File = "MindFreeze.ogg",    Label = "心灵冰冻" },
	{ Id = 1766,   File = "Kick.ogg",         Label = "脚踢" },
	{ Id = 6552,   File = "Pummel.ogg",        Label = "拳击" },
	{ Id = 183752, File = "disrupt.ogg",      Label = "瓦解" },
	{ Id = 57994,  File = "windShear.ogg",     Label = "风剪" },
	{ Id = 132409, File = "SpellLock.ogg",    Label = "法术封锁" },
	{ Id = 116705, File = "spearStrike.ogg", Label = "切喉手" },
	{ Id = 96231,  File = "Rebuke.ogg",       Label = "责难" },
	{ Id = 351338, File = "quell.ogg",        Label = "镇压" },
	{ Id = 106839, File = "skullBash.ogg",   Label = "裂颅猛击" },
	{ Id = 147362, File = "countershot.ogg", Label = "反制射击" },
}

M.SpellFiles = {
	[2139]   = "Counterspell.ogg",
	[47528]  = "MindFreeze.ogg",
	[1766]   = "Kick.ogg",
	[6552]   = "Pummel.ogg",
	[183752] = "disrupt.ogg",
	[57994]  = "windShear.ogg",
	[132409] = "SpellLock.ogg",
	[119910] = "SpellLock.ogg", -- Command Demon: Spell Lock
	[19647]  = "SpellLock.ogg",
	[116705] = "spearStrike.ogg",
	[96231]  = "Rebuke.ogg",
	[351338] = "quell.ogg",
	[106839] = "skullBash.ogg",
	[147362] = "countershot.ogg",
	[187707] = "countershot.ogg", -- Survival Muzzle: same clip as Counter Shot
}

-- These also land as debuffs (Self CC). Kick tracker must not announce them,
-- or Balance / Shadow would be guessed as Skull Bash / nothing useful.
M.DebuffInstead = {
	[78675] = true, -- Solar Beam (silence aura 81261)
	[15487] = true, -- Silence
}

-- Canonical checkbox id for a resolved interrupt (warlock pet variants share Spell Lock).
M.CanonicalId = {
	[119910] = 132409,
	[19647]  = 132409,
	[187707] = 147362, -- Survival Muzzle → Counter Shot voice / checkbox
}

-- Class token fallback when every PvP spec shares the same interrupt.
M.ClassInterruptSpell = {
	["WARRIOR"]     = 6552,
	["DEATHKNIGHT"] = 47528,
	["DEMONHUNTER"] = 183752,
	["MONK"]        = 116705,
	["PALADIN"]     = 96231,
	["ROGUE"]       = 1766,
	["MAGE"]        = 2139,
	["SHAMAN"]      = 57994,
	["EVOKER"]      = 351338,
	["WARLOCK"]     = 132409,
}

-- Per-spec interrupt data (MiniCC KickData.SpecData). SpellId = nil: no interrupt.
M.SpecData = {
	[259] = { SpellId = 1766,   KickCd = 15, Class = "ROGUE" },
	[260] = { SpellId = 1766,   KickCd = 15, Class = "ROGUE" },
	[261] = { SpellId = 1766,   KickCd = 15, Class = "ROGUE" },

	[71]  = { SpellId = 6552,   KickCd = 15, Class = "WARRIOR" },
	[72]  = { SpellId = 6552,   KickCd = 15, Class = "WARRIOR" },
	[73]  = { SpellId = 6552,   KickCd = 15, Class = "WARRIOR" },

	[250] = { SpellId = 47528,  KickCd = 15, Class = "DEATHKNIGHT" },
	[251] = { SpellId = 47528,  KickCd = 15, Class = "DEATHKNIGHT" },
	[252] = { SpellId = 47528,  KickCd = 15, Class = "DEATHKNIGHT" },

	[577]  = { SpellId = 183752, KickCd = 15, Class = "DEMONHUNTER" },
	[581]  = { SpellId = 183752, KickCd = 15, Class = "DEMONHUNTER" },
	[1480] = { SpellId = 183752, KickCd = 15, Class = "DEMONHUNTER" },

	[268] = { SpellId = 116705, KickCd = 15, Class = "MONK" },
	[269] = { SpellId = 116705, KickCd = 15, Class = "MONK" },
	[270] = { SpellId = nil,    KickCd = nil, Class = "MONK" },

	[65]  = { SpellId = nil,    KickCd = nil, Class = "PALADIN" },
	[66]  = { SpellId = 96231,  KickCd = 15, Class = "PALADIN" },
	[70]  = { SpellId = 96231,  KickCd = 15, Class = "PALADIN" },

	[102] = { SpellId = 78675,  KickCd = 60, Class = "DRUID" },
	[103] = { SpellId = 106839, KickCd = 15, Class = "DRUID" },
	[104] = { SpellId = 106839, KickCd = 15, Class = "DRUID" },
	[105] = { SpellId = nil,    KickCd = nil, Class = "DRUID" },

	[253] = { SpellId = 147362, KickCd = 24, Class = "HUNTER" },
	[254] = { SpellId = 147362, KickCd = 24, Class = "HUNTER" },
	[255] = { SpellId = 187707, KickCd = 15, Class = "HUNTER" },

	[62]  = { SpellId = 2139,   KickCd = 20, Class = "MAGE" },
	[63]  = { SpellId = 2139,   KickCd = 20, Class = "MAGE" },
	[64]  = { SpellId = 2139,   KickCd = 20, Class = "MAGE" },

	[265] = { SpellId = 132409, KickCd = 24, Class = "WARLOCK" },
	[266] = { SpellId = 132409, KickCd = 30, Class = "WARLOCK" },
	[267] = { SpellId = 132409, KickCd = 24, Class = "WARLOCK" },

	[262] = { SpellId = 57994,  KickCd = 12, Class = "SHAMAN" },
	[263] = { SpellId = 57994,  KickCd = 12, Class = "SHAMAN" },
	[264] = { SpellId = 57994,  KickCd = 30, Class = "SHAMAN" },

	[1467] = { SpellId = 351338, KickCd = 20, Class = "EVOKER" },
	[1468] = { SpellId = nil,    KickCd = nil, Class = "EVOKER" },
	[1473] = { SpellId = nil,    KickCd = nil, Class = "EVOKER" },

	[256] = { SpellId = nil,    KickCd = nil, Class = "PRIEST" },
	[257] = { SpellId = nil,    KickCd = nil, Class = "PRIEST" },
	[258] = { SpellId = 15487,  KickCd = 45, Class = "PRIEST" },
}

---@type table<string, table[]>?
local classKicks

---@return table<string, table[]>
local function GetClassKicks()
	if classKicks then
		return classKicks
	end
	local built = {}
	for specId, specInfo in pairs(M.SpecData) do
		if specInfo.SpellId and specInfo.KickCd and specInfo.Class then
			local list = built[specInfo.Class] or {}
			built[specInfo.Class] = list
			list[#list + 1] = { SpecId = specId, SpellId = specInfo.SpellId, KickCd = specInfo.KickCd }
		end
	end
	classKicks = built
	return built
end

function M:CanonicalSpellId(spellId)
	spellId = tonumber(spellId)
	if not spellId then return nil end
	return M.CanonicalId[spellId] or spellId
end

---MiniCC ResolveKick: class token + current arena opponent specs → interrupt spell + file.
---Secret/unknown class → nil (no generic interrupted.ogg).
---@param class string?
---@param opponentSpecIds number[]
---@return number? spellId
---@return string? file
function M:ResolveKick(class, opponentSpecIds)
	if class == nil then
		return nil, nil
	end
	if issecretvalue and issecretvalue(class) then
		return nil, nil
	end
	if type(class) ~= "string" or class == "" then
		return nil, nil
	end

	local kicks = GetClassKicks()[class]
	if not kicks or #kicks == 0 then
		return nil, nil
	end

	local match
	local ambiguous = false
	opponentSpecIds = opponentSpecIds or {}

	for i = 1, #opponentSpecIds do
		local specId = opponentSpecIds[i]
		for _, kick in ipairs(kicks) do
			if kick.SpecId == specId then
				if match and (match.SpellId ~= kick.SpellId or match.KickCd ~= kick.KickCd) then
					ambiguous = true
				end
				match = match or kick
			end
		end
	end

	if ambiguous or not match then
		local counts = {}
		for _, kick in ipairs(kicks) do
			counts[kick.SpellId] = (counts[kick.SpellId] or 0) + 1
		end
		match = kicks[1]
		for _, kick in ipairs(kicks) do
			local better = counts[kick.SpellId] > counts[match.SpellId]
				or (counts[kick.SpellId] == counts[match.SpellId] and kick.KickCd < match.KickCd)
			if better then
				match = kick
			end
		end
	end

	if not match or not match.SpellId then
		return nil, nil
	end
	local spellId = M:CanonicalSpellId(match.SpellId)
	if spellId and M.DebuffInstead[spellId] then
		return nil, nil
	end
	local file = spellId and M.SpellFiles[spellId]
	if not file then
		return nil, nil
	end
	return spellId, file
end
