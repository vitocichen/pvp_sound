---@type string, Addon
local addonName, addon = ...
local mini = addon.Core.Framework
local L = addon.L
local verticalSpacing = mini.VerticalSpacing
local horizontalSpacing = mini.HorizontalSpacing
local catalog = addon.Data.EnemyBuffCatalog
local selfCcCatalog = addon.Data.SelfCcCatalog
local voicePack = addon.Core.VoicePack
local profiles = addon.Core.Profiles

---@type Db
local db

-- StaticPopup data can be unreliable across client builds; keep confirm action here.
local pendingConfirmYes
local pendingConfirmNo

local function ShowConfirm(message, onYes, onNo)
	pendingConfirmYes = onYes
	pendingConfirmNo = onNo
	StaticPopup_Show("PVPSOUND_CONFIRM", message, nil, {
		OnYes = onYes,
		OnNo = onNo,
	})
end

local function AuraSounds()
	return addon.Modules.AuraSoundModule
end

local function BuildDefaultSpells()
	local spells = {}
	for spellId in pairs(addon.Data.EnemyBuffSounds) do
		spells[spellId] = true
	end
	return spells
end

local function BuildDefaultSelfCcSpells()
	local spells = {}
	for spellId in pairs(addon.Data.SelfCcSounds) do
		spells[spellId] = true
	end
	return spells
end

local dbDefaults = {
	Version = 29,
	WhatsNewVersion = false,
	VoicePack = "夏一可1.25x",
	ExtraVoicePacks = {},
	-- Healer-CC alert clip: HealerCcAlert.ogg lives in the selected voice pack; PS_* under Media\.
	HealerCcSoundFile = "HealerCcAlert.ogg",
	-- Interrupt success clip: interrupted.ogg from voice pack; PS_* under Media\.
	InterruptSoundFile = "interrupted.ogg",
	Sound = {
		Channel = "Master",
		CastInterval = 0.0,
	},
	-- PreferredMode: 0 off / 1 cast start / 2 cast end (system CAATargetCastMode when zone CastBar on).
	SysCast = {
		PreferredMode = 1,
	},
	-- Enabled = enemy buff; CcEnabled = self/party debuff; HealerCcEnabled = healer-in-CC;
	-- InterruptAlert = cast-interrupted voice; CastBar = system target-cast announce gate;
	-- ConsumableSay = /say when you use listed PvP potions (no aura).
	-- TargetFocusOnly = buff monitor (false = all enemies); CcScope = self|party|partyonly for debuffs.
	Zones = {
		World = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
		Arena = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
		BattleGrounds = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
		PvE = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
	},
	-- Sparse disable maps: key=spellId, value=true means unchecked/disabled.
	-- Missing key = enabled (default on). Avoids huge Spells={all true} SavedVariables issues.
	DisabledEnemySpells = {},
	DisabledSelfCcSpells = {},
	-- Legacy full maps kept for migration / old readers; no longer the source of truth.
	Spells = {},
	SelfCcSpells = {},
	-- Named config snapshots (multi-profile). Not wiped by settings CleanTable.
	ActiveProfileName = "",
	Profiles = {},
}

local M = addon.ConfigModern

function M:Apply()
	addon:Refresh()
end

-- ---------- migrations (keep chain so old DBs upgrade cleanly) ----------

local function MigrateV1(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 2) then return end
	savedDb.Version = 2
end

local function MigrateThroughV11(savedDb)
	if not savedDb then return end
	if not savedDb.Version then savedDb.Version = 1 end
	-- Jump any pre-v12 profile to the new simplified schema.
	if savedDb.Version >= 12 then return end

	local oldCastInterval = savedDb.TTS and savedDb.TTS.CastInterval
		or (savedDb.Sound and savedDb.Sound.CastInterval)

	local zoneEnabled = {}
	if savedDb.Zones then
		for key, zone in pairs(savedDb.Zones) do
			zoneEnabled[key] = zone.Enabled ~= false
		end
	end

	savedDb.TTS = nil
	savedDb.Sound = {
		Channel = (savedDb.Sound and savedDb.Sound.Channel) or "Master",
		CastInterval = oldCastInterval or 0,
	}
	-- Nameplates by default (duel / world practice matches MiniCC).
	savedDb.TargetFocusOnly = false
	savedDb.Zones = {
		World = { Enabled = zoneEnabled.World ~= false },
		Arena = { Enabled = zoneEnabled.Arena ~= false },
		BattleGrounds = { Enabled = zoneEnabled.BattleGrounds ~= false },
		PvE = { Enabled = zoneEnabled.PvE == true },
	}
	-- Spells filled after defaults merge.
	savedDb.Spells = savedDb.Spells or {}
	savedDb.Version = 12
end

-- v13: watch nameplates by default; UnitIsEnemy failed for same-faction duels.
local function MigrateV13(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 13) then return end
	savedDb.TargetFocusOnly = false
	savedDb.Version = 13
end

-- v14: self-CC (debuffs on player) via AddAuraSound on unitToken=player.
local function MigrateV14(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 14) then return end
	savedDb.SelfCcEnabled = true
	savedDb.SelfCcSpells = savedDb.SelfCcSpells or {}
	savedDb.Version = 14
end

-- v16: multi voice-pack folders under Media\<name>\.
local function MigrateV16(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 16) then return end
	savedDb.VoicePack = savedDb.VoicePack or "夏一可1.25x"
	savedDb.ExtraVoicePacks = savedDb.ExtraVoicePacks or {}
	savedDb.Version = 16
end

-- v17: SelfCcEnabled checkbox → SelfCcScope dropdown (self / party).
local function MigrateV17(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 17) then return end
	if savedDb.SelfCcScope ~= "self" and savedDb.SelfCcScope ~= "party" then
		savedDb.SelfCcScope = "self"
	end
	savedDb.SelfCcEnabled = nil
	savedDb.Version = 17
end

-- v18: per-zone TargetFocusOnly (was a single global flag).
local function MigrateV18(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 18) then return end
	savedDb.Zones = savedDb.Zones or {}
	local global = savedDb.TargetFocusOnly
	local defaults = {
		World = true,
		Arena = false,
		BattleGrounds = true,
		PvE = true,
	}
	for key, defaultValue in pairs(defaults) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		if savedDb.Zones[key].TargetFocusOnly == nil then
			if global ~= nil then
				savedDb.Zones[key].TargetFocusOnly = global and true or false
			else
				savedDb.Zones[key].TargetFocusOnly = defaultValue
				end
			end
		end
	savedDb.TargetFocusOnly = nil
	savedDb.Version = 18
end

-- v19: per-zone CC enable + CcScope (was global SelfCcScope).
local function MigrateV19(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 19) then return end
	savedDb.Zones = savedDb.Zones or {}
	local scope = (savedDb.SelfCcScope == "party") and "party" or "self"
	local defaultsCc = {
		World = true,
		Arena = true,
		BattleGrounds = true,
		PvE = false,
	}
	for key, ccDefault in pairs(defaultsCc) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		local zone = savedDb.Zones[key]
		if zone.CcEnabled == nil then
			zone.CcEnabled = ccDefault
		end
		if zone.CcScope ~= "self" and zone.CcScope ~= "party" then
			zone.CcScope = scope
			end
		end
	savedDb.SelfCcScope = nil
	savedDb.Version = 19
end

-- v20: per-zone HealerCcEnabled (MiniAuras-style healer-in-CC alert).
local function MigrateV20(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 20) then return end
	savedDb.Zones = savedDb.Zones or {}
	local defaults = {
		World = true,
		Arena = true,
		BattleGrounds = true,
		PvE = false,
	}
	for key, def in pairs(defaults) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		if savedDb.Zones[key].HealerCcEnabled == nil then
			savedDb.Zones[key].HealerCcEnabled = def
		end
	end
	savedDb.Version = 20
end

-- v21: selectable healer-CC sound (v2.0.3 Media\ clips + voice-pack Sonar).
local function MigrateV21(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 21) then return end
	if type(savedDb.HealerCcSoundFile) ~= "string" or savedDb.HealerCcSoundFile == "" then
		local legacy = savedDb.Zones and savedDb.Zones.Arena and savedDb.Zones.Arena.HealerCCSoundFile
		if type(legacy) == "string" and legacy ~= "" then
			savedDb.HealerCcSoundFile = legacy
		else
			savedDb.HealerCcSoundFile = "夏一可_控制成功.ogg"
			end
		end
	savedDb.Version = 21
end

