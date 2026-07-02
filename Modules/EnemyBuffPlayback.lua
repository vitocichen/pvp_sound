---@type string, Addon
local _, addon = ...

local unitWatcher = addon.Core.UnitAuraWatcher
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local spellSoundMap = addon.Data.SpellSoundMap.SPELL_TO_SOUND

local MEDIA_PREFIX = "Interface\\AddOns\\PVP_Sound\\Media\\"
local IMPORTANT_ANNOUNCE_INTERVAL = 1.0
local HOOK_RETRY_MAX = 5

---@class EnemyBuffPlaybackModule
local M = {}
addon.Modules.EnemyBuffPlayback = M

local scheduleUpdate
local paused = false
local inPrepRoom = false

local previousDefensiveAuras = {}
local currentDefensiveAuras = {}
local importantLastSeen = {}
local hookedAurasFrames = {}

local announceThisPassImportant = false
local announceThisPassDefensive = false
local pendingImportantDedupReset = false
local lastImportantAnnounceTime = 0

local arenaWatchers
local nameplateWatchers = {}
local targetWatcher
local focusWatcher
local eventsFrame

local function IsFeatureEnabled()
	local zone = moduleUtil:GetZoneConfig()
	if not zone or zone.ImportantEnabled == false then return false end
	return zone.Important or zone.Defensive
end

local function GetSoundPath(spellID)
	local fileName = spellSoundMap[spellID]
	if not fileName or fileName == "" then return nil end
	return MEDIA_PREFIX .. fileName
end

local function PlayMappedSound(spellID)
	local path = GetSoundPath(spellID)
	if not path then return false end
	pcall(PlaySoundFile, path, "Master")
	return true
end

local function ScheduleImportantDedupReset()
	if pendingImportantDedupReset then return end
	pendingImportantDedupReset = true
	C_Timer.After(0, function()
		pendingImportantDedupReset = false
		announceThisPassImportant = false
	end)
end

local function GetTargetFocusOnly()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return true end
	return zone.TargetFocusOnly ~= false
end

local function GetImportantFilterMode()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return "Simple" end
	return zone.ImportantFilterMode or "Simple"
end

local function ShouldTrackUnit(unit)
	return units:IsEnemyPlayer(unit)
end

local function ShouldAnnounceImportantForUnit(unit)
	local zone = moduleUtil:GetZoneConfig()
	if not zone or zone.ImportantEnabled == false or not zone.Important then
		return false
	end
	if not ShouldTrackUnit(unit) then return false end

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
	local af = np.UnitFrame.AurasFrame
	if af and af.IsForbidden and af:IsForbidden() then return end
	return af
end

local function ForEachImportantBuffId(unit, callback)
	local af = GetNameplateAurasFrame(unit)
	if not af or not af.buffList or not af.buffList.Iterate then return end

	pcall(function()
		af.buffList:Iterate(function(auraInstanceID)
			if auraInstanceID ~= nil then
				callback(auraInstanceID)
			end
		end)
	end)
end

local function CollectImportantBuffIds(unit)
	local ids = {}
	ForEachImportantBuffId(unit, function(id)
		ids[id] = true
	end)
	return ids
end

local function CollectDefensiveIds(unit)
	local ids = {}
	for _, filter in ipairs({ "HELPFUL|BIG_DEFENSIVE", "HELPFUL|EXTERNAL_DEFENSIVE" }) do
		for i = 1, 40 do
			local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
			if not aura then break end
			local id = aura.auraInstanceID
			if id ~= nil then ids[id] = true end
		end
	end
	return ids
end

local function IsPurgeableNonDefensive(unit, auraInstanceID)
	return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|RAID_PLAYER_DISPELLABLE")
		and C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
		and C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
end

local function ShouldAnnounceImportantBuff(unit, auraInstanceID, simpleMode)
	if not simpleMode then return true end

	if units:IsFriend(unit) then
		if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HELPFUL|INCLUDE_NAME_PLATE_ONLY|RAID_IN_COMBAT|PLAYER") then
			return false
		end
	end

	if IsPurgeableNonDefensive(unit, auraInstanceID) then
		return false
	end

	return true
end

local function TryPlayImportant(spellID)
	if announceThisPassImportant then return end
	if GetTime() - lastImportantAnnounceTime < IMPORTANT_ANNOUNCE_INTERVAL then return end
	if PlayMappedSound(spellID) then
		announceThisPassImportant = true
		lastImportantAnnounceTime = GetTime()
	end
