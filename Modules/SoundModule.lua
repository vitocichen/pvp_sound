---@type string, Addon
local _, addon = ...
local unitWatcher = addon.Core.UnitAuraWatcher
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local privateAuraSound = addon.Modules.PrivateAuraSound
local enemyBuffPlayback = addon.Modules.EnemyBuffPlayback
local eventsFrame
local paused = false
local inPrepRoom = false
local pendingAuraUpdate = false

---@type Db
local db

-- Tracking tables for friendly CC auras
local previousFriendlyCCAuras = {}
local currentFriendlyCCAuras = {}

-- Cached TTS settings (global)
local cachedVoiceID
local cachedTTSVolume
local cachedTTSSpeechRate
local cachedCastInterval

-- Per-frame announce dedup for CC only.
local announceThisPassCC = false

-- Friendly CC watchers
local friendlyWatchers = {}
local selfCCWatcher

-- Healer CC watchers (for Arena healer-CC TTS)
local healerCCWatchers = {}
local healerCCActive = false

-- Cast bar tracking
local castFrame
local lastCastAnnounceTime = 0
local lastInterruptAnnounceTime = 0

---@class SoundModule
local M = {}
addon.Modules.SoundModule = M

local function AnnounceTTS(spellName, spellType)
	if not spellName then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone then return end

	if spellType ~= "cc" then return end
	if zone.CCEnabled == false or not zone.CCMode or zone.CCMode == "Off" then
		return
	end

	if announceThisPassCC then return end
	announceThisPassCC = true

	pcall(function()
		local speechRate = cachedTTSSpeechRate or 7
		C_VoiceChat.SpeakText(cachedVoiceID, spellName, speechRate, cachedTTSVolume, true)
	end)
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

local function GetCastBarMode()
	local zone = moduleUtil:GetZoneConfig()
	if not zone then return "TargetOnly" end
	local val = zone.CastBarTargetOnly
	if val == "TargetingMe" then return "TargetingMe" end
	if val ~= false then return "TargetOnly" end
	return "All"
end

local function IsCastTargetingPlayer(unit)
	if unit == "target" then
		if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
			return true
		end
	elseif unit == "focus" then
		if UnitExists("focustarget") and UnitIsUnit("focustarget", "player") then
			return true
		end
	else
		local casterTarget = unit .. "target"
		if UnitExists(casterTarget) and UnitIsUnit(casterTarget, "player") then
			return true
		end
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

	if zone.CastBarExcludePets ~= false and units:IsPetOrMinion("target") then return end

	if mode == "TargetingMe" and not IsCastTargetingPlayer("target") then return end

	local spellName = UnitCastingInfo("target")
	if not spellName then
		spellName = UnitChannelInfo("target")
	end
	if not spellName then return end

	AnnounceCast(spellName)
end

local function OnCastEvent(unit, spellID)
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.CastBar then return end

	local mode = GetCastBarMode()
	if mode == "TargetOnly" then return end

	if not unit or not UnitExists(unit) or not units:IsEnemy(unit) then return end

	if zone.CastBarExcludePets ~= false and units:IsPetOrMinion(unit) then return end

	if mode == "TargetingMe" and not IsCastTargetingPlayer(unit) then return end

	local spellName
	if spellID and C_Spell and C_Spell.GetSpellName then
		spellName = C_Spell.GetSpellName(spellID)
	end
	if not spellName then
		spellName = UnitCastingInfo(unit)
	end
	if not spellName then
		spellName = UnitChannelInfo(unit)
	end
	if not spellName then return end

	AnnounceCast(spellName)
end