-- Coerce spell-id tables so SavedVariables string keys ("48707") match numeric lookups (48707).
local function NormalizeSpellIdKeys(spellTable)
	if type(spellTable) ~= "table" then return end
	local pending = {}
	for key, value in pairs(spellTable) do
		if type(key) == "string" then
			local numericId = tonumber(key)
			if numericId then
				pending[#pending + 1] = { old = key, id = numericId, value = value }
			end
		end
	end
	for i = 1, #pending do
		local entry = pending[i]
		spellTable[entry.old] = nil
		-- Keep an existing numeric entry; otherwise adopt the string-key value.
		if spellTable[entry.id] == nil then
			spellTable[entry.id] = entry.value and true or false
		end
		end
	end

-- v22: normalize Spells/SelfCcSpells keys + keep plain booleans for SavedVariables.
local function MigrateV22(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 22) then return end
	NormalizeSpellIdKeys(savedDb.Spells)
	NormalizeSpellIdKeys(savedDb.SelfCcSpells)
	savedDb.Version = 22
end

-- Copy legacy Spells/SelfCcSpells false entries into sparse disable maps.
local function MigrateLegacySpellMapsToDisabled(savedDb)
	savedDb.DisabledEnemySpells = savedDb.DisabledEnemySpells or {}
	savedDb.DisabledSelfCcSpells = savedDb.DisabledSelfCcSpells or {}
	if type(savedDb.Spells) == "table" then
		for key, enabled in pairs(savedDb.Spells) do
			local spellId = tonumber(key) or key
			if enabled == false then
				savedDb.DisabledEnemySpells[spellId] = true
			end
		end
	end
	if type(savedDb.SelfCcSpells) == "table" then
		for key, enabled in pairs(savedDb.SelfCcSpells) do
			local spellId = tonumber(key) or key
			if enabled == false then
				savedDb.DisabledSelfCcSpells[spellId] = true
			end
		end
		end
	end

-- v23: sparse DisabledEnemySpells / DisabledSelfCcSpells become the source of truth.
local function MigrateV23(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 23) then return end
	MigrateLegacySpellMapsToDisabled(savedDb)
	savedDb.Version = 23
end

-- v24: per-zone InterruptAlert + selectable InterruptSoundFile.
local function MigrateV24(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 24) then return end
	savedDb.Zones = savedDb.Zones or {}
	local defaults = {
		World = true,
		Arena = true,
		BattleGrounds = true,
		PvE = false,
	}
	for key, def in pairs(defaults) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		local zone = savedDb.Zones[key]
		if zone.InterruptAlert == nil then
			zone.InterruptAlert = def
		end
	end
	if type(savedDb.InterruptSoundFile) ~= "string" or savedDb.InterruptSoundFile == "" then
		savedDb.InterruptSoundFile = "interrupted.ogg"
	end
	savedDb.Version = 24
end

-- v25: healer-CC / interrupt dropdown = voice-pack clip + generic PS_* only.
local function MigrateV25(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 25) then return end
	local legacyHealer = {
		["夏一可_控制成功.ogg"] = true,
		["Sonar.ogg"] = true,
	}
	if type(savedDb.HealerCcSoundFile) ~= "string"
		or savedDb.HealerCcSoundFile == ""
		or legacyHealer[savedDb.HealerCcSoundFile]
	then
		savedDb.HealerCcSoundFile = "HealerCC.ogg"
	elseif savedDb.HealerCcSoundFile ~= "HealerCC.ogg"
		and not tostring(savedDb.HealerCcSoundFile):match("^PS_")
	then
		-- Unknown old value → fall back to pack clip.
		savedDb.HealerCcSoundFile = "HealerCC.ogg"
	end
	if type(savedDb.InterruptSoundFile) ~= "string" or savedDb.InterruptSoundFile == "" then
		savedDb.InterruptSoundFile = "interrupted.ogg"
	elseif savedDb.InterruptSoundFile ~= "interrupted.ogg"
		and not tostring(savedDb.InterruptSoundFile):match("^PS_")
		and savedDb.InterruptSoundFile ~= "夏一可_控制成功.ogg"
		and savedDb.InterruptSoundFile ~= "Sonar.ogg"
	then
		savedDb.InterruptSoundFile = "interrupted.ogg"
	elseif savedDb.InterruptSoundFile == "夏一可_控制成功.ogg"
		or savedDb.InterruptSoundFile == "Sonar.ogg"
	then
		-- Interrupt dropdown no longer offers these; keep interrupt on pack clip.
		savedDb.InterruptSoundFile = "interrupted.ogg"
	end
	savedDb.Version = 25
end

-- v26: rename pack healer clip HealerCC.ogg → HealerCcAlert.ogg (bust WoW sound cache).
local function MigrateV26(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 26) then return end
	if savedDb.HealerCcSoundFile == "HealerCC.ogg" or type(savedDb.HealerCcSoundFile) ~= "string"
		or savedDb.HealerCcSoundFile == ""
	then
		savedDb.HealerCcSoundFile = "HealerCcAlert.ogg"
	end
	savedDb.Version = 26
end

-- v27: multi-profile store (配置 page).
local function MigrateV27(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 27) then return end
	savedDb.Profiles = savedDb.Profiles or {}
	if type(savedDb.ActiveProfileName) ~= "string" then
		savedDb.ActiveProfileName = ""
	end
	savedDb.Version = 27
end

-- v28: system cast page — CastBar default on + SysCast preferred mode in profiles.
local function MigrateV28(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 28) then return end
	savedDb.SysCast = savedDb.SysCast or {}
	if savedDb.SysCast.PreferredMode == nil then
		local mode = tonumber(GetCVar and GetCVar("CAATargetCastMode")) or 1
		if mode < 1 then
			mode = 1
		end
		savedDb.SysCast.PreferredMode = mode
	end
	savedDb.Zones = savedDb.Zones or {}
	for _, key in ipairs({ "World", "Arena", "BattleGrounds", "PvE" }) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		-- Previous default was off; turn on for the new system-cast flow.
		savedDb.Zones[key].CastBar = true
	end
	savedDb.Version = 28
end

-- v29: per-zone ConsumableSay (honest /say when using listed potions).
local function MigrateV29(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 29) then return end
	savedDb.Zones = savedDb.Zones or {}
	for _, key in ipairs({ "World", "Arena", "BattleGrounds", "PvE" }) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		if savedDb.Zones[key].ConsumableSay == nil then
			savedDb.Zones[key].ConsumableSay = true
		end
	end
	savedDb.Version = 29
end

local function EnsureSysCastDefaults(savedDb)
	savedDb.SysCast = savedDb.SysCast or {}
	local mode = tonumber(savedDb.SysCast.PreferredMode)
	if mode == nil then
		savedDb.SysCast.PreferredMode = 1
	else
		if mode < 0 then mode = 0 end
		if mode > 2 then mode = 2 end
		savedDb.SysCast.PreferredMode = mode
	end
end

local function EnsureSpellDefaults(savedDb)
	-- Keep legacy maps present but empty-ish; runtime uses Disabled* maps.
	savedDb.Spells = savedDb.Spells or {}
	savedDb.DisabledEnemySpells = savedDb.DisabledEnemySpells or {}
	NormalizeSpellIdKeys(savedDb.Spells)
	NormalizeSpellIdKeys(savedDb.DisabledEnemySpells)
	MigrateLegacySpellMapsToDisabled(savedDb)
end

local function EnsureSelfCcDefaults(savedDb)
	savedDb.SelfCcSpells = savedDb.SelfCcSpells or {}
	savedDb.DisabledSelfCcSpells = savedDb.DisabledSelfCcSpells or {}
	NormalizeSpellIdKeys(savedDb.SelfCcSpells)
	NormalizeSpellIdKeys(savedDb.DisabledSelfCcSpells)
	MigrateLegacySpellMapsToDisabled(savedDb)
end

local function CopyDisableMap(src)
	local out = {}
	if type(src) ~= "table" then return out end
	for key, value in pairs(src) do
		if value then
			local spellId = tonumber(key) or key
			out[spellId] = true
		end
	end
	return out
end

local function EnsureZoneDefaults(savedDb)
	savedDb.Zones = savedDb.Zones or {}
	local defaults = {
		World = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
		Arena = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
		BattleGrounds = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
		PvE = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "party", HealerCcEnabled = true, InterruptAlert = false, CastBar = true, CastBarTargetOnly = true, ConsumableSay = true },
	}
	for key, def in pairs(defaults) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		local zone = savedDb.Zones[key]
		if zone.Enabled == nil then
			zone.Enabled = def.Enabled
		else
			zone.Enabled = zone.Enabled and true or false
		end
		if zone.TargetFocusOnly == nil then
			zone.TargetFocusOnly = def.TargetFocusOnly
		else
			zone.TargetFocusOnly = zone.TargetFocusOnly and true or false
		end
		if zone.CcEnabled == nil then
			zone.CcEnabled = def.CcEnabled
		else
			zone.CcEnabled = zone.CcEnabled and true or false
		end
		if zone.CcScope ~= "self" and zone.CcScope ~= "party" and zone.CcScope ~= "partyonly" then
			zone.CcScope = def.CcScope
		end
		if zone.HealerCcEnabled == nil then
			zone.HealerCcEnabled = def.HealerCcEnabled
		else
			zone.HealerCcEnabled = zone.HealerCcEnabled and true or false
		end
		if zone.InterruptAlert == nil then
			zone.InterruptAlert = def.InterruptAlert
		else
			zone.InterruptAlert = zone.InterruptAlert and true or false
		end
		if zone.CastBar == nil then
			zone.CastBar = def.CastBar
		else
			zone.CastBar = zone.CastBar and true or false
		end
		if zone.CastBarTargetOnly == nil then
			zone.CastBarTargetOnly = def.CastBarTargetOnly
		else
			zone.CastBarTargetOnly = zone.CastBarTargetOnly and true or false
		end
		if zone.ConsumableSay == nil then
			zone.ConsumableSay = def.ConsumableSay
		else
			zone.ConsumableSay = zone.ConsumableSay and true or false
		end
	end
end

-- ---------- UI helpers ----------

local channelItems = { "Master", "SFX", "Ambience", "Dialog", "Music" }

-- First entry = clip inside the selected voice pack; the rest are generic Media\ PS_* files.
local genericAlertSoundFiles = {
		"PS_Alert.ogg",
		"PS_Chime.ogg",
		"PS_Error.ogg",
		"PS_Horn.ogg",
		"PS_Impact.ogg",
		"PS_Ping.ogg",
		"PS_Pop.ogg",
		"PS_Radar.ogg",
		"PS_Shock.ogg",
		"PS_Swoosh.ogg",
		"PS_Warm.ogg",
}

