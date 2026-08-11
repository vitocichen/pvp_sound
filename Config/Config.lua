---@type string, Addon
local addonName, addon = ...
local mini = addon.Core.Framework
local L = addon.L
local verticalSpacing = mini.VerticalSpacing
local horizontalSpacing = mini.HorizontalSpacing
local catalog = addon.Data.EnemyBuffCatalog
local selfCcCatalog = addon.Data.SelfCcCatalog
local voicePack = addon.Core.VoicePack

---@type Db
local db

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
	Version = 20,
	WhatsNewVersion = false,
	VoicePack = "夏一可",
	ExtraVoicePacks = {},
	Sound = {
		Channel = "Master",
		CastInterval = 0.0,
	},
	-- Enabled = enemy buff; CcEnabled = self/party debuff; HealerCcEnabled = healer-in-CC alert.
	-- TargetFocusOnly = buff monitor; CcScope = self|party for debuffs.
	Zones = {
		World = { Enabled = true, TargetFocusOnly = true, CcEnabled = true, CcScope = "self", HealerCcEnabled = true },
		Arena = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "self", HealerCcEnabled = true },
		BattleGrounds = { Enabled = true, TargetFocusOnly = true, CcEnabled = true, CcScope = "self", HealerCcEnabled = true },
		PvE = { Enabled = false, TargetFocusOnly = true, CcEnabled = false, CcScope = "self", HealerCcEnabled = false },
	},
	Spells = {},
	SelfCcSpells = {},
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
	savedDb.VoicePack = savedDb.VoicePack or "夏一可"
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

local function EnsureSpellDefaults(savedDb)
	savedDb.Spells = savedDb.Spells or {}
	for spellId in pairs(addon.Data.EnemyBuffSounds) do
		if savedDb.Spells[spellId] == nil then
			savedDb.Spells[spellId] = true
		end
	end
end

local function EnsureSelfCcDefaults(savedDb)
	savedDb.SelfCcSpells = savedDb.SelfCcSpells or {}
	for spellId in pairs(addon.Data.SelfCcSounds) do
		if savedDb.SelfCcSpells[spellId] == nil then
			savedDb.SelfCcSpells[spellId] = true
		end
	end
end

local function EnsureZoneDefaults(savedDb)
	savedDb.Zones = savedDb.Zones or {}
	local defaults = {
		World = { Enabled = true, TargetFocusOnly = true, CcEnabled = true, CcScope = "self", HealerCcEnabled = true },
		Arena = { Enabled = true, TargetFocusOnly = false, CcEnabled = true, CcScope = "self", HealerCcEnabled = true },
		BattleGrounds = { Enabled = true, TargetFocusOnly = true, CcEnabled = true, CcScope = "self", HealerCcEnabled = true },
		PvE = { Enabled = false, TargetFocusOnly = true, CcEnabled = false, CcScope = "self", HealerCcEnabled = false },
	}
	for key, def in pairs(defaults) do
		savedDb.Zones[key] = savedDb.Zones[key] or {}
		local zone = savedDb.Zones[key]
		if zone.Enabled == nil then
			zone.Enabled = def.Enabled
		end
		if zone.TargetFocusOnly == nil then
			zone.TargetFocusOnly = def.TargetFocusOnly
		end
		if zone.CcEnabled == nil then
			zone.CcEnabled = def.CcEnabled
		end
		if zone.CcScope ~= "self" and zone.CcScope ~= "party" then
			zone.CcScope = def.CcScope
		end
		if zone.HealerCcEnabled == nil then
			zone.HealerCcEnabled = def.HealerCcEnabled
		end
	end
end

-- ---------- UI helpers ----------

local channelItems = { "Master", "SFX", "Ambience", "Dialog", "Music" }

local function DoTest()
	AuraSounds():PlayTest(45438)
end