local function OnCastInterrupted(unit)
	if not moduleUtil:IsEnabled() then return end
	if paused or inPrepRoom then return end

	local zone = moduleUtil:GetZoneConfig()
	if not zone or not zone.InterruptAlert then return end

	local mode = zone.InterruptMode or "Target"

	if mode == "Target" then
		if unit ~= "target" then return end
		if not UnitExists("target") or not units:IsEnemy("target") then return end
	elseif mode == "TargetFocus" then
		if unit ~= "target" and unit ~= "focus" then return end
		if not UnitExists(unit) or not units:IsEnemy(unit) then return end
	else
		if not unit or not UnitExists(unit) then return end
		if not units:IsEnemy(unit) then return end
	end

	if zone.InterruptExcludePets ~= false and units:IsPetOrMinion(unit) then
		return
	end

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

	announceThisPassCC = false
	wipe(currentFriendlyCCAuras)

	local inInstance, instanceType = IsInInstance()

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

	if (instanceType == "arena" or instanceType == "pvp") and not units:IsHealer("player") then
		local zone2 = moduleUtil:GetZoneConfig()
		if zone2 and zone2.HealerCC then
			local anyHealerCCed = false
			for _, watcher in ipairs(healerCCWatchers) do
				if not UnitIsUnit(watcher:GetUnit(), "player") and ProcessHealerCCData(watcher) then
					anyHealerCCed = true
				end
			end

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

	previousFriendlyCCAuras, currentFriendlyCCAuras = currentFriendlyCCAuras, previousFriendlyCCAuras

	enemyBuffPlayback:SetRuntimeState(paused, inPrepRoom)
	enemyBuffPlayback:OnAuraDataChanged()
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

	if selfCCWatcher then selfCCWatcher:ClearState(true) end
	for _, watcher in ipairs(friendlyWatchers) do
		watcher:ClearState(true)
	end
	for _, watcher in ipairs(healerCCWatchers) do
		watcher:ClearState(true)
	end

	previousFriendlyCCAuras = {}
	healerCCActive = false

	if inPrepRoom then
		enemyBuffPlayback:ClearState()
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

	local inInstance, instanceType = IsInInstance()
	if instanceType ~= "arena" and instanceType ~= "pvp" then return end

	local healers = units:FindHealers()
	local ccFilter = { CC = true }

	for _, healerUnit in ipairs(healers) do
		local watcher = unitWatcher:New(healerUnit, nil, ccFilter)
		watcher:RegisterCallback(ScheduleAuraDataUpdate)
		healerCCWatchers[#healerCCWatchers + 1] = watcher
	end
end

local function DisableWatchers()
	if selfCCWatcher then selfCCWatcher:Disable() end
	DisposeFriendlyWatchers()
	DisposeHealerCCWatchers()
	previousFriendlyCCAuras = {}
	healerCCActive = false
	privateAuraSound:ClearRegistrations()
	enemyBuffPlayback:ClearState()
end

local function EnableDisable()
	local moduleEnabled = moduleUtil:IsEnabled()

	if not moduleEnabled then
		DisableWatchers()
		return
	end

	local inInstance, instanceType = IsInInstance()
	local ccMode = GetCCMode()

	if instanceType == "arena" or instanceType == "pvp" then
		RebuildHealerCCWatchers()
	else
		DisposeHealerCCWatchers()
	end

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
	enemyBuffPlayback:EnableDisable()
end

local function CacheTTSSettings()
	local tts = db.TTS or {}
	cachedVoiceID = tts.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
	cachedTTSVolume = tts.Volume or 100
	cachedTTSSpeechRate = tts.SpeechRate or 7
	cachedCastInterval = tts.CastInterval or 0
end

function M:Refresh()
	OnMatchStateChanged()
	CacheTTSSettings()
	EnableDisable()
end

function M:Init()
	local mini = addon.Core.Framework
	db = mini:GetSavedVars()

	CacheTTSSettings()
	enemyBuffPlayback:Init(ScheduleAuraDataUpdate)

	local ccFilter = { CC = true }
	selfCCWatcher = unitWatcher:New("player", nil, ccFilter)
	selfCCWatcher:RegisterCallback(ScheduleAuraDataUpdate)

	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
	eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	eventsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventsFrame:SetScript("OnEvent", function(_, event)
		if event == "PVP_MATCH_STATE_CHANGED" then
			OnMatchStateChanged()
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			EnableDisable()
		elseif event == "GROUP_ROSTER_UPDATE" then
			local ccMode = GetCCMode()
			if (ccMode == "All" or ccMode == "Party") and moduleUtil:IsEnabled() then
				RebuildFriendlyWatchers()
			end
			local inInst, instType = IsInInstance()
			if (instType == "arena" or instType == "pvp") and moduleUtil:IsEnabled() then
				RebuildHealerCCWatchers()
			end
		end
	end)

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

	EnableDisable()
end