local healerCcSoundFiles = { "HealerCcAlert.ogg" }
local interruptSoundFiles = { "interrupted.ogg" }
for i = 1, #genericAlertSoundFiles do
	healerCcSoundFiles[#healerCcSoundFiles + 1] = genericAlertSoundFiles[i]
	interruptSoundFiles[#interruptSoundFiles + 1] = genericAlertSoundFiles[i]
end

local MEDIA_ROOT = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

local function IsPackHealerClip(fileName)
	return fileName == "HealerCcAlert.ogg" or fileName == "HealerCC.ogg"
end

local function IsPackInterruptClip(fileName)
	return fileName == "interrupted.ogg"
end

local function ResolveHealerCcSoundPath(fileName)
	fileName = fileName or (db and db.HealerCcSoundFile) or "HealerCcAlert.ogg"
	if IsPackHealerClip(fileName) then
		return voicePack:Path("HealerCcAlert.ogg")
	end
	return MEDIA_ROOT .. fileName
end

local function PreviewHealerCcSound(fileName)
	local path = ResolveHealerCcSoundPath(fileName)
	if path then
		pcall(PlaySoundFile, path, db and db.Sound and db.Sound.Channel or "Master")
	end
end

local function HealerCcSoundLabel(fileName)
	if IsPackHealerClip(fileName) then
		return L["Healer CC Sound Pack"]
	end
	return (fileName or ""):gsub("%.ogg$", ""):gsub("%.mp3$", "")
end

local function ResolveInterruptSoundPath(fileName)
	fileName = fileName or (db and db.InterruptSoundFile) or "interrupted.ogg"
	if IsPackInterruptClip(fileName) then
		return voicePack:Path("interrupted.ogg")
	end
	return MEDIA_ROOT .. fileName
end

local function PreviewInterruptSound(fileName)
	local path = ResolveInterruptSoundPath(fileName)
	if path then
		pcall(PlaySoundFile, path, db and db.Sound and db.Sound.Channel or "Master")
	end
end

local function InterruptSoundLabel(fileName)
	if IsPackInterruptClip(fileName) then
		return L["Interrupt Sound Pack"]
	end
	return (fileName or ""):gsub("%.ogg$", ""):gsub("%.mp3$", "")
end

local function DoTest()
	AuraSounds():PlayTest(45438)
end

local function BuildHomeTab(content)
	local intro = mini:TextBlock({
		Parent = content,
		Lines = {
			L["home_intro_1"],
			L["home_intro_buff"],
			L["home_intro_debuff"],
			L["home_intro_healer"],
			L["home_intro_cast"],
			L["home_intro_consumable"],
			" ",
			L["home_intro_tts_warning"],
			" ",
			L["home_intro_7"],
		},
	})
	intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)

	local soundDivider = mini:Divider({
		Parent = content,
		Text = L["Sound Settings"],
	})
	soundDivider:SetPoint("LEFT", content, "LEFT")
	soundDivider:SetPoint("RIGHT", content, "RIGHT")
	soundDivider:SetPoint("TOP", intro, "BOTTOM", 0, -verticalSpacing)

	local packItems = voicePack:ListPacks()
	local hintFont = "GameFontWhite"
	local packLabel = mini:TextLine({
		Parent = content,
		Text = L["Voice Pack Select"],
	})
	packLabel:SetPoint("TOPLEFT", soundDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local packDropdown = mini:Dropdown({
		Parent = content,
		Items = packItems,
		Width = 200,
		GetValue = function()
			return voicePack:GetSelectedPack()
		end,
		SetValue = function(value)
			voicePack:SetSelectedPack(value)
			M:Apply()
		end,
		GetText = function(value)
			return value or voicePack:DefaultPack()
		end,
	})
	packDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	packDropdown:SetPoint("TOP", packLabel, "TOP", 0, 8)
	packDropdown:SetWidth(200)

	local packHint = mini:TextBlock({
		Parent = content,
		Font = hintFont,
		Lines = {
			L["Voice Pack Select Hint"],
			" ",
		},
	})
	packHint:SetPoint("TOPLEFT", packLabel, "BOTTOMLEFT", 0, -verticalSpacing)

	local channelLabel = mini:TextLine({
		Parent = content,
		Text = L["Output Channel"],
	})
	channelLabel:SetPoint("TOPLEFT", packHint, "BOTTOMLEFT", 0, -verticalSpacing)

	local channelDropdown = mini:Dropdown({
		Parent = content,
		Items = channelItems,
		Width = 200,
		GetValue = function()
			return db.Sound and db.Sound.Channel or "Master"
		end,
		SetValue = function(value)
			db.Sound = db.Sound or {}
			db.Sound.Channel = value
				M:Apply()
		end,
		GetText = function(value)
			local key = "channel_" .. (value or "Master")
			return L[key] or value or L["channel_Master"]
		end,
	})
	channelDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	channelDropdown:SetPoint("TOP", channelLabel, "TOP", 0, 8)
	channelDropdown:SetWidth(200)

	local channelHint = mini:TextBlock({
		Parent = content,
		Font = hintFont,
		Lines = {
			" ",
			L["Output Channel Hint"],
		},
	})
	channelHint:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, 0)

	local testBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	testBtn:SetSize(140, 26)
	testBtn:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -verticalSpacing * 2)
	testBtn:SetText(L["Test"])
	testBtn:SetScript("OnClick", DoTest)

	local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 26)
	resetBtn:SetPoint("LEFT", testBtn, "RIGHT", horizontalSpacing, 0)
	resetBtn:SetText(L["Reset"])
	resetBtn:SetScript("OnClick", function()
		if InCombatLockdown() then
			mini:NotifyCombatLockdown()
			return
		end
		ShowConfirm(L["Are you sure you wish to reset to factory settings?"], function()
				local keepProfiles = {}
				if type(db.Profiles) == "table" then
					for k, v in pairs(db.Profiles) do
						keepProfiles[k] = v
					end
				end
				local keepActive = db.ActiveProfileName
				dbDefaults.Spells = {}
				dbDefaults.SelfCcSpells = {}
				dbDefaults.DisabledEnemySpells = {}
				dbDefaults.DisabledSelfCcSpells = {}
				mini:ResetSavedVars(dbDefaults)
				db = mini:GetSavedVars()
				db.Profiles = keepProfiles
				if type(keepActive) == "string" then
					db.ActiveProfileName = keepActive
				end
				EnsureSpellDefaults(db)
				EnsureSelfCcDefaults(db)
				EnsureZoneDefaults(db)
				voicePack:Init()
				if addon.Modules.AuraSoundModule and addon.Modules.AuraSoundModule.InitDb then
					addon.Modules.AuraSoundModule:InitDb()
				end
				addon:Refresh()
				mini:Notify(L["Settings reset to default."])
			end)
	end)

	local diyDivider = mini:Divider({
		Parent = content,
		Text = L["Voice DIY Settings"],
	})
	diyDivider:SetPoint("LEFT", content, "LEFT")
	diyDivider:SetPoint("RIGHT", content, "RIGHT")
	diyDivider:SetPoint("TOP", testBtn, "BOTTOM", 0, -verticalSpacing * 2)

	local diyHint = mini:TextBlock({
		Parent = content,
		Font = hintFont,
		Lines = {
			L["Voice DIY Method"],
			L["Voice DIY Hint 1"],
			L["Voice DIY Hint 2"],
			L["Voice DIY Hint 3"],
			L["Voice DIY Hint 4"],
			L["Voice DIY Hint 5"],
			L["Voice DIY Hint Note"],
		},
	})
	diyHint:SetPoint("TOPLEFT", diyDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local customLabel = mini:TextLine({
		Parent = content,
		Text = L["Custom Voice Pack"],
	})
	customLabel:SetPoint("TOPLEFT", diyHint, "BOTTOMLEFT", 0, -verticalSpacing * 2)

	local customScratch = ""
	local customBox = mini:EditBox({
		Parent = content,
		Width = 160,
		GetValue = function()
			return customScratch
		end,
		SetValue = function(value)
			customScratch = value or ""
		end,
	})
	customBox:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	customBox:SetPoint("TOP", customLabel, "TOP", 0, 4)
	customBox:SetWidth(160)
	customBox:SetAutoFocus(false)

	local addPackBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	addPackBtn:SetSize(70, 22)
	addPackBtn:SetPoint("LEFT", customBox, "RIGHT", 8, 0)
	addPackBtn:SetText(L["Add"])
	addPackBtn:SetScript("OnClick", function()
		local name = customBox:GetText()
		if voicePack:RegisterExtraPack(name) then
			local trimmed = name:match("^%s*(.-)%s*$")
			voicePack:SetSelectedPack(trimmed)
			customScratch = ""
			customBox:SetText("")
			wipe(packItems)
			for _, n in ipairs(voicePack:ListPacks()) do
				packItems[#packItems + 1] = n
			end
			M:Apply()
			print("|cff33ff99[PVP Sound]|r " .. string.format(L["voice_pack_added"], trimmed, trimmed))
			print("|cff33ff99[PVP Sound]|r " .. L["voice_pack_reload_hint"])
		else
			print("|cff33ff99[PVP Sound]|r " .. L["voice_pack_add_failed"])
		end
	end)
end

local function BuildZonesTab(content)
	local intro = mini:TextBlock({
		Parent = content,
		Lines = {
			L["zones_intro_buff"],
			L["zones_intro_debuff"],
			L["zones_intro_interrupt"],
			L["zones_intro_consumable"],
			L["zones_intro_healer"],
			L["zones_intro_cast"],
		},
	})
	intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	local columnWidth = mini:ColumnWidth(2, 0, 0)
	-- Fixed right-column label width so every dropdown lines up (长标签如「打断成功音效」不再把框挤歪).
	local rightLabelWidth = 110
	local rightControlX = columnWidth + rightLabelWidth + 8
	local buffRangeItems = { "TargetFocus", "All" }
	local ccScopeItems = { "self", "partyonly", "party" }
	local last = intro
	local zoneOrder = {
		{ Key = "World", Label = L["World"] },
		{ Key = "Arena", Label = L["Arena"] },
		{ Key = "BattleGrounds", Label = L["Battlegrounds"] },
		{ Key = "PvE", Label = L["PvE"] },
	}

	---TextLine defaults to TextMaxWidth; shrink so dropdown can sit to its right.
	local function PlaceRangeRow(anchorChk, labelText, items, getValue, setValue, getText)
		local rangeLabel = mini:TextLine({
			Parent = content,
			Text = labelText,
		})
		rangeLabel:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
		rangeLabel:SetPoint("TOP", anchorChk, "TOP", 0, 0)
		rangeLabel:SetWidth(rightLabelWidth)
		rangeLabel:SetJustifyH("LEFT")

		local rangeDropdown = mini:Dropdown({
			Parent = content,
			Items = items,
			Width = 180,
			GetValue = getValue,
			SetValue = setValue,
			GetText = getText,
		})
		rangeDropdown:SetPoint("LEFT", content, "LEFT", rightControlX, 0)
		rangeDropdown:SetPoint("TOP", anchorChk, "TOP", 0, 8)
		rangeDropdown:SetWidth(180)
		return rangeDropdown
	end

	for _, z in ipairs(zoneOrder) do
		local zoneKey = z.Key
		local divider = mini:Divider({
			Parent = content,
			Text = z.Label,
		})
		divider:SetPoint("LEFT", content, "LEFT")
		divider:SetPoint("RIGHT", content, "RIGHT")
		divider:SetPoint("TOP", last, "BOTTOM", 0, -verticalSpacing * 2)

		-- Row 1: buff enable + buff monitor range
		local buffChk = mini:Checkbox({
			Parent = content,
			LabelText = L["Enable Buff Alerts"],
			Tooltip = L["Enable enemy buff voice alerts in this zone."],
			GetValue = function()
				return db.Zones[zoneKey] and db.Zones[zoneKey].Enabled
			end,
			SetValue = function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].Enabled = value and true or false
				M:Apply()
			end,
		})
		buffChk:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -verticalSpacing)

		PlaceRangeRow(
			buffChk,
			L["Monitor Range"],
			buffRangeItems,
			function()
				local zone = db.Zones[zoneKey]
				if zone and zone.TargetFocusOnly == false then
					return "All"
				end
				return "TargetFocus"
			end,
			function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].TargetFocusOnly = (value == "TargetFocus")
				M:Apply()
			end,
			function(value)
				if value == "All" then
					return L["Monitor Everyone"]
				end
				return L["Monitor Target Focus"]
			end
		)

		-- Row 2: debuff enable + debuff monitor scope
		local ccChk = mini:Checkbox({
		Parent = content,
			LabelText = L["Enable Debuff Alerts"],
			Tooltip = L["Enable self-debuff voice alerts in this zone."],
			GetValue = function()
				local zone = db.Zones[zoneKey]
				return zone and zone.CcEnabled ~= false
			end,
		SetValue = function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].CcEnabled = value and true or false
			M:Apply()
		end,
	})
		ccChk:SetPoint("TOPLEFT", buffChk, "BOTTOMLEFT", 0, -verticalSpacing)

		PlaceRangeRow(
			ccChk,
			L["Monitor Range"],
			ccScopeItems,
			function()
				local zone = db.Zones[zoneKey]
				local scope = zone and zone.CcScope
				if scope == "party" or scope == "partyonly" then
					return scope
				end
				return "self"
			end,
			function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				if value == "party" or value == "partyonly" then
					db.Zones[zoneKey].CcScope = value
				else
					db.Zones[zoneKey].CcScope = "self"
				end
			M:Apply()
		end,
			function(value)
				if value == "partyonly" then
					return L["Self CC Scope PartyOnly"]
				end
				if value == "party" then
					return L["Self CC Scope Party"]
				end
				return L["Self CC Scope Self"]
			end
		)

		-- Row 3: healer-in-CC (MiniAuras-style; always watches group healers)
		local healerChk = mini:Checkbox({
		Parent = content,
			LabelText = L["Enable Healer CC Alerts"],
			Tooltip = L["Enable healer-in-CC voice alerts in this zone."],
		GetValue = function()
				local zone = db.Zones[zoneKey]
				return zone and zone.HealerCcEnabled ~= false
		end,
		SetValue = function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].HealerCcEnabled = value and true or false
			M:Apply()
				if value then
					PreviewHealerCcSound(db.HealerCcSoundFile)
			end
		end,
	})
		healerChk:SetPoint("TOPLEFT", ccChk, "BOTTOMLEFT", 0, -verticalSpacing)

		PlaceRangeRow(
			healerChk,
			L["Healer CC Sound File"],
			healerCcSoundFiles,
			function()
				return db.HealerCcSoundFile or "HealerCcAlert.ogg"
			end,
			function(value)
				db.HealerCcSoundFile = value
			M:Apply()
				PreviewHealerCcSound(value)
		end,
			HealerCcSoundLabel
		)

		-- Row 4: system target-cast announce (gated per zone)
		local castChk = mini:Checkbox({
			Parent = content,
			LabelText = L["Enable Cast Alerts"],
			Tooltip = L["Enable cast voice alerts in this zone."],
			GetValue = function()
				local zone = db.Zones[zoneKey]
				return zone and zone.CastBar == true
			end,
			SetValue = function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].CastBar = value and true or false
				M:Apply()
			end,
		})
		castChk:SetPoint("TOPLEFT", healerChk, "BOTTOMLEFT", 0, -verticalSpacing)

		local castHint = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		castHint:SetText(L["SysCast Zone Hint"])
		castHint:SetTextColor(1, 0.82, 0)
		castHint:SetJustifyH("LEFT")
		castHint:SetPoint("LEFT", content, "LEFT", rightControlX, 0)
		castHint:SetPoint("TOP", castChk, "TOP", 0, -2)
		castHint:SetWidth(180)
		castHint:SetWordWrap(true)

		-- Row 5: interrupt alert (UNIT_SPELLCAST_INTERRUPTED) + shared sound picker
		local interruptChk = mini:Checkbox({
		Parent = content,
			LabelText = L["Enable Interrupt Alerts"],
			Tooltip = L["Enable interrupt voice alerts in this zone."],
		GetValue = function()
				local zone = db.Zones[zoneKey]
				return zone and zone.InterruptAlert == true
		end,
		SetValue = function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].InterruptAlert = value and true or false
			M:Apply()
				if value then
					PreviewInterruptSound(db.InterruptSoundFile)
			end
		end,
	})
		interruptChk:SetPoint("TOPLEFT", castChk, "BOTTOMLEFT", 0, -verticalSpacing)

		PlaceRangeRow(
			interruptChk,
			L["Interrupt Sound File"],
			interruptSoundFiles,
			function()
				return db.InterruptSoundFile or "interrupted.ogg"
			end,
			function(value)
				db.InterruptSoundFile = value
			M:Apply()
				PreviewInterruptSound(value)
			end,
			InterruptSoundLabel
		)

		-- Row 6: consumable honesty /say (self UNIT_SPELLCAST_SUCCEEDED)
		local consumableChk = mini:Checkbox({
			Parent = content,
			LabelText = L["Enable Consumable Say"],
			Tooltip = L["Enable consumable honesty alerts in this zone."],
			GetValue = function()
				local zone = db.Zones[zoneKey]
				return not zone or zone.ConsumableSay ~= false
			end,
			SetValue = function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].ConsumableSay = value and true or false
				M:Apply()
			end,
		})
		consumableChk:SetPoint("TOPLEFT", interruptChk, "BOTTOMLEFT", 0, -verticalSpacing)

		last = consumableChk
	end
