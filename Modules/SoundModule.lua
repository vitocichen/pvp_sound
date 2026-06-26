---@type string, Addon
local _, addon = ...
local unitWatcher = addon.Core.UnitAuraWatcher
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local eventsFrame
local paused = false
local inPrepRoom = false
local pendingAuraUpdate = false

---@type Db
local db

-- Tracking tables for enemy defensive auras
local previousDefensiveAuras = {}
local currentDefensiveAuras = {}

-- Tracking tables for friendly CC auras
local previousFriendlyCCAuras = {}
local currentFriendlyCCAuras = {}

-- Cached TTS settings (global)
local cachedVoiceID
local cachedTTSVolume
local cachedTTSSpeechRate
local cachedCastInterval

-- Important (offensive) detection via Blizzard nameplate AurasFrame.buffList
-- (same data Platynator reads). This is Blizzard's curated important-buff set
-- before the looser on-screen display layer; stamina/intel etc. are not listed.
-- importantLastSeen[unit] = { [auraInstanceID] = true } from the last refresh.
local importantLastSeen = {}
local hookedAurasFrames = {}

-- Per-frame announce dedup: only one announce per spell-type per frame.
-- Defensive/CC reset at the top of OnAuraDataChanged; important resets at
-- frame end via ScheduleImportantDedupReset (RefreshAuras can fire from many
-- nameplates in one frame, e.g. Shaman Earthgrab hitting three targets).
local announceThisPassImportant = false
local announceThisPassDefensive = false
local announceThisPassCC = false
local pendingImportantDedupReset = false

-- Watchers
local arenaWatchers
local nameplateWatchers = {}
local targetWatcher
local focusWatcher

-- Friendly CC watchers
local friendlyWatchers = {}
local selfCCWatcher

