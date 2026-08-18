---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local auraSounds = addon.Core.AuraSounds
local voicePack = addon.Core.VoicePack
local L = addon.L

local enemyBuffSounds = addon.Data.EnemyBuffSounds
local selfCcSounds = addon.Data.SelfCcSounds
local ccSpellIds = addon.Data.CcSpellIds

local MEDIA_ROOT = "Interface\\AddOns\\PVP_Sound\\Media\\"

---@class AuraSoundModule
local M = {}
addon.Modules.AuraSoundModule = M

-- token -> handle list (enemy buffs)
local enemyByToken = {}
local enemySignature = nil
local spellGeneration = 0

-- friendly CC handles by unit token (player / party / raid)
local selfCcByToken = {}
local selfCcSignature = nil
local selfCcGeneration = 0

-- healer-in-CC: one shared alert clip on each healer unit (MiniAuras HealerCC)
local healerCcByToken = {}
local healerCcSignature = nil

local DEFAULT_CHANNEL = "Master"
local eventsFrame
local db

local enabledEnemySounds = {}
local enabledSelfCcSounds = {}

local function Channel()
	return (db and db.Sound and db.Sound.Channel) or DEFAULT_CHANNEL
end

local function BuffZoneEnabled()
	return moduleUtil:IsEnabled()
end

local function CcZoneEnabled()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return true end
	return zone.CcEnabled ~= false
end

local function HealerCcZoneEnabled()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return true end
	return zone.HealerCcEnabled ~= false
end

---@return string
local function HealerCcSoundFile()
	local file = db and db.HealerCcSoundFile
	if type(file) == "string" and file ~= "" then
		return file
	end
	return "HealerCcAlert.ogg"
end

---HealerCcAlert.ogg resolves from the selected voice pack; PS_* clips live under Media\.
---@return string?
local function ResolveHealerCcSoundPath()
	local file = HealerCcSoundFile()
	if file == "HealerCcAlert.ogg" or file == "HealerCC.ogg" then
		return voicePack:Path("HealerCcAlert.ogg")
	end
	return MEDIA_ROOT .. file
end

---"self" = player only; "party" = player + teammates; "partyonly" = teammates, not player (per zone).
local function SelfCcScope()
	local zone = moduleUtil:GetZoneConfig()
	if zone and (zone.CcScope == "party" or zone.CcScope == "partyonly") then
		return zone.CcScope
	end
	return "self"
end

local function RebuildEnabledEnemySounds()
	wipe(enabledEnemySounds)
	local disabled = db and db.DisabledEnemySpells
	local legacy = db and db.Spells
	for spellId, file in pairs(enemyBuffSounds) do
		local enabled = true
		if disabled and (disabled[spellId] or disabled[tostring(spellId)]) then
			enabled = false
		elseif legacy then
			local flag = legacy[spellId]
			if flag == nil then
				flag = legacy[tostring(spellId)]
			end
			if flag == false then
				enabled = false
			end
		end
		if enabled then
			enabledEnemySounds[spellId] = file
		end
	end
	-- Potion / trinket auras: always on, not shown in class catalog checkboxes.
	local consumables = addon.Data.Consumables
	local list = consumables and consumables.List
	if list then
		for i = 1, #list do
			local entry = list[i]
			local spellId = entry and entry.spellID
			local file = entry and entry.file
			if spellId and file and file ~= "" then
				enabledEnemySounds[spellId] = file
			end
		end
	end
end

local function RebuildEnabledSelfCcSounds()
	wipe(enabledSelfCcSounds)
	local disabled = db and db.DisabledSelfCcSpells
	local legacy = db and db.SelfCcSpells
	for spellId, file in pairs(selfCcSounds) do
		local enabled = true
		if disabled and (disabled[spellId] or disabled[tostring(spellId)]) then
			enabled = false
		elseif legacy then
			local flag = legacy[spellId]
			if flag == nil then
				flag = legacy[tostring(spellId)]
			end
			if flag == false then
				enabled = false
			end
		end
		if enabled then
			enabledSelfCcSounds[spellId] = file
		end
	end
end

local function UnitExistsSafe(unitToken)
	local exists = UnitExists(unitToken)
	return not issecretvalue(exists) and exists and true or false