end

-- ---------- System target-cast page (Accessibility → Audio Assistance mirror) ----------

local SYSCAST_MODE_ITEMS = { 0, 1, 2 }
local SYSCAST_FORMAT_ITEMS = { 0, 1, 2, 3, 4, 5, 6 }

local function SysCastEnums()
	local unit = (Enum and Enum.CombatAudioAlertUnit and Enum.CombatAudioAlertUnit.Target) or 1
	local alert = (Enum and Enum.CombatAudioAlertType and Enum.CombatAudioAlertType.Cast) or 1
	local cat = (Enum and Enum.CombatAudioAlertCategory and Enum.CombatAudioAlertCategory.TargetCast) or 4
	local throttle = (Enum and Enum.CombatAudioAlertThrottle and Enum.CombatAudioAlertThrottle.TargetCast) or 4
	return unit, alert, cat, throttle
end

local function SysCastAvailable()
	return C_CombatAudioAlert ~= nil
end

local function SysCastGetMaster()
	local CAA = C_CombatAudioAlert
	if CAA and CAA.IsEnabled then
		local ok, v = pcall(CAA.IsEnabled)
		if ok and v ~= nil then
			return v and true or false
		end
	end
	return (tonumber(GetCVar and GetCVar("CAAEnabled")) or 0) ~= 0
end

local function SysCastSetMaster(enabled)
	enabled = not not enabled
	local CAA = C_CombatAudioAlert
	if CAA and CAA.SetEnabled then
		pcall(CAA.SetEnabled, enabled)
	end
	pcall(SetCVar, "CAAEnabled", enabled and "1" or "0")
end

local function SysCastGetMode()
	return tonumber(GetCVar and GetCVar("CAATargetCastMode")) or 0
end

local function SysCastSetMode(mode)
	mode = tonumber(mode) or 0
	if mode < 0 then mode = 0 end
	if mode > 2 then mode = 2 end
	db = db or mini:GetSavedVars()
	db.SysCast = db.SysCast or {}
	db.SysCast.PreferredMode = mode
	if mode > 0 and not SysCastGetMaster() then
		SysCastSetMaster(true)
	end
	pcall(SetCVar, "CAATargetCastMode", tostring(mode))
	-- Re-apply zone gate (current zone may keep Mode off).
	if addon.Modules.SoundModule and addon.Modules.SoundModule.SyncSysCastZoneGate then
		addon.Modules.SoundModule:SyncSysCastZoneGate()
	end
end

local function SysCastGetFormat()
	local CAA = C_CombatAudioAlert
	local unit, alert = SysCastEnums()
	if CAA and CAA.GetFormatSetting then
		local ok, v = pcall(CAA.GetFormatSetting, unit, alert)
		if ok and v ~= nil then
			return tonumber(v) or 0
		end
	end
	return tonumber(GetCVar and GetCVar("CAATargetCastFormat")) or 0
end

local function SysCastSetFormat(fmt)
	fmt = tonumber(fmt) or 0
	if fmt < 0 then fmt = 0 end
	if fmt > 6 then fmt = 6 end
	local CAA = C_CombatAudioAlert
	local unit, alert = SysCastEnums()
	if CAA and CAA.SetFormatSetting then
		pcall(CAA.SetFormatSetting, unit, alert, fmt)
	end
	pcall(SetCVar, "CAATargetCastFormat", tostring(fmt))
end

local function SysCastGetVoice()
	local CAA = C_CombatAudioAlert
	local _, _, cat = SysCastEnums()
	if CAA and CAA.GetCategoryVoice then
		local ok, v = pcall(CAA.GetCategoryVoice, cat)
		if ok and v ~= nil then
			return tonumber(v) or 0
		end
	end
	return tonumber(GetCVar and GetCVar("CAAVoice")) or 0
end

local function SysCastSetVoice(voiceId)
	voiceId = tonumber(voiceId) or 0
	local CAA = C_CombatAudioAlert
	local _, _, cat = SysCastEnums()
	if CAA and CAA.SetCategoryVoice then
		pcall(CAA.SetCategoryVoice, cat, voiceId)
	end
end

local function SysCastGetVolume()
	local CAA = C_CombatAudioAlert
	local _, _, cat = SysCastEnums()
	if CAA and CAA.GetCategoryVolume then
		local ok, v = pcall(CAA.GetCategoryVolume, cat)
		if ok and v ~= nil then
			return tonumber(v) or 100
		end
	end
	return tonumber(GetCVar and GetCVar("CAAVolume")) or 100
end

local function SysCastSetVolume(vol)
	vol = tonumber(vol) or 100
	if vol < 0 then vol = 0 end
	if vol > 100 then vol = 100 end
	vol = math.floor(vol + 0.5)
	local CAA = C_CombatAudioAlert
	local _, _, cat = SysCastEnums()
	if CAA and CAA.SetCategoryVolume then
		pcall(CAA.SetCategoryVolume, cat, vol)
	end
end

local function SysCastGetThrottle()
	local CAA = C_CombatAudioAlert
	local _, _, _, throttleType = SysCastEnums()
	if CAA and CAA.GetThrottle then
		local ok, v = pcall(CAA.GetThrottle, throttleType)
		if ok and v ~= nil then
			return tonumber(v) or 0
		end
	end
	return tonumber(GetCVar and GetCVar("CAATargetCastThrottle")) or 0
end

local function SysCastSetThrottle(sec)
	sec = tonumber(sec) or 0
	if sec < 0 then sec = 0 end
	if sec > 10 then sec = 10 end
	sec = tonumber(string.format("%.1f", sec)) or sec
	local CAA = C_CombatAudioAlert
	local _, _, _, throttleType = SysCastEnums()
	if CAA and CAA.SetThrottle then
		pcall(CAA.SetThrottle, throttleType, sec)
	end
	pcall(SetCVar, "CAATargetCastThrottle", tostring(sec))
end

local function SysCastGetMinTime()
	return tonumber(GetCVar and GetCVar("CAATargetCastMinTime")) or 0.5
end

local function SysCastSetMinTime(sec)
	sec = tonumber(sec) or 0.5
	if sec < 0 then sec = 0 end
	if sec > 10 then sec = 10 end
	sec = tonumber(string.format("%.1f", sec)) or sec
	pcall(SetCVar, "CAATargetCastMinTime", tostring(sec))
end

local function SysCastModeLabel(mode)
	mode = tonumber(mode) or 0
	if mode == 1 then return L["SysCast Mode Start"] end
	if mode == 2 then return L["SysCast Mode End"] end
	return L["SysCast Mode Off"]
end

local function SysCastFormatLabel(fmt)
	fmt = tonumber(fmt) or 0
	local key = "SysCast Format " .. tostring(fmt)
	return L[key] or tostring(fmt)
end

local function SysCastBuildVoiceItems()
	local items = {}
	local names = {}
	local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or nil
	if voices then
		for _, v in ipairs(voices) do
			if v and v.voiceID ~= nil then
				items[#items + 1] = v.voiceID
				names[v.voiceID] = v.name or tostring(v.voiceID)
			end
		end
		table.sort(items, function(a, b)
			return (names[a] or tostring(a)) < (names[b] or tostring(b))
		end)
	end
	if #items == 0 then
		local cur = SysCastGetVoice()
		items[1] = cur
		names[cur] = tostring(cur)
	end
	return items, names
end

local function BuildSysCastTab(content)
	if not SysCastAvailable() then
		local missing = mini:TextBlock({
			Parent = content,
			Lines = {
				L["SysCast Unavailable"],
			},
		})
		missing:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
		return
	end

	local intro = mini:TextBlock({
		Parent = content,
		Lines = {
			L["syscast_intro_1"],
			L["syscast_intro_2"],
			L["syscast_intro_3"],
			L["syscast_intro_4"],
		},
	})
	intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	local warn = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	warn:SetJustifyH("LEFT")
	warn:SetWordWrap(true)
	warn:SetWidth(mini.TextMaxWidth or 520)
	warn:SetTextColor(1, 0.2, 0.2)
	warn:SetText(L["syscast_intro_warn"])
	warn:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -verticalSpacing)

	local divider = mini:Divider({
		Parent = content,
		Text = L["SysCast Settings"],
	})
	divider:SetPoint("LEFT", content, "LEFT")
	divider:SetPoint("RIGHT", content, "RIGHT")
	divider:SetPoint("TOP", warn, "BOTTOM", 0, -verticalSpacing * 1.5)

	local columnWidth = mini:ColumnWidth(2, 0, 0)
	local controlWidth = 260

	local function PlaceLabeledDropdown(anchor, labelText, items, getValue, setValue, getText, gridMode)
		local label = mini:TextLine({
			Parent = content,
			Text = labelText,
		})
		label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -verticalSpacing * 1.5)
		label:SetWidth(math.max(1, label:GetStringWidth() + 2))

		local dropdown = mini:Dropdown({
			Parent = content,
			Items = items,
			Width = controlWidth,
			GridMode = gridMode,
			GetValue = getValue,
			SetValue = setValue,
			GetText = getText,
		})
		dropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
		dropdown:SetPoint("TOP", label, "TOP", 0, 8)
		dropdown:SetWidth(controlWidth)
		return label, dropdown
	end

	local masterChk = mini:Checkbox({
		Parent = content,
		LabelText = L["SysCast Master"],
		Tooltip = L["SysCast Master Tooltip"],
		GetValue = function()
			return SysCastGetMaster()
		end,
		SetValue = function(value)
			SysCastSetMaster(value and true or false)
		end,
	})
	masterChk:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -verticalSpacing)

	local modeLabel = PlaceLabeledDropdown(
		masterChk,
		L["SysCast Announce Target"],
		SYSCAST_MODE_ITEMS,
		function()
			db = db or mini:GetSavedVars()
			if db.SysCast and db.SysCast.PreferredMode ~= nil then
				return tonumber(db.SysCast.PreferredMode) or 0
			end
			return SysCastGetMode()
		end,
		function(value)
			SysCastSetMode(value)
		end,
		SysCastModeLabel
	)

	local formatLabel = PlaceLabeledDropdown(
		modeLabel,
		L["SysCast Format"],
		SYSCAST_FORMAT_ITEMS,
		function()
			return SysCastGetFormat()
		end,
		function(value)
			SysCastSetFormat(value)
		end,
		SysCastFormatLabel
	)

	local voiceItems, voiceNames = SysCastBuildVoiceItems()
	local voiceLabel = PlaceLabeledDropdown(
		formatLabel,
		L["SysCast Voice"],
		voiceItems,
		function()
			return SysCastGetVoice()
		end,
		function(value)
			SysCastSetVoice(value)
		end,
		function(value)
			return voiceNames[value] or tostring(value)
		end,
		true
	)

	local minDivider = mini:Divider({
		Parent = content,
		Text = L["SysCast Min Time"],
	})
	minDivider:SetPoint("LEFT", content, "LEFT")
	minDivider:SetPoint("RIGHT", content, "RIGHT")
	minDivider:SetPoint("TOP", voiceLabel, "BOTTOM", 0, -verticalSpacing * 2)

	local minSlider = mini:Slider({
		Parent = content,
		Min = 0,
		Max = 5,
		Step = 0.1,
		Width = (columnWidth * 2) - 80,
		LabelText = "",
		GetValue = function()
			return SysCastGetMinTime()
		end,
		SetValue = function(v)
			SysCastSetMinTime(v)
		end,
	})
	minSlider.Slider:SetPoint("TOPLEFT", minDivider, "BOTTOMLEFT", 4, -verticalSpacing)

	local throttleDivider = mini:Divider({
		Parent = content,
		Text = L["SysCast Interval"],
	})
	throttleDivider:SetPoint("LEFT", content, "LEFT")
	throttleDivider:SetPoint("RIGHT", content, "RIGHT")
	throttleDivider:SetPoint("TOP", minSlider.Slider, "BOTTOM", 0, -verticalSpacing * 2)

	local throttleSlider = mini:Slider({
		Parent = content,
		Min = 0,
		Max = 5,
		Step = 0.1,
		Width = (columnWidth * 2) - 80,
		LabelText = "",
		GetValue = function()
			return SysCastGetThrottle()
		end,
		SetValue = function(v)
			SysCastSetThrottle(v)
		end,
	})
	throttleSlider.Slider:SetPoint("TOPLEFT", throttleDivider, "BOTTOMLEFT", 4, -verticalSpacing)

	local volDivider = mini:Divider({
		Parent = content,
		Text = L["SysCast Volume"],
	})
	volDivider:SetPoint("LEFT", content, "LEFT")
	volDivider:SetPoint("RIGHT", content, "RIGHT")
	volDivider:SetPoint("TOP", throttleSlider.Slider, "BOTTOM", 0, -verticalSpacing * 2)

	local volSlider = mini:Slider({
		Parent = content,
		Min = 0,
		Max = 100,
		Step = 1,
		Width = (columnWidth * 2) - 80,
		LabelText = "",
		GetValue = function()
			return SysCastGetVolume()
		end,
		SetValue = function(v)
			SysCastSetVolume(v)
		end,
	})
	volSlider.Slider:SetPoint("TOPLEFT", volDivider, "BOTTOMLEFT", 4, -verticalSpacing)

	local preview = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	preview:SetSize(120, 22)
	preview:SetText(L["SysCast Preview"])
	preview:SetPoint("TOPLEFT", volSlider.Slider, "BOTTOMLEFT", -4, -verticalSpacing * 2)
	preview:SetScript("OnClick", function()
		local CAA = C_CombatAudioAlert
		if not CAA or not CAA.SpeakText then return end
		local _, _, cat = SysCastEnums()
		pcall(CAA.SpeakText, L["SysCast Preview Text"], cat, true)
	end)