local function BuildHomeTab(content)
	local intro = mini:TextBlock({
		Parent = content,
		Lines = {
			L["home_intro_1"],
			L["home_intro_voice_warning"],
			" ",
			L["home_intro_enemy_buffs"],
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

	local packHint = mini:TextBlock({
		Parent = content,
		Lines = { L["Voice Pack Hint"] },
	})
	packHint:SetPoint("TOPLEFT", soundDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local packItems = voicePack:ListPacks()
	local packLabel = mini:TextLine({
		Parent = content,
		Text = L["Voice Pack Select"],
	})
	packLabel:SetPoint("TOPLEFT", packHint, "BOTTOMLEFT", 0, -verticalSpacing)

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

	local customLabel = mini:TextLine({
		Parent = content,
		Text = L["Custom Voice Pack"],
	})
	customLabel:SetPoint("TOPLEFT", packLabel, "BOTTOMLEFT", 0, -verticalSpacing * 2)

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

	local channelLabel = mini:TextLine({
		Parent = content,
		Text = L["Output Channel"],
	})
	channelLabel:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -verticalSpacing * 2)

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

	local testBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	testBtn:SetSize(140, 26)
	testBtn:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -verticalSpacing * 2)
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
		StaticPopup_Show("PVPSOUND_CONFIRM", L["Are you sure you wish to reset to factory settings?"], nil, {
			OnYes = function()
				dbDefaults.Spells = BuildDefaultSpells()
				mini:ResetSavedVars(dbDefaults)
				db = mini:GetSavedVars()
				addon:Refresh()
				mini:Notify(L["Settings reset to default."])
			end,
		})
	end)
end

local function BuildZonesTab(content)
	local intro = mini:TextBlock({
		Parent = content,
		Lines = { L["zones_intro"] },
	})
	intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	local columnWidth = mini:ColumnWidth(2, 0, 0)
	local buffRangeItems = { "TargetFocus", "All" }
	local ccScopeItems = { "self", "party" }
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
		rangeLabel:SetWidth(math.max(1, rangeLabel:GetStringWidth() + 2))

		local rangeDropdown = mini:Dropdown({
			Parent = content,
			Items = items,
			Width = 180,
			GetValue = getValue,
			SetValue = setValue,
			GetText = getText,
		})
		rangeDropdown:SetPoint("LEFT", rangeLabel, "RIGHT", 8, 0)
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
				return (zone and zone.CcScope == "party") and "party" or "self"
			end,
			function(value)
				db.Zones[zoneKey] = db.Zones[zoneKey] or {}
				db.Zones[zoneKey].CcScope = (value == "party") and "party" or "self"
				M:Apply()
			end,
			function(value)
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
					local path = voicePack:Path("Sonar.ogg")
					if path then
						pcall(PlaySoundFile, path, db.Sound and db.Sound.Channel or "Master")
					end
				end
			end,
		})
		healerChk:SetPoint("TOPLEFT", ccChk, "BOTTOMLEFT", 0, -verticalSpacing)

		last = healerChk
	end
end

---@param spellId number
---@param fallbackName string?
local function SpellLabel(spellId, fallbackName)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
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

local function IsMergedSpellEnabled(spell)
	local ok = true
	if SpellUsesSelfCc(spell) then
		ok = ok and AuraSounds():IsSelfCcGroupEnabled(spell)
	end
	if SpellUsesEnemy(spell) then
		ok = ok and AuraSounds():IsSpellGroupEnabled(spell)
	end
	return ok
end

local function SetMergedSpellEnabled(spell, enabled)
	if SpellUsesSelfCc(spell) then
		AuraSounds():SetSelfCcGroupEnabled(spell, enabled)
	end
	if SpellUsesEnemy(spell) then
		AuraSounds():SetSpellGroupEnabled(spell, enabled)
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
		divider:SetPoint("TOP", anchor, "BOTTOM", 0, -verticalSpacing * 2)
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
			LabelText = SpellLabel(spellId, spell.Name),
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

local function BuildChangelogTab(content)
	local block = mini:TextBlock({
		Parent = content,
		Lines = {
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

	dbDefaults.Spells = BuildDefaultSpells()
	dbDefaults.SelfCcSpells = BuildDefaultSelfCcSpells()
	db = mini:GetSavedVars(dbDefaults)
	EnsureSpellDefaults(db)
	EnsureSelfCcDefaults(db)
	EnsureZoneDefaults(db)
	-- ExtraVoicePacks is a free-form list; empty-template CleanTable would wipe entries in-place.
	-- Must copy into a NEW table — saving the same reference then restoring does nothing.
	local savedExtraPacks = {}
	if type(db.ExtraVoicePacks) == "table" then
		for k, v in pairs(db.ExtraVoicePacks) do
			savedExtraPacks[k] = v
		end
	end
	-- Do NOT CleanTable Spells against defaults in a way that drops false — defaults include all keys.
	mini:CleanTable(db, dbDefaults, true, true)
	db.ExtraVoicePacks = savedExtraPacks
	EnsureSpellDefaults(db)
	EnsureSelfCcDefaults(db)
	EnsureZoneDefaults(db)
	voicePack:Init()

	local scroll = CreateFrame("ScrollFrame", nil, nil, "UIPanelScrollFrameTemplate")
	scroll.name = addonName

	local category = mini:AddCategory(scroll)
	if not category then return end

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
		if generalEntry then
			BuildClassSection(content, intro, generalEntry, { showDivider = false })
		end
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

		spellHost:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", 0, -verticalSpacing * 3)
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
		OnAccept = function(_, data)
			if data and data.OnYes then data.OnYes() end
		end,
		OnCancel = function(_, data)
			if data and data.OnNo then data.OnNo() end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	SLASH_PVPSOUND1 = "/pvpsound"
	SLASH_PVPSOUND2 = "/ps"
	SlashCmdList.PVPSOUND = function(msg)
		msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
		if msg == "test" then
			DoTest()
			return
		end
		mini:OpenSettings(category, scroll)
	end
end