end

---@return string[]
local function GetSelfCcWatchTokens()
	-- Match old PVP_Sound Friendly CC + MiniAuras party unit picking:
	-- self: player; party: player + teammates; partyonly: teammates only (v2 "Party Only").
	-- Skip pets/minions. When healer-CC alert is on, skip healers so they only get Sonar.
	local scope = SelfCcScope()
	local tokens = {}
	if scope ~= "partyonly" then
		tokens[#tokens + 1] = "player"
		if scope ~= "party" then
			return tokens
		end
	end

	local skipHealers = HealerCcZoneEnabled()
	for _, unit in ipairs(units:FriendlyUnits()) do
		if not units:IsPetOrMinion(unit) then
			if not (skipHealers and units:IsHealer(unit)) then
				tokens[#tokens + 1] = unit
			end
		end
	end

	return tokens
end

local function IsTargetFocusOnly()
	-- Old PVP_Sound: per-zone TargetFocusOnly; nil/true = target+focus only.
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return true end
	return zone.TargetFocusOnly ~= false
end

local function GetEnemyWatchTokens()
	-- One registration per unit GUID. Otherwise target/focus + arenaN / nameplate
	-- for the same enemy would AddAuraSound twice and double-play.
	local tokens = {}
	local seenGuid = {}

	local function AddToken(unitToken)
		if not unitToken then return end
		local guid = UnitGUID(unitToken)
		if guid and not issecretvalue(guid) then
			if seenGuid[guid] then return end
			seenGuid[guid] = true
		end
		tokens[#tokens + 1] = unitToken
	end

	local _, instanceType = IsInInstance()
	local targetFocusOnly = IsTargetFocusOnly()

	AddToken("target")
	AddToken("focus")

	if instanceType == "arena" then
		if not targetFocusOnly then
			AddToken("arena1")
			AddToken("arena2")
			AddToken("arena3")
		end
		return tokens
	end

	if not targetFocusOnly then
		-- Combat: do not index Compact nameplate frames (GetNamePlates).
		-- NAME_PLATE_UNIT_ADDED still registers new plates.
		if InCombatLockdown() then
			for token in pairs(enemyByToken) do
				if type(token) == "string" and token:find("^nameplate") then
					AddToken(token)
				end
			end
		else
			for _, nameplate in ipairs(C_NamePlate.GetNamePlates() or {}) do
				local unitToken = nameplate.unitToken
				if units:IsEnemyPlayer(unitToken) then
					AddToken(unitToken)
				end
			end
		end
	end

	return tokens
end

local function ClearMap(map)
	for token, ids in pairs(map) do
		auraSounds:RemoveSet(ids)
		map[token] = nil
	end
end

---Only watch units that currently qualify (hostile/duel player, or existing arena frame).
---@param unitToken string
---@return boolean
local function ShouldWatchToken(unitToken)
	if not unitToken then return false end
	local isArena = unitToken == "arena1" or unitToken == "arena2" or unitToken == "arena3"
	if isArena then
		local exists = UnitExists(unitToken)
		return not issecretvalue(exists) and exists and true or false
	end
	return units:IsEnemyPlayer(unitToken)
end

local function UnregisterToken(unitToken)
	local ids = enemyByToken[unitToken]
	if not ids then return end
	auraSounds:RemoveSet(ids)
	enemyByToken[unitToken] = nil
end

local function RegisterEnemyToken(unitToken, basePath, channel)
	if enemyByToken[unitToken] then return end
	if not next(enabledEnemySounds) then return end
	if not ShouldWatchToken(unitToken) then return end

	enemyByToken[unitToken] = auraSounds:RegisterMappedSet(nil, unitToken, enabledEnemySounds, basePath, channel)
end

local function UnregisterSelfCcToken(unitToken)
	local ids = selfCcByToken[unitToken]
	if not ids then return end
	auraSounds:RemoveSet(ids)
	selfCcByToken[unitToken] = nil
end

local function RegisterSelfCcToken(unitToken, basePath, channel)
	if selfCcByToken[unitToken] then return end
	if not next(enabledSelfCcSounds) then return end
	if unitToken ~= "player" and not UnitExistsSafe(unitToken) then return end

	selfCcByToken[unitToken] = auraSounds:RegisterMappedSet(nil, unitToken, enabledSelfCcSounds, basePath, channel)
end

local function RefreshSelfCc(basePath, channel, active)
	local wantActive = active and next(enabledSelfCcSounds) ~= nil
	local scope = SelfCcScope()
	local inGroup = IsInGroup() and true or false
	local inRaid = IsInRaid() and true or false
	local sig = auraSounds:Signature(
		wantActive,
		basePath or "",
		channel,
		selfCcGeneration,
		scope,
		inGroup,
		inRaid,
		moduleUtil:GetZoneKey(),
		HealerCcZoneEnabled()
	)

	local tokens = wantActive and GetSelfCcWatchTokens() or {}
	local want = {}
	for i = 1, #tokens do
		want[tokens[i]] = true
	end

	if sig ~= selfCcSignature then
		ClearMap(selfCcByToken)
		selfCcSignature = sig
	else
		for token in pairs(selfCcByToken) do
			if not want[token] or (token ~= "player" and not UnitExistsSafe(token)) then
				UnregisterSelfCcToken(token)
			end
		end
	end

	if wantActive and basePath then
		for token in pairs(want) do
			RegisterSelfCcToken(token, basePath, channel)
		end
	elseif not wantActive then
		ClearMap(selfCcByToken)
	end
end

local function UnregisterHealerCcToken(unitToken)
	local ids = healerCcByToken[unitToken]
	if not ids then return end
	auraSounds:RemoveSet(ids)
	healerCcByToken[unitToken] = nil
end

local function RegisterHealerCcToken(unitToken, soundPath, channel)
	if healerCcByToken[unitToken] then return end
	if not ccSpellIds or not next(ccSpellIds) then return end
	if not UnitExistsSafe(unitToken) then return end

	healerCcByToken[unitToken] = auraSounds:RegisterSet(nil, unitToken, ccSpellIds, soundPath, channel)
end

---MiniAuras HealerCC: register full CC list on each party/raid healer (not the player).
local function RefreshHealerCc(basePath, channel, active)
	local soundPath = active and ResolveHealerCcSoundPath() or nil
	local wantActive = active and soundPath ~= nil and ccSpellIds ~= nil and next(ccSpellIds) ~= nil
	if wantActive and not soundPath then
		wantActive = false
	end

	local inGroup = IsInGroup() and true or false
	local inRaid = IsInRaid() and true or false
	local sig = auraSounds:Signature(
		wantActive,
		soundPath or "",
		HealerCcSoundFile(),
		channel,
		inGroup,
		inRaid,
		moduleUtil:GetZoneKey()
	)

	local want = {}
	if wantActive then
		for _, unit in ipairs(units:FindHealers()) do
			if not units:IsPetOrMinion(unit) then
				want[unit] = true
			end
		end
	end

	if sig ~= healerCcSignature then
		ClearMap(healerCcByToken)
		healerCcSignature = sig
	else
		for token in pairs(healerCcByToken) do
			if not want[token] or not UnitExistsSafe(token) then
				UnregisterHealerCcToken(token)
			end
		end
	end

	if wantActive and soundPath then
		for token in pairs(want) do
			RegisterHealerCcToken(token, soundPath, channel)
		end
	elseif not wantActive then
		ClearMap(healerCcByToken)
	end
end

function M:Refresh(reason)
	if not auraSounds:IsAvailable() then return end

	RebuildEnabledEnemySounds()
	RebuildEnabledSelfCcSounds()

	local basePath = voicePack:GetBasePath()
	local channel = Channel()

	-- --- enemy buffs ---
	local enemyActive = BuffZoneEnabled() and basePath ~= nil and next(enabledEnemySounds) ~= nil
	local targetFocusOnly = IsTargetFocusOnly()
	local sig = auraSounds:Signature(
		enemyActive,
		basePath or "",
		channel,
		moduleUtil:GetZoneKey(),
		spellGeneration,
		targetFocusOnly
	)

	local tokens = enemyActive and GetEnemyWatchTokens() or {}
	local want = {}
	for i = 1, #tokens do
		want[tokens[i]] = true
	end

	if sig ~= enemySignature then
		ClearMap(enemyByToken)
		enemySignature = sig
	else
		-- Drop tokens we no longer want, OR that no longer qualify (e.g. target
		-- was hostile, registration stuck after they became friendly / cleared).
		for token in pairs(enemyByToken) do
			if not want[token] or not ShouldWatchToken(token) then
				UnregisterToken(token)
			end
		end
	end

	if enemyActive and basePath then
		for token in pairs(want) do
			if ShouldWatchToken(token) then
				RegisterEnemyToken(token, basePath, channel)
			else
				UnregisterToken(token)
			end
		end
	elseif not enemyActive then
		ClearMap(enemyByToken)
	end

	-- --- friendly CC (player / optional party+raid) ---
	local ccActive = CcZoneEnabled() and basePath ~= nil
	RefreshSelfCc(basePath, channel, ccActive)

	-- --- healer-in-CC (other healers only; MiniAuras-style) ---
	local healerActive = HealerCcZoneEnabled()
	RefreshHealerCc(basePath, channel, healerActive)
end

function M:ClearAll()
	ClearMap(enemyByToken)
	enemySignature = nil
	ClearMap(selfCcByToken)
	selfCcSignature = nil
	ClearMap(healerCcByToken)
	healerCcSignature = nil
end

---@return table<string, number>
---@return number
function M:GetRegistrationStats()
	local byToken = {}
	local total = 0
	for token, ids in pairs(enemyByToken) do
		local n = ids and #ids or 0
		byToken[token] = n
		total = total + n
	end
	for token, ids in pairs(selfCcByToken) do
		local n = ids and #ids or 0
		byToken[token .. "(selfCC)"] = n
		total = total + n
	end
	for token, ids in pairs(healerCcByToken) do
		local n = ids and #ids or 0
		byToken[token .. "(healerCC)"] = n
		total = total + n
	end
	return byToken, total
end

---@param spellID number?
function M:PlayTest(spellID)
	spellID = spellID or 45438
	local file = enemyBuffSounds[spellID] or selfCcSounds[spellID]
	if not file then
		print(string.format("|cff33ff99[PVP Sound]|r " .. L["debug_no_spell_map"], spellID))
		return
	end
	local path = voicePack:Path(file)
	if not path then
		print("|cff33ff99[PVP Sound]|r " .. L["debug_voice_file_missing"])
		return
	end
	local ok = PlaySoundFile(path, Channel())
	if ok then
		print(string.format("|cff33ff99[PVP Sound]|r " .. L["debug_preview_ok"], spellID, file))
	else
		print(string.format("|cff33ff99[PVP Sound]|r " .. L["debug_preview_fail"], spellID, path))
	end
end

---@param spellID number
---@return boolean
function M:IsSpellEnabled(spellID)
	spellID = tonumber(spellID) or spellID
	if not db then return true end
	if db.DisabledEnemySpells and db.DisabledEnemySpells[spellID] then
		return false
	end
	if db.Spells and db.Spells[spellID] == false then
		return false
	end
	return true
end

---@param spellID number
---@param enabled boolean
function M:SetSpellEnabled(spellID, enabled)
	if not db then return end
	spellID = tonumber(spellID) or spellID
	db.DisabledEnemySpells = db.DisabledEnemySpells or {}
	db.Spells = db.Spells or {}
	local value = enabled and true or false
	if value then
		db.DisabledEnemySpells[spellID] = nil
	else
		db.DisabledEnemySpells[spellID] = true
	end
	db.Spells[spellID] = value
	spellGeneration = spellGeneration + 1
	self:Refresh("spell-toggle")
end

---Enable/disable one enemy-buff ability (all ID variants sharing the UI row).
---@param spellEntry table { Id, File, Ids? }
---@param enabled boolean
function M:SetSpellGroupEnabled(spellEntry, enabled)
	if not db or not spellEntry then return end
	db.DisabledEnemySpells = db.DisabledEnemySpells or {}
	db.Spells = db.Spells or {}
	local value = enabled and true or false
	local wrote = false
	if spellEntry.Ids then
		for spellId in pairs(spellEntry.Ids) do
			spellId = tonumber(spellId) or spellId
			if value then
				db.DisabledEnemySpells[spellId] = nil
			else
				db.DisabledEnemySpells[spellId] = true
			end
			db.Spells[spellId] = value
			wrote = true
		end
	end
	if not wrote and spellEntry.Id then
		local spellId = tonumber(spellEntry.Id) or spellEntry.Id
		if value then
			db.DisabledEnemySpells[spellId] = nil
		else
			db.DisabledEnemySpells[spellId] = true
		end
		db.Spells[spellId] = value
	end
	spellGeneration = spellGeneration + 1
	self:Refresh("spell-group-toggle")
end

---@param spellEntry table
---@return boolean
function M:IsSpellGroupEnabled(spellEntry)
	if not spellEntry then return false end
	return self:IsSpellEnabled(tonumber(spellEntry.Id) or spellEntry.Id)
end

---@param spellID number
---@return boolean
function M:IsSelfCcEnabled(spellID)
	spellID = tonumber(spellID) or spellID
	if not db then return true end
	if db.DisabledSelfCcSpells and db.DisabledSelfCcSpells[spellID] then
		return false
	end
	if db.SelfCcSpells and db.SelfCcSpells[spellID] == false then
		return false
	end
	return true
end

---Enable/disable one catalog ability (all aura ID variants).
---@param spellEntry table { Id, File, Ids? }
---@param enabled boolean
function M:SetSelfCcGroupEnabled(spellEntry, enabled)
	if not db or not spellEntry then return end
	db.DisabledSelfCcSpells = db.DisabledSelfCcSpells or {}
	db.SelfCcSpells = db.SelfCcSpells or {}
	local value = enabled and true or false
	local wrote = false
	if spellEntry.Ids then
		for spellId in pairs(spellEntry.Ids) do
			spellId = tonumber(spellId) or spellId
			if value then
				db.DisabledSelfCcSpells[spellId] = nil
			else
				db.DisabledSelfCcSpells[spellId] = true
			end
			db.SelfCcSpells[spellId] = value
			wrote = true
		end
	end
	if not wrote and spellEntry.Id then
		local spellId = tonumber(spellEntry.Id) or spellEntry.Id
		if value then
			db.DisabledSelfCcSpells[spellId] = nil
		else
			db.DisabledSelfCcSpells[spellId] = true
		end
		db.SelfCcSpells[spellId] = value
	end
	selfCcGeneration = selfCcGeneration + 1
	self:Refresh("selfcc-toggle")
end

---@param spellEntry table
---@return boolean
function M:IsSelfCcGroupEnabled(spellEntry)
	if not spellEntry then return false end
	return self:IsSelfCcEnabled(spellEntry.Id)
end

---Re-bind to SavedVariables after reset / re-init.
function M:InitDb()
	db = addon.Core.Framework:GetSavedVars()
end

function M:Init()
	self:InitDb()

	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	eventsFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	eventsFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	eventsFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventsFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	eventsFrame:RegisterEvent("DUEL_INBOUNDS")
	eventsFrame:RegisterEvent("DUEL_FINISHED")
	eventsFrame:RegisterUnitEvent("UNIT_FACTION", "target", "focus", "arena1", "arena2", "arena3")
	eventsFrame:SetScript("OnEvent", function(_, event, arg1)
		if event == "NAME_PLATE_UNIT_ADDED" then
			if (not IsTargetFocusOnly()) and units:IsEnemyPlayer(arg1) then
				local basePath = voicePack:GetBasePath()
				if BuffZoneEnabled() and basePath then
					-- Skip if this enemy is already watched as target/focus (different token, same GUID).
					local guid = UnitGUID(arg1)
					local already = false
					if guid and not issecretvalue(guid) then
						for token in pairs(enemyByToken) do
							local g = UnitGUID(token)
							if g and not issecretvalue(g) and g == guid then
								already = true
								break
							end
						end
					end
					if not already then
						RebuildEnabledEnemySounds()
						RegisterEnemyToken(arg1, basePath, Channel())
					end
				end
			end
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			if arg1 and enemyByToken[arg1] then
				auraSounds:RemoveSet(enemyByToken[arg1])
				enemyByToken[arg1] = nil
			end
		else
			M:Refresh(event)
		end
	end)

	-- Dev-only preview stays on the settings Test button (not a public slash).
end