end

local function TryPlayDefensive(spellID)
	if announceThisPassDefensive then return end
	if PlayMappedSound(spellID) then
		announceThisPassDefensive = true
	end
end

local function OnImportantBuffsRefreshed(unit)
	if not ShouldTrackUnit(unit) then return end

	local current = CollectImportantBuffIds(unit)
	local lastSeen = importantLastSeen[unit]
	if not lastSeen then
		importantLastSeen[unit] = current
		return
	end

	if paused or inPrepRoom or not moduleUtil:IsEnabled() or not IsFeatureEnabled() then
		importantLastSeen[unit] = current
		return
	end

	if ShouldAnnounceImportantForUnit(unit) then
		ScheduleImportantDedupReset()
		local defensiveIds = CollectDefensiveIds(unit)
		local simpleMode = GetImportantFilterMode() == "Simple"
		for id in pairs(current) do
			if not lastSeen[id] and not defensiveIds[id] then
				if announceThisPassImportant then break end
				if ShouldAnnounceImportantBuff(unit, id, simpleMode) then
					local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
					if data and data.spellId then
						TryPlayImportant(data.spellId)
					end
				end
			end
		end
	end

	importantLastSeen[unit] = current
end

local function HookNameplateImportantBuffs(unit, retryCount)
	if not ShouldTrackUnit(unit) then return end
	retryCount = retryCount or 0

	local af = GetNameplateAurasFrame(unit)
	if not af then
		if retryCount < HOOK_RETRY_MAX then
			C_Timer.After(0, function()
				if ShouldTrackUnit(unit) then
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
	if not ShouldTrackUnit(unit) then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or zone.ImportantEnabled == false or not zone.Defensive then return end

	for _, data in ipairs(watcher:GetDefensiveState()) do
		if data.AuraInstanceID and data.SpellId then
			if not currentDefensiveAuras[data.AuraInstanceID]
				and not previousDefensiveAuras[data.AuraInstanceID] then
				TryPlayDefensive(data.SpellId)
			end
			currentDefensiveAuras[data.AuraInstanceID] = true
		end
	end
end

local function HookAllEnemyNameplates()
	for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		local unitToken = nameplate.unitToken
		if ShouldTrackUnit(unitToken) then
			HookNameplateImportantBuffs(unitToken)
		end
	end
end

local function OnNamePlateAdded(unitToken)
	if not ShouldTrackUnit(unitToken) then return end

	if nameplateWatchers[unitToken] then
		nameplateWatchers[unitToken]:Dispose()
		nameplateWatchers[unitToken] = nil
	end

	local watcher = unitWatcher:New(unitToken, nil, { Defensive = true })
	watcher:RegisterCallback(scheduleUpdate)
	nameplateWatchers[unitToken] = watcher
	HookNameplateImportantBuffs(unitToken)
	scheduleUpdate()
end

local function OnNamePlateRemoved(unitToken)
	UnhookNameplateImportantBuffs(unitToken)
	if nameplateWatchers[unitToken] then
		nameplateWatchers[unitToken]:Dispose()
		nameplateWatchers[unitToken] = nil
		scheduleUpdate()
	end
end

local function ClearNamePlateWatchers()
	for unitToken, watcher in pairs(nameplateWatchers) do
		watcher:Dispose()
		nameplateWatchers[unitToken] = nil
	end
end

local function RebuildNameplateWatchers()
	local activeTokens = {}
	for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		local unitToken = nameplate.unitToken
		if ShouldTrackUnit(unitToken) then
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

local function ProcessWatchersForInstance(instanceType, inInstance)
	if instanceType == "arena" then
		for _, watcher in ipairs(arenaWatchers) do
			ProcessEnemyWatcherData(watcher)
		end
	end

	if instanceType == "pvp" or not inInstance then
		if GetTargetFocusOnly() then
			for _, pair in ipairs({ { targetWatcher, "target" }, { focusWatcher, "focus" } }) do
				local watcher, unit = pair[1], pair[2]
				if watcher and ShouldTrackUnit(unit) then
					ProcessEnemyWatcherData(watcher)
				end
			end
		else
			for _, watcher in pairs(nameplateWatchers) do
				ProcessEnemyWatcherData(watcher)
			end
		end
	end

	if instanceType == "party" or instanceType == "raid" then
		if GetTargetFocusOnly() then
			for _, pair in ipairs({ { targetWatcher, "target" }, { focusWatcher, "focus" } }) do
				local watcher, unit = pair[1], pair[2]
				if watcher and ShouldTrackUnit(unit) then
					ProcessEnemyWatcherData(watcher)
				end
			end
		else
			for _, watcher in pairs(nameplateWatchers) do
				ProcessEnemyWatcherData(watcher)
			end
		end
	end
end

function M:SetRuntimeState(isPaused, isInPrepRoom)
	paused = isPaused and true or false
	inPrepRoom = isInPrepRoom and true or false
end

function M:OnAuraDataChanged()
	if paused or inPrepRoom then return end
	if not moduleUtil:IsEnabled() or not IsFeatureEnabled() then return end

	announceThisPassDefensive = false
	wipe(currentDefensiveAuras)

	local inInstance, instanceType = IsInInstance()
	ProcessWatchersForInstance(instanceType, inInstance)

	previousDefensiveAuras, currentDefensiveAuras = currentDefensiveAuras, previousDefensiveAuras
end

function M:ClearState()
	for _, watcher in ipairs(arenaWatchers) do
		watcher:ClearState(true)
	end
	for _, watcher in pairs(nameplateWatchers) do
		watcher:ClearState(true)
	end
	if targetWatcher then targetWatcher:ClearState(true) end
	if focusWatcher then focusWatcher:ClearState(true) end
	previousDefensiveAuras = {}
	wipe(importantLastSeen)
end

function M:EnableDisable()
	if not moduleUtil:IsEnabled() or not IsFeatureEnabled() then
		for _, watcher in ipairs(arenaWatchers) do watcher:Disable() end
		for _, watcher in pairs(nameplateWatchers) do watcher:Disable() end
		if targetWatcher then targetWatcher:Disable() end
		if focusWatcher then focusWatcher:Disable() end
		self:ClearState()
		return
	end

	local inInstance, instanceType = IsInInstance()
	local targetFocusOnly = GetTargetFocusOnly()

	if instanceType == "arena" then
		for _, watcher in ipairs(arenaWatchers) do watcher:Enable() end
	else
		for _, watcher in ipairs(arenaWatchers) do watcher:Disable() end
	end

	if instanceType == "pvp" or instanceType == "party" or instanceType == "raid" or not inInstance then
		if targetFocusOnly then
			if targetWatcher then targetWatcher:Enable() end
			if focusWatcher then focusWatcher:Enable() end
			ClearNamePlateWatchers()
		else
			if targetWatcher then targetWatcher:Disable() end
			if focusWatcher then focusWatcher:Disable() end
			RebuildNameplateWatchers()
		end
	else
		if instanceType ~= "arena" then
			ClearNamePlateWatchers()
			if targetWatcher then targetWatcher:Disable() end
			if focusWatcher then focusWatcher:Disable() end
		end
	end

	HookAllEnemyNameplates()
end

function M:Init(onScheduleUpdate)
	scheduleUpdate = onScheduleUpdate

	local enemyFilter = { Defensive = true }
	local arenaEvents = { "ARENA_OPPONENT_UPDATE" }
	arenaWatchers = {
		unitWatcher:New("arena1", arenaEvents, enemyFilter),
		unitWatcher:New("arena2", arenaEvents, enemyFilter),
		unitWatcher:New("arena3", arenaEvents, enemyFilter),
	}
	for _, watcher in ipairs(arenaWatchers) do
		watcher:RegisterCallback(scheduleUpdate)
	end

	targetWatcher = unitWatcher:New("target", { "PLAYER_TARGET_CHANGED" }, enemyFilter)
	targetWatcher:RegisterCallback(scheduleUpdate)

	focusWatcher = unitWatcher:New("focus", { "PLAYER_FOCUS_CHANGED" }, enemyFilter)
	focusWatcher:RegisterCallback(scheduleUpdate)

	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	eventsFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	eventsFrame:SetScript("OnEvent", function(_, event, unitToken)
		if not moduleUtil:IsEnabled() then return end
		local inInstance, instanceType = IsInInstance()
		if instanceType == "arena" or GetTargetFocusOnly() then return end
		if event == "NAME_PLATE_UNIT_ADDED" then
			OnNamePlateAdded(unitToken)
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			OnNamePlateRemoved(unitToken)
		end
	end)
end