-- Healer CC watchers (for Arena healer-CC TTS)
local healerCCWatchers = {}
local healerCCActive = false -- true while any healer has CC (like MiniCC's IsVisible)

-- Cast bar tracking
local castFrame
local lastCastAnnounceTime = 0
local lastInterruptAnnounceTime = 0

-- Nameplate important-buff hook frame
local importantFrame

---@class SoundModule
local M = {}
addon.Modules.SoundModule = M

local function AnnounceTTS(spellName, spellType)
	if not spellName then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone then return end

	local enabled = false
	if spellType == "important" and zone.ImportantEnabled ~= false and zone.Important then
		enabled = true
	elseif spellType == "defensive" and zone.ImportantEnabled ~= false and zone.Defensive then
		enabled = true
	elseif spellType == "cc" and zone.CCEnabled ~= false and zone.CCMode and zone.CCMode ~= "Off" then
		enabled = true
	end

	if not enabled then return end

	-- Per-frame dedup: only the first announce of each type per frame.
	if spellType == "important" then
		if announceThisPassImportant then return end
		announceThisPassImportant = true
	elseif spellType == "defensive" then
		if announceThisPassDefensive then return end
		announceThisPassDefensive = true
	elseif spellType == "cc" then
		if announceThisPassCC then return end
		announceThisPassCC = true
	end

	pcall(function()
		local speechRate = cachedTTSSpeechRate or 7
		C_VoiceChat.SpeakText(cachedVoiceID, spellName, speechRate, cachedTTSVolume, true)
	end)
end

local function ScheduleImportantDedupReset()
	if pendingImportantDedupReset then return end
	pendingImportantDedupReset = true
	C_Timer.After(0, function()
		pendingImportantDedupReset = false
		announceThisPassImportant = false
	end)
end

local function ShouldAnnounceImportantForUnit(unit)
	local zone = moduleUtil:GetZoneConfig()
	if not zone or zone.ImportantEnabled == false or not zone.Important then
		return false
	end

	local _, instanceType = IsInInstance()
	if instanceType ~= "arena"
		and zone.TargetFocusOnly ~= false
		and not (UnitIsUnit(unit, "target") or UnitIsUnit(unit, "focus")) then
		return false
	end

	return true
end

local function GetNameplateAurasFrame(unit)
	local np = C_NamePlate.GetNamePlateForUnit(unit)
	if not np or not np.UnitFrame then return end
	-- Default UI uses BuffFrame for buffs specifically, or AurasFrame as a container.
	return np.UnitFrame.BuffFrame or np.UnitFrame.AurasFrame
end

-- Blizzard's curated important buff ids (AurasFrame.buffList), not on-screen icons.
local function ForEachImportantBuffId(unit, callback)
	local af = GetNameplateAurasFrame(unit)
	if not af or not af.buffList then return end

	if type(af.buffList) == "table" and af.buffList.Iterate then
		pcall(function()
			af.buffList:Iterate(function(auraInstanceID)
				if auraInstanceID ~= nil then
					callback(auraInstanceID)
				end
			end)
		end)
	elseif type(af.buffList) == "table" then
		-- Fallback for standard table iteration
		for _, auraInstanceID in ipairs(af.buffList) do
			if auraInstanceID ~= nil then
				callback(auraInstanceID)
			end
		end
	end
end

local function CollectImportantBuffIds(unit)
	local ids = {}
	ForEachImportantBuffId(unit, function(id)
		ids[id] = true
	end)
	return ids
end

-- Defensives are announced separately; skip them in the important path.
local function CollectDefensiveIds(unit)
	local ids = {}
	for _, filter in ipairs({ "HELPFUL|BIG_DEFENSIVE", "HELPFUL|EXTERNAL_DEFENSIVE" }) do
		for i = 1, 40 do
			local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
			if not a then break end
			local id = a.auraInstanceID
			if id ~= nil then
				ids[id] = true
			end
		end
	end
	return ids
end

-- "Simple" filter mode (same as MiniCC): treats a buff as junk when the player can
-- dispel/steal it AND it isn't a defensive cooldown. This drops purgeable junk like
-- Intellect/Rejuvenation, but also drops purgeable utility like Blessing of Freedom.
local function IsPurgeableNonDefensive(unit, auraInstanceID)
	return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|RAID_PLAYER_DISPELLABLE")
		and C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
		and C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
end

-- "Simple" (default) filters purgeable non-defensive buffs; "Detailed" announces
-- everything Blizzard lists on the nameplate.
local function GetImportantFilterMode()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return "Simple" end
	return zone.ImportantFilterMode or "Simple"
end

local function OnImportantBuffsRefreshed(unit)
	if not unit or not UnitExists(unit) or not units:IsEnemy(unit) then return end

	local current = CollectImportantBuffIds(unit)
	local lastSeen = importantLastSeen[unit]
	if not lastSeen then
		importantLastSeen[unit] = current
		return
	end

	if paused or inPrepRoom then
		importantLastSeen[unit] = current
		return
	end
	if not moduleUtil:IsEnabled() then
		importantLastSeen[unit] = current
		return
	end

	local shouldAnnounce = ShouldAnnounceImportantForUnit(unit)
	if shouldAnnounce then
		ScheduleImportantDedupReset()
		local defensiveIds = CollectDefensiveIds(unit)
		local simpleMode = GetImportantFilterMode() == "Simple"
		for id in pairs(current) do
			if not lastSeen[id] and not defensiveIds[id] then
				if announceThisPassImportant then break end
				-- 简易版：额外剔除“可驱散 + 非减伤”的垃圾 buff（同 MiniCC，但自由祝福也会被剔除）
				-- 详细版：暴雪姓名板列表显示什么就播报什么（含自由祝福，可能多回春/智力等）
				if not (simpleMode and IsPurgeableNonDefensive(unit, id)) then
					local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
					if data and data.name then
						AnnounceTTS(data.name, "important")
					end
				end
			end
		end
	end

	importantLastSeen[unit] = current
end

local HOOK_RETRY_MAX = 5

local function HookNameplateImportantBuffs(unit, retryCount)
	if not unit or not units:IsEnemy(unit) then return end
	retryCount = retryCount or 0

	local af = GetNameplateAurasFrame(unit)
	if not af then
		if retryCount < HOOK_RETRY_MAX then
			C_Timer.After(0, function()
				if unit and UnitExists(unit) and units:IsEnemy(unit) then
					HookNameplateImportantBuffs(unit, retryCount + 1)
				end
			end)
		end
		return
	end
	if hookedAurasFrames[af] then return end

	hookedAurasFrames[af] = true
	importantLastSeen[unit] = CollectImportantBuffIds(unit)

	pcall(function()
		hooksecurefunc(af, "RefreshAuras", function(frame)
			if frame:IsForbidden() then return end
			local parent = frame.GetParent and frame:GetParent()
			local refreshedUnit = parent and parent.unit
			if refreshedUnit then
				OnImportantBuffsRefreshed(refreshedUnit)
			end
		end)
	end)
end

local function UnhookNameplateImportantBuffs(unit)
	importantLastSeen[unit] = nil
end

local function ProcessEnemyWatcherData(watcher)
	local unit = watcher:GetUnit()
	if not unit or not UnitExists(unit) then return end

	local defensivesData = watcher:GetDefensiveState()

	for _, data in ipairs(defensivesData) do
		if data.AuraInstanceID then
			if not currentDefensiveAuras[data.AuraInstanceID]
				and not previousDefensiveAuras[data.AuraInstanceID] then
				AnnounceTTS(data.SpellName, "defensive")
			end
			currentDefensiveAuras[data.AuraInstanceID] = true
		end
	end
end

local function ProcessFriendlyCCData(watcher)
	local unit = watcher:GetUnit()
	if not unit or not UnitExists(unit) then return end

	local ccData = watcher:GetCcState()

	for _, data in ipairs(ccData) do
		if data.AuraInstanceID then
			if not currentFriendlyCCAuras[data.AuraInstanceID]
				and not previousFriendlyCCAuras[data.AuraInstanceID] then
				AnnounceTTS(data.SpellName, "cc")
			end
			currentFriendlyCCAuras[data.AuraInstanceID] = true
		end
	end
end

local function AnnounceHealerCC(zone)
	if not zone then return end
	local mode = zone.HealerCCMode or "TTS"
	if mode == "Sound" then
		local fileName = zone.HealerCCSoundFile or "夏一可_控制成功.ogg"
		local path = "Interface\\AddOns\\PVP_Sound\\Media\\" .. fileName
		pcall(PlaySoundFile, path, "Master")
	else
		local text = zone.HealerCCText or "治疗被控"
		if not text or text == "" then return end
		pcall(function()
			local speechRate = cachedTTSSpeechRate or 7
			C_VoiceChat.SpeakText(cachedVoiceID, text, speechRate, cachedTTSVolume, true)
		end)
	end
end

local function ProcessHealerCCData(watcher)
	local unit = watcher:GetUnit()
	if not unit or not UnitExists(unit) then return false end

	local ccData = watcher:GetCcState()
	return #ccData > 0
end

local function GetCCMode()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return "Off" end
	if zone.CCEnabled == false then return "Off" end
	return zone.CCMode or "Off"
end

local function GetTargetFocusOnly()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return true end
	return zone.TargetFocusOnly ~= false
end

local function GetCastBarMode()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return "TargetOnly" end
	local val = zone.CastBarTargetOnly
	if val == "TargetingMe" then return "TargetingMe" end
	if val ~= false then return "TargetOnly" end
	return "All"
end

local function IsCastTargetingPlayer(unit)
	-- Method 1: check caster's current target via explicit compound unit tokens
	if unit == "target" then
		if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
			return true
		end
	elseif unit == "focus" then
		if UnitExists("focustarget") and UnitIsUnit("focustarget", "player") then
			return true
		end
	else
		-- arena/nameplate/boss units: try compound token
		local casterTarget = unit .. "target"
		if UnitExists(casterTarget) and UnitIsUnit(casterTarget, "player") then
			return true
		end
		-- Also cross-check via "target"/"focus" if this unit matches
		if UnitExists("target") and UnitIsUnit(unit, "target") then
			if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
				return true
			end
		end
		if UnitExists("focus") and UnitIsUnit(unit, "focus") then
			if UnitExists("focustarget") and UnitIsUnit("focustarget", "player") then
				return true
			end
		end
	end

	-- Method 2: UnitSpellTargetName (catches @focus macro casts where
	-- the caster's target isn't the player but the spell target is)
	if UnitSpellTargetName then
		local playerName = UnitName("player")
		local name = UnitSpellTargetName(unit)
		if name and name == playerName then return true end
		if UnitExists("target") and UnitIsUnit(unit, "target") then
			name = UnitSpellTargetName("target")
			if name and name == playerName then return true end
		end
		if UnitExists("focus") and UnitIsUnit(unit, "focus") then
			name = UnitSpellTargetName("focus")
			if name and name == playerName then return true end
		end
	end

	-- Method 3: For NPCs, use threat as heuristic.
	-- If the player is the mob's primary target (tanking / highest threat),
	-- the mob's cast is very likely directed at the player.
	if not UnitIsPlayer(unit) then
		local threat = UnitThreatSituation("player", unit)
		if threat and threat >= 2 then
			return true
		end
	end

	return false
end

local function AnnounceCast(spellName)
	if not spellName then return end

	-- Interval check: always enforce a minimum 0.05s gap to prevent
	-- duplicate announces from the same cast arriving via multiple
	-- unitIDs (e.g. "arena2" + "target" + "nameplate7" in the same frame).
	local now = GetTime()
	local minInterval = cachedCastInterval and cachedCastInterval > 0 and cachedCastInterval or 0.05
	if now - lastCastAnnounceTime < minInterval then return end
	lastCastAnnounceTime = now

	pcall(function()
		local speechRate = cachedTTSSpeechRate or 7
		C_VoiceChat.SpeakText(cachedVoiceID, spellName, speechRate, cachedTTSVolume, true)
	end)
end

local function CheckTargetCast()
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.CastBar then return end

	local mode = GetCastBarMode()
	if mode ~= "TargetOnly" and mode ~= "TargetingMe" then return end

	if not UnitExists("target") or not units:IsEnemy("target") then return end

	-- Exclude pet/guardian casts if the option is enabled, even when the pet is
	-- the current target (the user wants pet casts fully ignored).
	if zone.CastBarExcludePets ~= false and units:IsPetOrMinion("target") then return end

	-- For TargetingMe mode, only announce if the target is casting at the player
	if mode == "TargetingMe" and not IsCastTargetingPlayer("target") then return end

	local spellName = UnitCastingInfo("target")
	if not spellName then
		spellName = UnitChannelInfo("target")
	end
	if not spellName then return end

	AnnounceCast(spellName)
end

local function GetCastSpellName(unit, spellID)
	local spellName
	if spellID then
		spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
	end
	if not spellName then
		spellName = UnitCastingInfo(unit)
	end
	if not spellName then
		spellName = UnitChannelInfo(unit)
	end
	return spellName
end

local function OnCastEvent(unit, spellID)
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.CastBar then return end

	local mode = GetCastBarMode()

	if mode == "TargetOnly" then
		if unit ~= "target" then return end
		if not UnitExists("target") or not units:IsEnemy("target") then return end
	elseif mode == "TargetingMe" then
		if not unit or not UnitExists(unit) then return end
		if not units:IsEnemy(unit) then return end
		if zone.CastBarExcludePets ~= false and units:IsPetOrMinion(unit) then return end

		local spellName = GetCastSpellName(unit, spellID) or tostring(spellID or "cast")

		if IsCastTargetingPlayer(unit) then
			AnnounceCast(spellName)
			return
		end

		-- UnitSpellTargetName may not be populated yet at UNIT_SPELLCAST_START;
		-- retry after a short delay (similar to InsaneForPvP's OnValueChanged polling).
		C_Timer.After(0.15, function()
			if not UnitExists(unit) then return end
			if not (UnitCastingInfo(unit) or UnitChannelInfo(unit)) then return end
			if IsCastTargetingPlayer(unit) then
				AnnounceCast(spellName)
			end
		end)
		return
	else -- "All"
		if not unit or not UnitExists(unit) then return end
		if not units:IsEnemy(unit) then return end
	end

	-- Exclude pet/guardian casts if option is enabled
	if zone.CastBarExcludePets ~= false and units:IsPetOrMinion(unit) then
		return
	end

	local spellName = GetCastSpellName(unit, spellID) or tostring(spellID or "cast")
	AnnounceCast(spellName)
end

local function OnCastInterrupted(unit)
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.InterruptAlert then return end

	local mode = zone.InterruptMode or "Target"

	-- Filter unit based on InterruptMode
	if mode == "Target" then
		if unit ~= "target" then return end
		if not UnitExists("target") or not units:IsEnemy("target") then return end
	elseif mode == "TargetFocus" then
		if unit ~= "target" and unit ~= "focus" then return end
		if not UnitExists(unit) or not units:IsEnemy(unit) then return end
	else -- "All"
		if not unit or not UnitExists(unit) then return end
		if not units:IsEnemy(unit) then return end
	end

	-- Exclude pet/guardian interrupts if option is enabled
	if zone.InterruptExcludePets ~= false and units:IsPetOrMinion(unit) then
		return
	end

	-- Throttle: at most once per second
	local now = GetTime()
	if now - lastInterruptAnnounceTime < 1 then return end
	lastInterruptAnnounceTime = now

	local text = addon.L["Interrupted"] or "Interrupted"
	pcall(function()
		local speechRate = cachedTTSSpeechRate or 7
		C_VoiceChat.SpeakText(cachedVoiceID, text, speechRate, cachedTTSVolume, true)
	end)
end

local function OnAuraDataChanged()
	if paused then return end
	if not moduleUtil:IsEnabled() then return end

	if inPrepRoom then return end

	-- Reset per-frame announce flags so each type can announce once this pass
	announceThisPassDefensive = false
	announceThisPassCC = false

	wipe(currentDefensiveAuras)
	wipe(currentFriendlyCCAuras)

	local inInstance, instanceType = IsInInstance()

	-- Process enemy watchers (arena)
	if instanceType == "arena" then
		for _, watcher in ipairs(arenaWatchers) do
			ProcessEnemyWatcherData(watcher)
		end
	end

	-- Process enemy watchers (World/BG)
	if instanceType == "pvp" or not inInstance then
		local targetFocusOnly = GetTargetFocusOnly()
		if targetFocusOnly then
			for _, pair in ipairs({ { targetWatcher, "target" }, { focusWatcher, "focus" } }) do
				local watcher, unit = pair[1], pair[2]
				if watcher and UnitExists(unit) and units:IsEnemy(unit) then
					ProcessEnemyWatcherData(watcher)
				end
			end
		else
			for _, watcher in pairs(nameplateWatchers) do
				ProcessEnemyWatcherData(watcher)
			end
		end
	end

	-- Process enemy watchers (PvE)
	if instanceType == "party" or instanceType == "raid" then
		local targetFocusOnly = GetTargetFocusOnly()
		if targetFocusOnly then
			for _, pair in ipairs({ { targetWatcher, "target" }, { focusWatcher, "focus" } }) do
				local watcher, unit = pair[1], pair[2]
				if watcher and UnitExists(unit) and units:IsEnemy(unit) then
					ProcessEnemyWatcherData(watcher)
				end
			end
		else
			for _, watcher in pairs(nameplateWatchers) do
				ProcessEnemyWatcherData(watcher)
			end
		end
	end

	-- Process friendly CC watchers
	local ccMode = GetCCMode()
	if ccMode ~= "Off" then
		if ccMode == "Self" or ccMode == "All" then
			if selfCCWatcher then
				ProcessFriendlyCCData(selfCCWatcher)
			end
		end
		if ccMode == "Party" or ccMode == "All" then
			for _, watcher in ipairs(friendlyWatchers) do
				ProcessFriendlyCCData(watcher)
			end
		end
	end

	-- Process healer CC watchers (Arena and BattleGrounds)
	-- Skip if player is the healer (no need to alert yourself)
	if (instanceType == "arena" or instanceType == "pvp") and not units:IsHealer("player") then
		local zone2 = moduleUtil:GetZoneConfig()
		if zone2 and zone2.HealerCC then
			local anyHealerCCed = false
			for _, watcher in ipairs(healerCCWatchers) do
				if not UnitIsUnit(watcher:GetUnit(), "player") and ProcessHealerCCData(watcher) then
					anyHealerCCed = true
				end
			end

			-- Only announce when transitioning from no-CC to CC (like MiniCC)
			if anyHealerCCed then
				if not healerCCActive then
					healerCCActive = true
					AnnounceHealerCC(zone2)
				end
			else
				healerCCActive = false
			end
		end
	end

	-- Swap buffers
	previousDefensiveAuras, currentDefensiveAuras = currentDefensiveAuras, previousDefensiveAuras
	previousFriendlyCCAuras, currentFriendlyCCAuras = currentFriendlyCCAuras, previousFriendlyCCAuras
end

local function ScheduleAuraDataUpdate()
	if pendingAuraUpdate then return end
	pendingAuraUpdate = true
	C_Timer.After(0, function()
		pendingAuraUpdate = false
		OnAuraDataChanged()
	end)
end

local function OnMatchStateChanged()
	local matchState = C_PvP.GetActiveMatchState()
	inPrepRoom = matchState == Enum.PvPMatchState.StartUp

	if not inPrepRoom then return end

	for _, watcher in ipairs(arenaWatchers) do
		watcher:ClearState(true)
	end
	for _, watcher in pairs(nameplateWatchers) do
		watcher:ClearState(true)
	end
	if targetWatcher then targetWatcher:ClearState(true) end
	if focusWatcher then focusWatcher:ClearState(true) end
	if selfCCWatcher then selfCCWatcher:ClearState(true) end
	for _, watcher in ipairs(friendlyWatchers) do
		watcher:ClearState(true)
	end
	for _, watcher in ipairs(healerCCWatchers) do
		watcher:ClearState(true)
	end

	previousDefensiveAuras = {}
	previousFriendlyCCAuras = {}
	healerCCActive = false
	wipe(importantLastSeen)
end

local function OnNamePlateAdded(unitToken)
	if nameplateWatchers[unitToken] then
		nameplateWatchers[unitToken]:Dispose()
		nameplateWatchers[unitToken] = nil
	end

	if not units:IsEnemy(unitToken) then return end

	local watcherFilter = { Defensive = true }
	local watcher = unitWatcher:New(unitToken, nil, watcherFilter)
	watcher:RegisterCallback(ScheduleAuraDataUpdate)
	nameplateWatchers[unitToken] = watcher

	ScheduleAuraDataUpdate()
end

local function OnNamePlateRemoved(unitToken)
	UnhookNameplateImportantBuffs(unitToken)

	if nameplateWatchers[unitToken] then
		nameplateWatchers[unitToken]:Dispose()
		nameplateWatchers[unitToken] = nil
		ScheduleAuraDataUpdate()
	end
end

local function ClearNamePlateWatchers()
	for unitToken, watcher in pairs(nameplateWatchers) do
		watcher:Dispose()
		nameplateWatchers[unitToken] = nil
	end
end

local function DisableTargetFocusWatchers()
	if targetWatcher then targetWatcher:Disable() end
	if focusWatcher then focusWatcher:Disable() end
end

local function EnableTargetFocusWatchers()
	if targetWatcher then targetWatcher:Enable() end
	if focusWatcher then focusWatcher:Enable() end
end

local function HookAllEnemyNameplates()
	for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		local unitToken = nameplate.unitToken
		if unitToken and units:IsEnemy(unitToken) then
			HookNameplateImportantBuffs(unitToken)
		end
	end
end

local function RebuildNameplateWatchers()
	local activeTokens = {}
	for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		local unitToken = nameplate.unitToken
		if unitToken and units:IsEnemy(unitToken) then
			activeTokens[unitToken] = true
		end
	end

	for unitToken, watcher in pairs(nameplateWatchers) do
		if not activeTokens[unitToken] then
			watcher:Dispose()
			nameplateWatchers[unitToken] = nil
		end
	end

	for unitToken in pairs(activeTokens) do
		if not nameplateWatchers[unitToken] then
			OnNamePlateAdded(unitToken)
		end
	end
end

local function DisposeFriendlyWatchers()
	for _, watcher in ipairs(friendlyWatchers) do
		watcher:Dispose()
	end
	wipe(friendlyWatchers)
end

local function RebuildFriendlyWatchers()
	DisposeFriendlyWatchers()

	local ccMode = GetCCMode()
	if ccMode ~= "All" and ccMode ~= "Party" then return end

	local ccFilter = { CC = true }
	local friendlyUnits = units:FriendlyUnits()

	for _, unit in ipairs(friendlyUnits) do
		if not units:IsPetOrMinion(unit) then
			local watcher = unitWatcher:New(unit, nil, ccFilter)
			watcher:RegisterCallback(ScheduleAuraDataUpdate)
			friendlyWatchers[#friendlyWatchers + 1] = watcher
		end
	end
end

local function DisposeHealerCCWatchers()
	for _, watcher in ipairs(healerCCWatchers) do
		watcher:Dispose()
	end
	wipe(healerCCWatchers)
end

local function RebuildHealerCCWatchers()
	DisposeHealerCCWatchers()

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.HealerCC then return end

	-- Only in arena or battlegrounds
	local inInstance, instanceType = IsInInstance()
	if instanceType ~= "arena" and instanceType ~= "pvp" then return end

	-- Find friendly healers (same as mini-cc)
	local healers = units:FindHealers()
	local ccFilter = { CC = true }

	for _, healerUnit in ipairs(healers) do
		local watcher = unitWatcher:New(healerUnit, nil, ccFilter)
		watcher:RegisterCallback(ScheduleAuraDataUpdate)
		healerCCWatchers[#healerCCWatchers + 1] = watcher
	end
end

local function DisableWatchers()
	for _, watcher in ipairs(arenaWatchers) do
		watcher:Disable()
	end
	for _, watcher in pairs(nameplateWatchers) do
		watcher:Disable()
	end
	if targetWatcher then targetWatcher:Disable() end
	if focusWatcher then focusWatcher:Disable() end
	if selfCCWatcher then selfCCWatcher:Disable() end
	DisposeFriendlyWatchers()
	DisposeHealerCCWatchers()

	previousDefensiveAuras = {}
	previousFriendlyCCAuras = {}
	healerCCActive = false
	wipe(importantLastSeen)
end

local function EnableDisable()
	local moduleEnabled = moduleUtil:IsEnabled()

	if not moduleEnabled then
		DisableWatchers()
		return
	end

	local inInstance, instanceType = IsInInstance()
	local ccMode = GetCCMode()
	local targetFocusOnly = GetTargetFocusOnly()

	-- Arena watchers
	if instanceType == "arena" then
		for _, watcher in ipairs(arenaWatchers) do
			watcher:Enable()
		end
	else
		for _, watcher in ipairs(arenaWatchers) do
			watcher:Disable()
		end
	end

	-- Build healer CC watchers in arena and battlegrounds
	if instanceType == "arena" or instanceType == "pvp" then
		RebuildHealerCCWatchers()
	else
		DisposeHealerCCWatchers()
	end

	-- World/BG/PvE watchers (target/focus or nameplate)
	if instanceType == "pvp" or instanceType == "party" or instanceType == "raid" or not inInstance then
		if targetFocusOnly then
			EnableTargetFocusWatchers()
			ClearNamePlateWatchers()
		else
			DisableTargetFocusWatchers()
			RebuildNameplateWatchers()
		end
	else
		if instanceType ~= "arena" then
			ClearNamePlateWatchers()
			DisableTargetFocusWatchers()
		end
	end

	-- Friendly CC watchers
	if ccMode ~= "Off" then
		if ccMode == "Self" or ccMode == "All" then
			if selfCCWatcher then selfCCWatcher:Enable() end
		else
			if selfCCWatcher then selfCCWatcher:Disable() end
		end
		if ccMode == "All" or ccMode == "Party" then
			RebuildFriendlyWatchers()
		else
			DisposeFriendlyWatchers()
		end
	else
		if selfCCWatcher then selfCCWatcher:Disable() end
		DisposeFriendlyWatchers()
	end

	ScheduleAuraDataUpdate()
	HookAllEnemyNameplates()
end

local function CacheTTSSettings()
	local tts = db.TTS or {}
	cachedVoiceID = tts.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
	cachedTTSVolume = tts.Volume or 100
	cachedTTSSpeechRate = tts.SpeechRate or 7
	cachedCastInterval = tts.CastInterval or 0
end

function M:Refresh()
	-- Re-sync the prep-room gate from the real match state. It is otherwise only
	-- updated on PVP_MATCH_STATE_CHANGED; if the "left the arena" event is ever
	-- missed, inPrepRoom would stay true and silence ALL announcements until a
	-- /reload. Refresh runs on PLAYER_ENTERING_WORLD, so this self-heals.
	OnMatchStateChanged()
	CacheTTSSettings()
	EnableDisable()
end

function M:Init()
	local mini = addon.Core.Framework
	db = mini:GetSavedVars()

	CacheTTSSettings()

	-- Initialize arena watchers (enemy defensives; important from AurasFrame.buffList).
	local enemyFilter = { Defensive = true }
	local arenaEvents = { "ARENA_OPPONENT_UPDATE" }
	arenaWatchers = {
		unitWatcher:New("arena1", arenaEvents, enemyFilter),
		unitWatcher:New("arena2", arenaEvents, enemyFilter),
		unitWatcher:New("arena3", arenaEvents, enemyFilter),
	}
	for _, watcher in ipairs(arenaWatchers) do
		watcher:RegisterCallback(ScheduleAuraDataUpdate)
	end

	-- Initialize target/focus watchers (enemy defensives)
	targetWatcher = unitWatcher:New("target", { "PLAYER_TARGET_CHANGED" }, enemyFilter)
	targetWatcher:RegisterCallback(ScheduleAuraDataUpdate)

	focusWatcher = unitWatcher:New("focus", { "PLAYER_FOCUS_CHANGED" }, enemyFilter)
	focusWatcher:RegisterCallback(ScheduleAuraDataUpdate)

	-- Initialize self CC watcher
	local ccFilter = { CC = true }
	selfCCWatcher = unitWatcher:New("player", nil, ccFilter)
	selfCCWatcher:RegisterCallback(ScheduleAuraDataUpdate)

	-- Events frame
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
	eventsFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	eventsFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	eventsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventsFrame:SetScript("OnEvent", function(_, event, unitToken)
		if event == "PVP_MATCH_STATE_CHANGED" then
			OnMatchStateChanged()
		elseif event == "NAME_PLATE_UNIT_ADDED" then
			if moduleUtil:IsEnabled() then
				local inInstance, instanceType = IsInInstance()
				if instanceType ~= "arena" and not GetTargetFocusOnly() then
					OnNamePlateAdded(unitToken)
				end
			end
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			OnNamePlateRemoved(unitToken)
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			EnableDisable()
		elseif event == "GROUP_ROSTER_UPDATE" then
			local ccMode = GetCCMode()
			if (ccMode == "All" or ccMode == "Party") and moduleUtil:IsEnabled() then
				RebuildFriendlyWatchers()
			end
			-- Refresh healer CC watchers on roster change (arena and battlegrounds)
			local inInst, instType = IsInInstance()
			if (instType == "arena" or instType == "pvp") and moduleUtil:IsEnabled() then
				RebuildHealerCCWatchers()
			end
		end
	end)

	-- Cast bar frame: detect target casting and interrupts via events
	castFrame = CreateFrame("Frame")
	castFrame:RegisterEvent("UNIT_SPELLCAST_START")
	castFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	castFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	castFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	castFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	castFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
		if event == "PLAYER_TARGET_CHANGED" then
			CheckTargetCast()
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			OnCastInterrupted(unit)
		else
			OnCastEvent(unit, spellID)
		end
	end)

	-- Important buff detection: hook Blizzard nameplate AurasFrame.RefreshAuras.
	importantFrame = CreateFrame("Frame")
	importantFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	importantFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	importantFrame:SetScript("OnEvent", function(_, event, unit)
		if event == "NAME_PLATE_UNIT_ADDED" then
			if units:IsEnemy(unit) then
				HookNameplateImportantBuffs(unit)
			end
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			UnhookNameplateImportantBuffs(unit)
		end
	end)

	EnableDisable()
	HookAllEnemyNameplates()
end