end

---@param spellId number
---@param fallbackName string?
local function SpellLabel(spellId, fallbackName, overrideName)
	local name = overrideName
	if not name or name == "" then
		name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
	end
	local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId)
	name = name or fallbackName
	if name and icon then
		return string.format("|T%s:20:20:0:0|t %s", icon, name)
	end
	if name then
		return name
	end
	return string.format("Spell %d", spellId)
end

local CLASS_ORDER = {
	"General",
	"DeathKnight",
	"DemonHunter",
	"Druid",
	"Evoker",
	"Hunter",
	"Mage",
	"Monk",
	"Paladin",
	"Priest",
	"Rogue",
	"Shaman",
	"Warlock",
	"Warrior",
}

---Collapse same File into one UI row (enemy buff + self-CC share one checkbox).
---@param spells table[]
---@return table[]
local function DedupeSpells(spells)
	local order = {}
	local byKey = {}
	for _, spell in ipairs(spells) do
		local key = spell.File or ("id:" .. tostring(spell.Id))
		local group = byKey[key]
		local mode = spell.Mode or "enemy"
		if not group then
			group = {
				Id = spell.Id,
				File = spell.File,
				Name = spell.Name,
				Label = spell.Label,
				Mode = mode,
				Modes = {},
				Ids = {},
			}
			byKey[key] = group
			order[#order + 1] = group
		end
		group.Modes[mode] = true
		if spell.Name and not group.Name then
			group.Name = spell.Name
		end
		-- Prefer a named / selfcc primary Id for the label when available.
		if mode == "selfcc" and spell.Id then
			group.Id = spell.Id
		end
		group.Ids[spell.Id] = true
		if spell.Ids then
			for id in pairs(spell.Ids) do
				group.Ids[id] = true
			end
		end
	end
	return order
end

local function SpellUsesSelfCc(spell)
	if not spell then return false end
	if spell.Modes then return spell.Modes.selfcc == true end
	return spell.Mode == "selfcc"
end

local function SpellUsesEnemy(spell)
	if not spell then return false end
	if spell.Modes then return spell.Modes.enemy == true end
	return spell.Mode ~= "selfcc"
end

local function SpellIdList(spell)
	local ids = {}
	local seen = {}
	local function add(id)
		id = tonumber(id) or id
		if id == nil or seen[id] then return end
		seen[id] = true
		ids[#ids + 1] = id
	end
	if spell then
		if spell.Ids then
			for id in pairs(spell.Ids) do
				add(id)
			end
		end
		add(spell.Id)
	end
	return ids
end

local function IsEnemySpellEnabled(spellId)
	spellId = tonumber(spellId) or spellId
	if not db then return true end
	if db.DisabledEnemySpells and db.DisabledEnemySpells[spellId] then
		return false
	end
	-- Legacy fallback while old Spells maps still exist.
	if db.Spells and db.Spells[spellId] == false then
		return false
	end
	return true
end

local function IsSelfCcSpellEnabled(spellId)
	spellId = tonumber(spellId) or spellId
	if not db then return true end
	if db.DisabledSelfCcSpells and db.DisabledSelfCcSpells[spellId] then
		return false
	end
	if db.SelfCcSpells and db.SelfCcSpells[spellId] == false then
		return false
	end
	return true
end

local function IsMergedSpellEnabled(spell)
	local ok = true
	local ids = SpellIdList(spell)
	local primary = ids[1] or (spell and spell.Id)
	if SpellUsesSelfCc(spell) then
		ok = ok and IsSelfCcSpellEnabled(primary)
	end
	if SpellUsesEnemy(spell) then
		ok = ok and IsEnemySpellEnabled(primary)
	end
	return ok and true or false
end

local function SetMergedSpellEnabled(spell, enabled)
	-- Always write through Config's SavedVariables reference (plain booleans only).
	db = db or mini:GetSavedVars()
	_G.PVPSoundDB = _G.PVPSoundDB or db
	db = _G.PVPSoundDB

	local value = enabled and true or false
	local ids = SpellIdList(spell)

	if SpellUsesEnemy(spell) then
		db.DisabledEnemySpells = db.DisabledEnemySpells or {}
		db.Spells = db.Spells or {}
		for i = 1, #ids do
			local spellId = ids[i]
			if value then
				db.DisabledEnemySpells[spellId] = nil
			else
				db.DisabledEnemySpells[spellId] = true
			end
			-- Keep legacy map in sync for any old readers.
			db.Spells[spellId] = value
		end
	end

	if SpellUsesSelfCc(spell) then
		db.DisabledSelfCcSpells = db.DisabledSelfCcSpells or {}
		db.SelfCcSpells = db.SelfCcSpells or {}
		for i = 1, #ids do
			local spellId = ids[i]
			if value then
				db.DisabledSelfCcSpells[spellId] = nil
			else
				db.DisabledSelfCcSpells[spellId] = true
			end
			db.SelfCcSpells[spellId] = value
		end
	end

	local aura = AuraSounds()
	if aura then
		if aura.InitDb then aura:InitDb() end
		if aura.Refresh then aura:Refresh("spell-toggle") end
	end
end

---Merge enemy-buff + self-CC catalogs into one class list for the Spells tab.
---@return table[] { Key, Name, Spells = { { Id, File, Mode, Ids? }, ... } }
local function BuildMergedClasses()
	local byKey = {}

	local function Ensure(key, name)
		if not byKey[key] then
			byKey[key] = { Key = key, Name = name, Spells = {} }
		end
		return byKey[key]
	end

	if catalog and catalog.Classes then
		for _, classEntry in ipairs(catalog.Classes) do
			local entry = Ensure(classEntry.Key, classEntry.Name)
			for _, spell in ipairs(classEntry.Spells) do
				entry.Spells[#entry.Spells + 1] = {
					Id = spell.Id,
					File = spell.File,
					Mode = "enemy",
					Name = spell.Name,
					Label = spell.Label,
				}
			end
		end
	end

	if selfCcCatalog and selfCcCatalog.Classes then
		for _, classEntry in ipairs(selfCcCatalog.Classes) do
			local entry = Ensure(classEntry.Key, classEntry.Name)
			for _, spell in ipairs(classEntry.Spells) do
				entry.Spells[#entry.Spells + 1] = {
					Id = spell.Id,
					File = spell.File,
					Mode = "selfcc",
					Ids = spell.Ids,
				}
			end
		end
	end

	local list = {}
	local seen = {}
	for _, key in ipairs(CLASS_ORDER) do
		if byKey[key] and #byKey[key].Spells > 0 then
			byKey[key].Spells = DedupeSpells(byKey[key].Spells)
			list[#list + 1] = byKey[key]
			seen[key] = true
		end
	end
	for key, entry in pairs(byKey) do
		if not seen[key] and #entry.Spells > 0 then
			entry.Spells = DedupeSpells(entry.Spells)
			list[#list + 1] = entry
		end
	end
	return list
end

---@param spells table[]
---@return table[] buffs
---@return table[] ccs
local function SplitClassSpells(spells)
	local buffs, ccs = {}, {}
	for _, spell in ipairs(spells) do
		-- Prefer CC section when a row is (also) self-CC — avoids CC showing under buffs.
		if SpellUsesSelfCc(spell) then
			ccs[#ccs + 1] = spell
		elseif SpellUsesEnemy(spell) then
			buffs[#buffs + 1] = spell
		end
	end
	return buffs, ccs
end

---One category block: optional divider + select all/none + 2-col checkboxes.
---@param parent Frame
---@param anchor Region
---@param spells table[]
---@param dividerText string?
---@return Region bottom
local function BuildSpellGroup(parent, anchor, spells, dividerText)
	if not spells or #spells == 0 then
		return anchor
	end

	local last = anchor
	if dividerText then
		local divider = mini:Divider({
			Parent = parent,
			Text = dividerText,
		})
		divider:SetPoint("LEFT", parent, "LEFT")
		divider:SetPoint("RIGHT", parent, "RIGHT")
		divider:SetPoint("TOP", anchor, "BOTTOM", 0, -verticalSpacing)
		last = divider
	end

	local selectAll = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	selectAll:SetSize(100, 22)
	selectAll:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -verticalSpacing)
	selectAll:SetText(L["Select All"])
	selectAll:SetScript("OnClick", function()
		for _, spell in ipairs(spells) do
			SetMergedSpellEnabled(spell, true)
		end
		if parent.MiniRefresh then parent:MiniRefresh() end
	end)

	local selectNone = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	selectNone:SetSize(100, 22)
	selectNone:SetPoint("LEFT", selectAll, "RIGHT", horizontalSpacing, 0)
	selectNone:SetText(L["Select None"])
	selectNone:SetScript("OnClick", function()
		for _, spell in ipairs(spells) do
			SetMergedSpellEnabled(spell, false)
		end
		if parent.MiniRefresh then parent:MiniRefresh() end
	end)

	local columns = 2
	local columnWidth = mini:ColumnWidth(columns, 0, 0)
	local lastLeft, lastRight = selectAll, selectAll

	for i, spell in ipairs(spells) do
		local spellId = spell.Id
		local file = spell.File
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)

		local chk = mini:Checkbox({
			Parent = parent,
			LabelText = SpellLabel(spellId, spell.Name, spell.Label),
			Tooltip = string.format(L["spell_toggle_tooltip"], spellId, file),
		GetValue = function()
				return IsMergedSpellEnabled(spell)
		end,
		SetValue = function(value)
				SetMergedSpellEnabled(spell, value and true or false)
				if value then
					local path = voicePack:Path(file)
					if path then
						pcall(PlaySoundFile, path, db.Sound and db.Sound.Channel or "Master")
					end
			end
		end,
	})

		chk:HookScript("OnEnter", function(self)
			if C_Spell and C_Spell.GetSpellLink then
				local link = C_Spell.GetSpellLink(spellId)
				if link then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetHyperlink(link)
					GameTooltip:Show()
				end
			end
		end)

		if col == 0 then
			if row == 0 then
				chk:SetPoint("TOPLEFT", selectAll, "BOTTOMLEFT", 0, -verticalSpacing)
			else
				chk:SetPoint("TOPLEFT", lastLeft, "BOTTOMLEFT", 0, -4)
			end
			lastLeft = chk
		else
			if row == 0 then
				chk:SetPoint("TOPLEFT", selectAll, "BOTTOMLEFT", columnWidth + horizontalSpacing, -verticalSpacing)
			else
				chk:SetPoint("TOPLEFT", lastRight, "BOTTOMLEFT", 0, -4)
			end
			lastRight = chk
		end
	end

	return lastLeft
end

---@param parent Frame
---@param anchor Region


local function ConsumableLabel(entry)
	local name = (entry and (entry.zh or entry.en)) or ""
	local icon
	if entry and entry.spellID and C_Spell and C_Spell.GetSpellTexture then
		icon = C_Spell.GetSpellTexture(entry.spellID)
	end
	if (not icon) and entry and entry.itemID then
		if C_Item and C_Item.GetItemIconByID then
			icon = C_Item.GetItemIconByID(entry.itemID)
		elseif GetItemIcon then
			icon = GetItemIcon(entry.itemID)
		end
	end
	if name ~= "" and icon then
		return string.format("|T%s:20:20:0:0|t %s", icon, name)
	end
	return name
end

local function BuildConsumableWatchSection(parent, anchor)
	local data = addon.Data.Consumables
	local list = data and data.List
	if not list or #list == 0 then
		return anchor
	end

	local divider = mini:Divider({
		Parent = parent,
		Text = L["spell_group_consumables"],
	})
	divider:SetPoint("LEFT", parent, "LEFT")
	divider:SetPoint("RIGHT", parent, "RIGHT")
	divider:SetPoint("TOP", anchor, "BOTTOM", 0, -verticalSpacing * 2)

	local columns = 2
	local columnWidth = mini:ColumnWidth(columns, 0, 0)
	local lastLeft, lastRight = divider, divider

	for i, entry in ipairs(list) do
		local name = entry.zh or entry.en or ""
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local itemID = entry.itemID
		local spellID = entry.spellID
		local chk = mini:Checkbox({
			Parent = parent,
			LabelText = ConsumableLabel(entry),
			GetValue = function()
				return true
			end,
			SetValue = function()
			end,
		})
		-- Keep mouse so hover tooltip works; click cannot uncheck.
		chk:SetScript("OnClick", function(self)
			self:SetChecked(true)
		end)
		chk:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local shown = false
			if itemID then
				local ok = pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
				shown = ok and true or false
			end
			if (not shown) and spellID then
				if GameTooltip.SetSpellByID then
					local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
					shown = ok and true or false
				end
				if (not shown) and C_Spell and C_Spell.GetSpellLink then
					local link = C_Spell.GetSpellLink(spellID)
					if link then
						pcall(GameTooltip.SetHyperlink, GameTooltip, link)
						shown = true
					end
				end
			end
			if not shown then
				GameTooltip:SetText(name, 1, 0.82, 0)
				GameTooltip:AddLine(L["consumable_watch_locked_tooltip"], 1, 1, 1, true)
			end
			GameTooltip:Show()
		end)
		chk:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		if col == 0 then
			if row == 0 then
				chk:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -verticalSpacing)
			else
				chk:SetPoint("TOPLEFT", lastLeft, "BOTTOMLEFT", 0, -4)
			end
			lastLeft = chk
		else
			if row == 0 then
				chk:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", columnWidth + horizontalSpacing, -verticalSpacing)
			else
				chk:SetPoint("TOPLEFT", lastRight, "BOTTOMLEFT", 0, -4)
			end
			lastRight = chk
		end
	end

	return lastLeft
end

---@param classEntry table
---@param opts table? { showDivider = boolean?, splitCategories = boolean? }
---@return Region bottom
local function BuildClassSection(parent, anchor, classEntry, opts)
	opts = opts or {}
	local last = anchor

	if opts.showDivider ~= false then
		local divider = mini:Divider({
			Parent = parent,
			Text = L[classEntry.Name] or classEntry.Name,
		})
		divider:SetPoint("LEFT", parent, "LEFT")
		divider:SetPoint("RIGHT", parent, "RIGHT")
		divider:SetPoint("TOP", anchor, "BOTTOM", 0, -verticalSpacing * 2)
		last = divider
	end

	local buffs, ccs = SplitClassSpells(classEntry.Spells)
	local debuffTitle = (classEntry.Key == "General") and L["spell_group_debuffs_general"] or L["spell_group_debuffs"]

	if opts.splitCategories ~= false then
		last = BuildSpellGroup(parent, last, buffs, L["spell_group_buffs"])
		last = BuildSpellGroup(parent, last, ccs, debuffTitle)
		return last
	end

	-- Fallback: single list (unused; keep for safety).
	local all = {}
	for i = 1, #buffs do all[#all + 1] = buffs[i] end
	for i = 1, #ccs do all[#all + 1] = ccs[i] end
	return BuildSpellGroup(parent, last, all, nil)
end

---Run the same migration chain used at Init, so imported/old snapshots upgrade.
local function MigrateSettingsSnapshot(savedDb)
	if type(savedDb) ~= "table" then return end
	MigrateV1(savedDb)
	MigrateThroughV11(savedDb)
	MigrateV13(savedDb)
	MigrateV14(savedDb)
	MigrateV16(savedDb)
	MigrateV17(savedDb)
	MigrateV18(savedDb)
	MigrateV19(savedDb)
	MigrateV20(savedDb)
	MigrateV21(savedDb)
	MigrateV22(savedDb)
	MigrateV23(savedDb)
	MigrateV24(savedDb)
	MigrateV25(savedDb)
	MigrateV26(savedDb)
	MigrateV27(savedDb)
	MigrateV28(savedDb)
	MigrateV29(savedDb)
end

local function RefreshFrameTree(frame)
	if not frame then
		return
	end
	if frame.MiniRefresh then
		pcall(frame.MiniRefresh, frame)
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		RefreshFrameTree(children[i])
	end
end

local function AfterSettingsMutated(notifyMsg)
	-- Always bind to the live SavedVariables table.
	db = mini:GetSavedVars()
	_G.PVPSoundDB = db
	EnsureSpellDefaults(db)
	EnsureSelfCcDefaults(db)
	EnsureZoneDefaults(db)
	EnsureSysCastDefaults(db)
	voicePack:Init()
	if addon.Modules.AuraSoundModule and addon.Modules.AuraSoundModule.InitDb then
		addon.Modules.AuraSoundModule:InitDb()
	end
	if addon.Modules.SoundModule then
		if addon.Modules.SoundModule.Refresh then
			pcall(function()
				addon.Modules.SoundModule:Refresh()
			end)
		end
	end
	addon:Refresh()
	if M.TabController and M.TabController.Tabs then
		for _, tab in ipairs(M.TabController.Tabs) do
			RefreshFrameTree(tab.Content)
		end
	end
	if notifyMsg then
		mini:Notify(notifyMsg)
	end
end

local function ApplySettingsSnapshot(snap, notifyMsg)
	if type(snap) ~= "table" then
		return false
	end
	db = mini:GetSavedVars()
	_G.PVPSoundDB = db
	-- Keep sparse disable maps from the raw snapshot (before defaults fill).
	local keepDisabledEnemy = CopyDisableMap(snap.DisabledEnemySpells)
	local keepDisabledSelfCc = CopyDisableMap(snap.DisabledSelfCcSpells)
	local copy = profiles:DeepCopy(snap)
	MigrateSettingsSnapshot(copy)
	-- Fill missing keys from defaults without wiping Profiles.
	mini:CopyTable(dbDefaults, copy)
	-- Defaults use empty {} disable maps; restore snapshot disables after fill.
	copy.DisabledEnemySpells = keepDisabledEnemy
	copy.DisabledSelfCcSpells = keepDisabledSelfCc
	profiles:ApplySettings(db, copy)
	db.DisabledEnemySpells = CopyDisableMap(keepDisabledEnemy)
	db.DisabledSelfCcSpells = CopyDisableMap(keepDisabledSelfCc)
	db.Spells = {}
	db.SelfCcSpells = {}
	for spellId in pairs(db.DisabledEnemySpells) do
		db.Spells[spellId] = false
	end
	for spellId in pairs(db.DisabledSelfCcSpells) do
		db.SelfCcSpells[spellId] = false
	end
	db.Version = dbDefaults.Version
	AfterSettingsMutated(notifyMsg)
	return true
end

local function BuildProfilesTab(content)
	local intro = mini:TextBlock({
			Parent = content,
		Lines = {
			L["profiles_intro_1"],
			L["profiles_intro_2"],
		},
	})
	intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	local columnWidth = mini:ColumnWidth(2, 0, 0)
	local nameScratch = ""
	local exportScratch = ""
	local selectedName = db.ActiveProfileName or ""

	local function ProfileItems()
		return profiles:ListNames(db)
	end

	local schemeDivider = mini:Divider({
			Parent = content,
		Text = L["profiles_section_schemes"],
	})
	schemeDivider:SetPoint("LEFT", content, "LEFT")
	schemeDivider:SetPoint("RIGHT", content, "RIGHT")
	schemeDivider:SetPoint("TOP", intro, "BOTTOM", 0, -verticalSpacing)

	local activeLabel = mini:TextLine({
			Parent = content,
		Text = L["profiles_active"],
	})
	activeLabel:SetPoint("TOPLEFT", schemeDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local profileItems = ProfileItems()
	if selectedName == "" and profileItems[1] then
		selectedName = profileItems[1]
	end

	local profileDropdown = mini:Dropdown({
			Parent = content,
		Items = profileItems,
		Width = 200,
			GetValue = function()
			return selectedName
			end,
			SetValue = function(value)
			selectedName = value or ""
			nameScratch = selectedName
			end,
			GetText = function(value)
			if value and value ~= "" then
				return value
				end
			return L["profiles_none"]
			end,
		})
	profileDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	profileDropdown:SetPoint("TOP", activeLabel, "TOP", 0, 8)
	profileDropdown:SetWidth(200)

	local nameLabel = mini:TextLine({
			Parent = content,
		Text = L["profiles_name"],
		})
	nameLabel:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 0, -verticalSpacing)

	local nameBox = mini:EditBox({
			Parent = content,
			Width = 200,
			GetValue = function()
			return nameScratch
			end,
			SetValue = function(value)
			nameScratch = value or ""
			end,
		})
	nameBox:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	nameBox:SetPoint("TOP", nameLabel, "TOP", 0, 4)
	nameBox:SetWidth(200)

	local function RefreshProfileDropdown()
		wipe(profileItems)
		for _, n in ipairs(ProfileItems()) do
			profileItems[#profileItems + 1] = n
		end
		if profileDropdown.MiniRefresh then
			profileDropdown:MiniRefresh()
		end
		if nameBox.MiniRefresh then
			nameBox:MiniRefresh()
		end
	end

	local saveBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	saveBtn:SetSize(120, 24)
	saveBtn:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -verticalSpacing)
	saveBtn:SetText(L["profiles_save"])
	saveBtn:SetScript("OnClick", function()
		local name = (nameScratch ~= "" and nameScratch) or selectedName
		name = (name or ""):match("^%s*(.-)%s*$") or ""
		if name == "" then
			mini:Notify(L["profiles_need_name"])
			return
		end
		if profiles:Save(db, name) then
			selectedName = name
			nameScratch = name
			RefreshProfileDropdown()
			mini:Notify(string.format(L["profiles_saved"], name))
		else
			mini:Notify(L["profiles_need_name"])
		end
	end)

	local loadBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	loadBtn:SetSize(120, 24)
	loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", horizontalSpacing, 0)
	loadBtn:SetText(L["profiles_load"])
	loadBtn:SetScript("OnClick", function()
		local name = selectedName
		if not name or name == "" then
			mini:Notify(L["profiles_need_select"])
			return
		end
		local snap = profiles:Get(db, name)
		if not snap then
			mini:Notify(L["profiles_missing"])
			return
		end
		ShowConfirm(string.format(L["profiles_load_confirm"], name), function()
				db.ActiveProfileName = name
				ApplySettingsSnapshot(snap, string.format(L["profiles_loaded"], name))
				nameScratch = name
				RefreshProfileDropdown()
			end)
	end)

	local deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	deleteBtn:SetSize(120, 24)
	deleteBtn:SetPoint("LEFT", loadBtn, "RIGHT", horizontalSpacing, 0)
	deleteBtn:SetText(L["profiles_delete"])
	deleteBtn:SetScript("OnClick", function()
		local name = selectedName
		if not name or name == "" then
			mini:Notify(L["profiles_need_select"])
			return
		end
		ShowConfirm(string.format(L["profiles_delete_confirm"], name), function()
				if profiles:Delete(db, name) then
					selectedName = ""
					nameScratch = ""
					RefreshProfileDropdown()
					mini:Notify(string.format(L["profiles_deleted"], name))
				end
			end)
	end)

	local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	resetBtn:SetSize(160, 24)
	resetBtn:SetPoint("LEFT", deleteBtn, "RIGHT", horizontalSpacing, 0)
	resetBtn:SetText(L["profiles_reset_current"])
	resetBtn:SetScript("OnClick", function()
		if InCombatLockdown() then
			mini:NotifyCombatLockdown()
			return
		end
		ShowConfirm(L["profiles_reset_confirm"], function()
				local defaultsSnap = profiles:CaptureSettings(dbDefaults)
				ApplySettingsSnapshot(defaultsSnap, L["Settings reset to default."])
			end)
	end)

	local ioDivider = mini:Divider({
			Parent = content,
		Text = L["profiles_section_io"],
		})
	ioDivider:SetPoint("LEFT", content, "LEFT")
	ioDivider:SetPoint("RIGHT", content, "RIGHT")
	ioDivider:SetPoint("TOP", saveBtn, "BOTTOM", 0, -verticalSpacing * 2)

	local ioHint = mini:TextBlock({
			Parent = content,
		Font = "GameFontWhite",
		Lines = {
			L["profiles_io_hint_1"],
			L["profiles_io_hint_2"],
		},
	})
	ioHint:SetPoint("TOPLEFT", ioDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Simple clickable multiline paste box (avoid BackdropTemplate / GetStringHeight — can error in Settings UI).
	local exportFrame = CreateFrame("Frame", nil, content)
	exportFrame:SetPoint("TOPLEFT", ioHint, "BOTTOMLEFT", 0, -verticalSpacing)
	exportFrame:SetSize(520, 130)
	exportFrame:EnableMouse(true)
	local exportBg = exportFrame:CreateTexture(nil, "BACKGROUND")
	exportBg:SetAllPoints()
	exportBg:SetColorTexture(0, 0, 0, 0.55)
	local exportBorder = exportFrame:CreateTexture(nil, "BORDER")
	exportBorder:SetPoint("TOPLEFT", -1, 1)
	exportBorder:SetPoint("BOTTOMRIGHT", 1, -1)
	exportBorder:SetColorTexture(0.55, 0.55, 0.55, 0.8)
	exportBg:SetDrawLayer("BACKGROUND", 1)

	local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
	exportScroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 6, -6)
	exportScroll:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -26, 6)
	exportScroll:EnableMouse(true)

	local exportBox = CreateFrame("EditBox", nil, exportScroll)
	exportBox:SetMultiLine(true)
	exportBox:SetFontObject(GameFontHighlightSmall)
	exportBox:SetWidth(470)
	exportBox:SetHeight(400)
	exportBox:SetAutoFocus(false)
	exportBox:EnableMouse(true)
	exportBox:SetTextInsets(4, 4, 4, 4)
	if exportBox.SetMaxLetters then
		exportBox:SetMaxLetters(200000)
	end
	exportBox:SetText(exportScratch or "")
	exportBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			exportScratch = self:GetText() or ""
		else
			exportScratch = self:GetText() or ""
			end
		end)
	exportBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	exportBox:SetScript("OnMouseDown", function(self)
		self:SetFocus()
	end)
	exportScroll:SetScript("OnMouseDown", function()
		exportBox:SetFocus()
	end)
	exportFrame:SetScript("OnMouseDown", function()
		exportBox:SetFocus()
	end)
	exportScroll:SetScrollChild(exportBox)

	local exportBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	exportBtn:SetSize(140, 24)
	exportBtn:SetPoint("TOPLEFT", exportFrame, "BOTTOMLEFT", 0, -verticalSpacing)
	exportBtn:SetText(L["profiles_export"])
	exportBtn:SetScript("OnClick", function()
		local snap = profiles:CaptureSettings(db)
		local name = (selectedName ~= "" and selectedName) or (nameScratch ~= "" and nameScratch) or "profile"
		local text = profiles:Export(snap, name)
		exportScratch = text
		exportBox:SetText(text)
		exportBox:SetFocus()
		exportBox:HighlightText()
		mini:Notify(L["profiles_exported"])
	end)

	local importBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	importBtn:SetSize(140, 24)
	importBtn:SetPoint("LEFT", exportBtn, "RIGHT", horizontalSpacing, 0)
	importBtn:SetText(L["profiles_import_apply"])
	importBtn:SetScript("OnClick", function()
		local text = exportBox:GetText() or exportScratch
		local payload, err = profiles:Import(text)
		if not payload then
			mini:Notify(string.format(L["profiles_import_failed"], tostring(err)))
			return
		end
		ShowConfirm(L["profiles_import_confirm"], function()
				local pname = payload.name
				if type(pname) == "string" and pname ~= "" then
					db.ActiveProfileName = pname
					selectedName = pname
					nameScratch = pname
				end
				ApplySettingsSnapshot(payload.settings, L["profiles_imported"])
				RefreshProfileDropdown()
			end)
	end)

	local importSaveBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	importSaveBtn:SetSize(160, 24)
	importSaveBtn:SetPoint("LEFT", importBtn, "RIGHT", horizontalSpacing, 0)
	importSaveBtn:SetText(L["profiles_import_save"])
	importSaveBtn:SetScript("OnClick", function()
		local text = exportBox:GetText() or exportScratch
		local payload, err = profiles:Import(text)
		if not payload then
			mini:Notify(string.format(L["profiles_import_failed"], tostring(err)))
			return
		end
		local pname = nameScratch
		if pname == "" then
			pname = (type(payload.name) == "string" and payload.name ~= "" and payload.name) or nil
		end
		if not pname or pname == "" then
			mini:Notify(L["profiles_need_name"])
			return
		end
		-- Apply into a temp fashion: save snapshot under name without necessarily applying? User asked import and save as scheme.
		-- Save imported settings as a named profile, then optionally apply.
		ShowConfirm(string.format(L["profiles_import_save_confirm"], pname), function()
				db.Profiles = db.Profiles or {}
				local copy = profiles:DeepCopy(payload.settings)
				MigrateSettingsSnapshot(copy)
				db.Profiles[pname] = copy
				db.ActiveProfileName = pname
				selectedName = pname
				nameScratch = pname
				ApplySettingsSnapshot(copy, string.format(L["profiles_imported_saved"], pname))
				RefreshProfileDropdown()
			end)
	end)
