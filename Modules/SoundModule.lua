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

-- Tracking tables for enemy important/defensive auras
local previousImportantAuras = {}
local previousDefensiveAuras = {}
local currentImportantAuras = {}
local currentDefensiveAuras = {}

-- Tracking tables for friendly CC auras
local previousFriendlyCCAuras = {}
local currentFriendlyCCAuras = {}

-- Cached TTS settings (global)
local cachedVoiceID
local cachedTTSVolume
local cachedTTSSpeechRate

-- Watchers
local arenaWatchers
local nameplateWatchers = {}
local targetWatcher
local focusWatcher

-- Friendly CC watchers
local friendlyWatchers = {}
local selfCCWatcher

-- Cast bar tracking
local castFrame

---@class SoundModule
local M = {}
addon.Modules.SoundModule = M

local function AnnounceTTS(spellName, spellType)
	if not spellName then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone then return end

	local enabled = false
	if spellType == "important" and zone.Important then
		enabled = true
	elseif spellType == "defensive" and zone.Defensive then
		enabled = true
	elseif spellType == "cc" and zone.CCMode and zone.CCMode ~= "Off" then
		enabled = true
	end

	if not enabled then return end

	pcall(function()
		local speechRate = cachedTTSSpeechRate or 0
		C_VoiceChat.SpeakText(cachedVoiceID, spellName, speechRate, cachedTTSVolume, true)
	end)
end

local function ProcessEnemyWatcherData(watcher)
	local unit = watcher:GetUnit()
	if not unit or not UnitExists(unit) then return end

	local importantData = watcher:GetImportantState()
	local defensivesData = watcher:GetDefensiveState()

	for _, data in ipairs(importantData) do
		if data.AuraInstanceID then
			if not currentImportantAuras[data.AuraInstanceID]
				and not previousImportantAuras[data.AuraInstanceID] then
				AnnounceTTS(data.SpellName, "important")
			end
			currentImportantAuras[data.AuraInstanceID] = true
		end
	end

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

local function GetCCMode()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return "Off" end
	return zone.CCMode or "Off"
end

local function GetTargetFocusOnly()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return true end
	return zone.TargetFocusOnly ~= false
end

local function AnnounceCast(spellName)
	if not spellName then return end
	pcall(function()
		local speechRate = cachedTTSSpeechRate or 0
		C_VoiceChat.SpeakText(cachedVoiceID, spellName, speechRate, cachedTTSVolume, true)
	end)
end

local function CheckTargetCast()
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.CastBar then return end

	if not UnitExists("target") or not units:IsEnemy("target") then return end

	local spellName = UnitCastingInfo("target")
	if not spellName then
		spellName = UnitChannelInfo("target")
	end
	if spellName then
		AnnounceCast(spellName)
	end
end

local function OnCastEvent(unit, spellID)
	if unit ~= "target" then return end
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.CastBar then return end

	if not UnitExists("target") or not units:IsEnemy("target") then return end

	-- Get spell name: try C_Spell first, fall back to UnitCastingInfo/UnitChannelInfo
	local spellName
	if spellID then
		spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
	end
	if not spellName then
		spellName = UnitCastingInfo("target")
	end
	if not spellName then
		spellName = UnitChannelInfo("target")
	end
	if not spellName then
		spellName = tostring(spellID or "cast")
	end

	AnnounceCast(spellName)
end

local function OnAuraDataChanged()
	if paused then return end
	if not moduleUtil:IsEnabled() then return end

	if inPrepRoom then return end

	wipe(currentImportantAuras)
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
		if ccMode == "Self" then
			if selfCCWatcher then
				ProcessFriendlyCCData(selfCCWatcher)
			end
		elseif ccMode == "All" then
			if selfCCWatcher then
				ProcessFriendlyCCData(selfCCWatcher)
			end
			for _, watcher in ipairs(friendlyWatchers) do
				ProcessFriendlyCCData(watcher)
			end
		end
	end

	-- Swap buffers
	previousImportantAuras, currentImportantAuras = currentImportantAuras, previousImportantAuras
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

	previousImportantAuras = {}
	previousDefensiveAuras = {}
	previousFriendlyCCAuras = {}
end

local function OnNamePlateAdded(unitToken)
	if nameplateWatchers[unitToken] then
		nameplateWatchers[unitToken]:Dispose()
		nameplateWatchers[unitToken] = nil
	end

	if not units:IsEnemy(unitToken) then return end

	local watcherFilter = { Defensive = true, Important = true }
	local watcher = unitWatcher:New(unitToken, nil, watcherFilter)
	watcher:RegisterCallback(ScheduleAuraDataUpdate)
	nameplateWatchers[unitToken] = watcher

	ScheduleAuraDataUpdate()
end

local function OnNamePlateRemoved(unitToken)
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
	if ccMode ~= "All" then return end

	local ccFilter = { CC = true }
	local friendlyUnits = units:FriendlyUnits()

	for _, unit in ipairs(friendlyUnits) do
		if unit ~= "player" and not string.find(unit, "pet", 1, true) then
			local watcher = unitWatcher:New(unit, nil, ccFilter)
			watcher:RegisterCallback(ScheduleAuraDataUpdate)
			friendlyWatchers[#friendlyWatchers + 1] = watcher
		end
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

	previousImportantAuras = {}
	previousDefensiveAuras = {}
	previousFriendlyCCAuras = {}
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
		if selfCCWatcher then selfCCWatcher:Enable() end
		if ccMode == "All" then
			RebuildFriendlyWatchers()
		else
			DisposeFriendlyWatchers()
		end
	else
		if selfCCWatcher then selfCCWatcher:Disable() end
		DisposeFriendlyWatchers()
	end

	ScheduleAuraDataUpdate()
end

local function CacheTTSSettings()
	local tts = db.TTS or {}
	cachedVoiceID = tts.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
	cachedTTSVolume = tts.Volume or 100
	cachedTTSSpeechRate = tts.SpeechRate or 0
end

function M:Refresh()
	CacheTTSSettings()
	EnableDisable()
end

function M:Init()
	local mini = addon.Core.Framework
	db = mini:GetSavedVars()

	CacheTTSSettings()

	-- Initialize arena watchers (enemy important/defensive)
	local enemyFilter = { Defensive = true, Important = true }
	local arenaEvents = { "ARENA_OPPONENT_UPDATE" }
	arenaWatchers = {
		unitWatcher:New("arena1", arenaEvents, enemyFilter),
		unitWatcher:New("arena2", arenaEvents, enemyFilter),
		unitWatcher:New("arena3", arenaEvents, enemyFilter),
	}
	for _, watcher in ipairs(arenaWatchers) do
		watcher:RegisterCallback(ScheduleAuraDataUpdate)
	end

	-- Initialize target/focus watchers (enemy important/defensive)
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
			if ccMode == "All" and moduleUtil:IsEnabled() then
				RebuildFriendlyWatchers()
			end
		end
	end)

	-- Cast bar frame: detect target casting via events
	castFrame = CreateFrame("Frame")
	castFrame:RegisterEvent("UNIT_SPELLCAST_START")
	castFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	castFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	castFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
		if event == "PLAYER_TARGET_CHANGED" then
			CheckTargetCast()
		else
			OnCastEvent(unit, spellID)
		end
	end)

	EnableDisable()
end