end

local function BuildChangelogTab(content)
	local block = mini:TextBlock({
		Parent = content,
		Lines = {
			L["changelog_v3.0.5"],
			" ",
			L["changelog_v3.0.4"],
			" ",
			L["changelog_v3.0.3"],
			" ",
			L["changelog_v3.0.2"],
			" ",
			L["changelog_v3.0.1"],
			" ",
			L["changelog_v3.0.0"],
			" ",
			L["changelog_v2.0.3"],
			" ",
			L["changelog_v2.0.2"],
			" ",
			L["changelog_v2.0.1"],
			" ",
			L["changelog_v2.0.0"],
		},
	})
	block:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
end

function M:Init()
	local rawDb = mini:GetSavedVars()
	MigrateV1(rawDb)
	MigrateThroughV11(rawDb)
	MigrateV13(rawDb)
		MigrateV14(rawDb)
	MigrateV16(rawDb)
	MigrateV17(rawDb)
	MigrateV18(rawDb)
	MigrateV19(rawDb)
	MigrateV20(rawDb)
	MigrateV21(rawDb)
	MigrateV22(rawDb)
	MigrateV23(rawDb)
	MigrateV24(rawDb)
	MigrateV25(rawDb)
	MigrateV26(rawDb)
	MigrateV27(rawDb)
	MigrateV28(rawDb)
	MigrateV29(rawDb)

	-- Spells defaults stay empty; Disabled* sparse maps are the source of truth.
	dbDefaults.Spells = {}
	dbDefaults.SelfCcSpells = {}
	dbDefaults.DisabledEnemySpells = {}
	dbDefaults.DisabledSelfCcSpells = {}
	db = mini:GetSavedVars(dbDefaults)
	EnsureSpellDefaults(db)
	EnsureSelfCcDefaults(db)
	EnsureZoneDefaults(db)
	EnsureSysCastDefaults(db)
	-- Free-form / sparse tables must be copied out before CleanTable (empty {} template wipes them).
	local savedExtraPacks = {}
	if type(db.ExtraVoicePacks) == "table" then
		for k, v in pairs(db.ExtraVoicePacks) do
			savedExtraPacks[k] = v
		end
	end
	local savedProfiles = {}
	if type(db.Profiles) == "table" then
		for k, v in pairs(db.Profiles) do
			savedProfiles[k] = v
		end
	end
	local savedSysCast = nil
	if type(db.SysCast) == "table" then
		savedSysCast = {}
		for k, v in pairs(db.SysCast) do
			savedSysCast[k] = v
		end
	end
	local savedActiveProfile = db.ActiveProfileName
	local savedDisabledEnemy = CopyDisableMap(db.DisabledEnemySpells)
	local savedDisabledSelfCc = CopyDisableMap(db.DisabledSelfCcSpells)
	local savedVoicePack = db.VoicePack
	local savedHealerCcSound = db.HealerCcSoundFile
	local savedInterruptSound = db.InterruptSoundFile
	mini:CleanTable(db, dbDefaults, true, true)
	db.ExtraVoicePacks = savedExtraPacks
	db.Profiles = savedProfiles
	if savedSysCast then
		db.SysCast = savedSysCast
	end
	if type(savedActiveProfile) == "string" then
		db.ActiveProfileName = savedActiveProfile
	end
	db.DisabledEnemySpells = savedDisabledEnemy
	db.DisabledSelfCcSpells = savedDisabledSelfCc
	db.Spells = {}
	db.SelfCcSpells = {}
	-- Rehydrate legacy maps from disable maps so any leftover readers stay consistent.
	for spellId in pairs(savedDisabledEnemy) do
		db.Spells[spellId] = false
	end
	for spellId in pairs(savedDisabledSelfCc) do
		db.SelfCcSpells[spellId] = false
	end
	if type(savedVoicePack) == "string" and savedVoicePack ~= "" then
		db.VoicePack = savedVoicePack
	end
	if type(savedHealerCcSound) == "string" and savedHealerCcSound ~= "" then
		db.HealerCcSoundFile = savedHealerCcSound
	end
	if type(savedInterruptSound) == "string" and savedInterruptSound ~= "" then
		db.InterruptSoundFile = savedInterruptSound
	end
	EnsureSpellDefaults(db)
	EnsureSelfCcDefaults(db)
	EnsureZoneDefaults(db)
	EnsureSysCastDefaults(db)
	voicePack:Init()

	local scroll = CreateFrame("ScrollFrame", nil, nil, "UIPanelScrollFrameTemplate")
	scroll.name = addonName

	local category = mini:AddCategory(scroll)
	if not category then return end

	-- Register early: later UI build errors must not leave /ps dead.
	SLASH_PVPSOUND1 = "/pvpsound"
	SLASH_PVPSOUND2 = "/ps"
	SlashCmdList.PVPSOUND = function(msg)
		msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
		if msg == "casttest" or msg == "cast" then
			if addon.Modules.SoundModule and addon.Modules.SoundModule.DebugCastTest then
				addon.Modules.SoundModule:DebugCastTest()
			else
				print("|cffff3333[PVP Sound]|r SoundModule 未加载。")
			end
			return
		end
		local sysArg = msg:match("^syscast%s*(.*)$")
		if sysArg ~= nil or msg == "sys" then
			if addon.Modules.SoundModule and addon.Modules.SoundModule.DebugSysCast then
				addon.Modules.SoundModule:DebugSysCast(sysArg or "")
			else
				print("|cffff3333[PVP Sound]|r SoundModule 未加载。")
			end
			return
		end
		if msg == "test" then
			DoTest()
			return
		end
		local potionArg = msg:match("^potion%s*(.*)$") or msg:match("^consumable%s*(.*)$")
		if potionArg ~= nil then
			if addon.Modules.ConsumableModule and addon.Modules.ConsumableModule.DebugTest then
				addon.Modules.ConsumableModule:DebugTest(potionArg)
			else
				print("|cffff3333[PVP Sound]|r ConsumableModule 未加载。")
			end
			return
		end
		mini:OpenSettings(category, scroll)
	end

	local panel = CreateFrame("Frame", nil, scroll)
	local width, height = mini:SettingsSize()
	panel:SetWidth(width)
	-- Tall enough for all classes listed on one Spells page.
	panel:SetHeight(math.max(height * 8, 5000))
	scroll:SetScrollChild(panel)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(scrollSelf, delta)
		local step = 30
		local current = scrollSelf:GetVerticalScroll()
		local max = scrollSelf:GetVerticalScrollRange()
		if delta > 0 then
			scrollSelf:SetVerticalScroll(math.max(current - step, 0))
		else
			scrollSelf:SetVerticalScroll(math.min(current + step, max))
		end
	end)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local descBlock = mini:TextBlock({
		Parent = panel,
		Lines = { L["addon_description"] },
	})
	descBlock:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local authorLine = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	authorLine:SetText(L["Author: DK-姜世离（燃烧之刃）"])
	authorLine:SetPoint("TOPLEFT", descBlock, "BOTTOMLEFT", 0, -4)

	local donateBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	donateBtn:SetSize(80, 22)
	donateBtn:SetPoint("LEFT", authorLine, "RIGHT", horizontalSpacing, 2)
	donateBtn:SetText(L["Donate"])

	local donatePopup = CreateFrame("Frame", "PVPSoundDonatePopup", UIParent, "BasicFrameTemplateWithInset")
	donatePopup:SetSize(440, 140)
	donatePopup:SetPoint("CENTER")
	donatePopup:SetFrameStrata("DIALOG")
	donatePopup:EnableMouse(true)
	donatePopup:SetMovable(true)
	donatePopup:RegisterForDrag("LeftButton")
	donatePopup:SetScript("OnDragStart", donatePopup.StartMoving)
	donatePopup:SetScript("OnDragStop", donatePopup.StopMovingOrSizing)
	donatePopup:Hide()
	donatePopup.TitleText:SetText(L["Donate Popup Title"])

	local donateHint = donatePopup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	donateHint:SetText(L["Donate Popup Hint"])
	donateHint:SetPoint("TOP", donatePopup, "TOP", 0, -32)

	local donateURL = "https://vitocichen.github.io/DK-jiangshili/"
	local donateEditBox = CreateFrame("EditBox", nil, donatePopup, "InputBoxTemplate")
	donateEditBox:SetSize(300, 20)
	donateEditBox:SetPoint("TOP", donateHint, "BOTTOM", -20, -12)
	donateEditBox:SetAutoFocus(false)
	donateEditBox:SetText(donateURL)
	donateEditBox:SetCursorPosition(0)
	donateEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	donateEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	donateEditBox:SetScript("OnTextChanged", function(self)
		self:SetText(donateURL)
		self:HighlightText()
	end)

	local donateCopyBtn = CreateFrame("Button", nil, donatePopup, "UIPanelButtonTemplate")
	donateCopyBtn:SetSize(60, 22)
	donateCopyBtn:SetPoint("LEFT", donateEditBox, "RIGHT", 8, 0)
	donateCopyBtn:SetText(L["Copy"])
	donateCopyBtn:SetScript("OnClick", function(self)
		donateEditBox:SetText(donateURL)
		donateEditBox:HighlightText()
		donateEditBox:SetFocus()
		self:SetText(L["Copied"])
		C_Timer.After(1.5, function() self:SetText(L["Copy"]) end)
	end)

	local donateOpenHint = donatePopup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	donateOpenHint:SetText(L["Donate Open Hint"])
	donateOpenHint:SetPoint("TOP", donateEditBox, "BOTTOM", -20, -8)

	donateBtn:SetScript("OnClick", function()
		if donatePopup:IsShown() then
			donatePopup:Hide()
		else
			donatePopup:Show()
			donateEditBox:SetText(donateURL)
			donateEditBox:SetCursorPosition(0)
		end
	end)

	local tabsPanel = CreateFrame("Frame", nil, panel)
	tabsPanel:SetPoint("TOPLEFT", authorLine, "BOTTOMLEFT", 0, -verticalSpacing)
	tabsPanel:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	tabsPanel:SetPoint("BOTTOM", panel, "BOTTOM", 0, verticalSpacing * 2)

	local function BuildGeneralSpellsTab(content)
		local intro = mini:TextBlock({
			Parent = content,
			Lines = { L["spells_tab_intro"] },
		})
		intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

		local merged = BuildMergedClasses()
		local generalEntry
		for _, classEntry in ipairs(merged) do
			if classEntry.Key == "General" then
				generalEntry = classEntry
				break
			end
		end
		local last = intro
		if generalEntry then
			last = BuildClassSection(content, intro, generalEntry, { showDivider = false })
		end
		BuildConsumableWatchSection(content, last)
	end

	local function BuildClassSpellsTab(content)
		local merged = BuildMergedClasses()
		local classItems = {}
		local classByKey = {}
		for _, classEntry in ipairs(merged) do
			if classEntry.Key ~= "General" then
				classItems[#classItems + 1] = classEntry.Key
				classByKey[classEntry.Key] = classEntry
			end
		end
		if #classItems == 0 then
			return
		end

		local classLabel = mini:TextLine({
			Parent = content,
			Text = L["Class"],
		})
		classLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

		local classColumnWidth = mini:ColumnWidth(2, 0, 0)
		local selectedKey = classItems[1]
		local spellHost = CreateFrame("Frame", nil, content)
		spellHost:SetPoint("RIGHT", content, "RIGHT", 0, 0)
		spellHost:SetHeight(4000)

		local function ClearHost()
			for _, child in ipairs({ spellHost:GetChildren() }) do
				child:Hide()
				child:SetParent(nil)
			end
			spellHost.MiniControls = nil
			spellHost.MiniRefresh = nil
		end

		local function RebuildClassSpells()
			ClearHost()
			local entry = classByKey[selectedKey]
			if not entry then
				return
			end
			local dummy = CreateFrame("Frame", nil, spellHost)
			dummy:SetPoint("TOPLEFT", spellHost, "TOPLEFT", 0, 0)
			dummy:SetSize(1, 1)
			BuildClassSection(spellHost, dummy, entry, { showDivider = false })
		end

		local classDropdown = mini:Dropdown({
			Parent = content,
			Items = classItems,
			Width = 200,
			GetValue = function()
				return selectedKey
			end,
			SetValue = function(value)
				selectedKey = value
				RebuildClassSpells()
			end,
			GetText = function(value)
				local entry = classByKey[value]
				if entry then
					return L[entry.Name] or entry.Name
				end
				return value or ""
			end,
		})
		classDropdown:SetPoint("LEFT", content, "LEFT", classColumnWidth, 0)
		classDropdown:SetPoint("TOP", classLabel, "TOP", 0, 8)
		classDropdown:SetWidth(200)

		spellHost:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", 0, -verticalSpacing)
		RebuildClassSpells()
	end

	local tabs = {
			{
				Key = "Home",
				Title = addonName,
				Build = function(content) BuildHomeTab(content) end,
			},
			{
			Key = "Zones",
			Title = L["Zones"],
			Build = function(content) BuildZonesTab(content) end,
		},
		{
			Key = "SysCast",
			Title = L["SysCast Tab"],
			Build = function(content) BuildSysCastTab(content) end,
		},
		{
			Key = "GeneralSpells",
			Title = L["General Spells"],
			Build = function(content) BuildGeneralSpellsTab(content) end,
		},
		{
			Key = "ClassSpells",
			Title = L["Class Spells"],
			Build = function(content) BuildClassSpellsTab(content) end,
		},
		{
			Key = "Profiles",
			Title = L["Profiles"],
			Build = function(content)
				local ok, err = pcall(BuildProfilesTab, content)
				if not ok then
					print("|cffff3333[PVP Sound]|r Profiles tab error: " .. tostring(err))
					local msg = mini:TextBlock({
						Parent = content,
						Lines = {
							"|cFFFF5050配置页加载失败|r",
							tostring(err),
						},
					})
					msg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
				end
			end,
			},
			{
				Key = "Changelog",
				Title = L["Changelog"],
				Build = function(content) BuildChangelogTab(content) end,
			},
	}

	M.TabController = mini:CreateTabs({
		Parent = tabsPanel,
		InitialKey = "Home",
		ContentInsets = { Top = verticalSpacing },
		Tabs = tabs,
	})

	StaticPopupDialogs["PVPSOUND_CONFIRM"] = {
		text = "%s",
		button1 = YES,
		button2 = NO,
		-- Prefer module locals; also accept self.data / 2nd arg for compatibility.
		OnAccept = function(self, data)
			local fn = pendingConfirmYes
			pendingConfirmYes = nil
			pendingConfirmNo = nil
			data = data or (self and self.data)
			if fn then
				fn()
			elseif data and data.OnYes then
				data.OnYes()
			end
		end,
		OnCancel = function(self, data)
			local fn = pendingConfirmNo
			pendingConfirmYes = nil
			pendingConfirmNo = nil
			data = data or (self and self.data)
			if fn then
				fn()
			elseif data and data.OnNo then
				data.OnNo()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end
