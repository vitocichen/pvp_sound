---@type string, Addon
local addonName, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local voicePack = addon.Core.VoicePack

-- Cast/interrupt kept minimal; enemy-buff alerts are handled by AuraSoundModule.
local castSounds = addon.Data.CastSounds
local castSuccessSounds = addon.Data.CastSuccessSounds

-- Instant cast / totem drops that GLA announces on castSuccess (not auraApplied).
-- Grounding Totem's aura is 8178 (also registered via AddAuraSound); cast is 204336.
local INSTANT_CAST_ALERTS = {
	[204336] = true, -- Grounding Totem
	[8143] = true, -- Tremor Totem
	[98008] = true, -- Spirit Link Totem
	[108280] = true, -- Healing Tide Totem
	[192058] = true, -- Capacitor Totem
	[192222] = true, -- Liquid Magma Totem
	[198838] = true, -- Earthen Wall Totem
	[204331] = true, -- Counterstrike Totem
	[204330] = true, -- Skyfury Totem / Storm Totems family (GLA)
	[355580] = true, -- Static Field Totem
	[383013] = true, -- Poison Cleansing Totem
	[444995] = true, -- Surging Totem
}

local MEDIA_ROOT = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

---@type Db
local db

local inPrepRoom = false
local castFrame
local lastCastAnnounceTime = 0
local lastInterruptAnnounceTime = 0
local lastInstantAnnounceTime = 0
local cachedCastInterval = 0

---@class SoundModule
local M = {}
addon.Modules.SoundModule = M

local function Channel()
	return (db and db.Sound and db.Sound.Channel) or "Master"
end

local function PlayMapped(map, spellID)
	if not spellID or issecretvalue(spellID) then return false end
	local file = map[spellID]
	if not file then return false end
	local path = voicePack:Path(file)
	if not path then return false end
	pcall(PlaySoundFile, path, Channel())
	return true
end

local function IsEnemyCaster(unit)
	if not unit or not UnitExists(unit) then return false end
	-- Prefer CanAttack (duels); fall back to classic IsEnemy.
	if units.IsEnemyPlayer then
		return units:IsEnemyPlayer(unit)
	end
	return units:IsEnemy(unit) and not units:IsPetOrMinion(unit)
end

local function AnnounceInstantCast(spellID)
	if not INSTANT_CAST_ALERTS[spellID] then return end
	local now = GetTime()
	if now - lastInstantAnnounceTime < 0.15 then return end
	lastInstantAnnounceTime = now
	PlayMapped(castSuccessSounds, spellID)
end

local function AnnounceCast(spellID)
	local zone = moduleUtil:GetZoneConfig()
	-- Zone schema is simplified (Enabled only); keep cast-start optional if present.
	if zone and zone.CastBar == false then return end

	local now = GetTime()
	local minInterval = cachedCastInterval > 0 and cachedCastInterval or 0.05
	if now - lastCastAnnounceTime < minInterval then return end
	lastCastAnnounceTime = now
	PlayMapped(castSounds, spellID)
end

local function OnCastEvent(unit, spellID)
	if not moduleUtil:IsCastAlertsEnabled() or inPrepRoom then return end
	if not IsEnemyCaster(unit) then return end
	AnnounceCast(spellID)
end

local function OnCastSuccess(unit, spellID)
	if not moduleUtil:IsCastAlertsEnabled() or inPrepRoom then return end
	if not IsEnemyCaster(unit) then return end
	AnnounceInstantCast(spellID)
end

local function ResolveInterruptSoundPath()
	local file = (db and db.InterruptSoundFile) or "interrupted.ogg"
	if file == "interrupted.ogg" then
		return voicePack:Path("interrupted.ogg")
	end
	return MEDIA_ROOT .. file
end

local function OnCastInterrupted(unit)
	if not moduleUtil:IsInterruptAlertsEnabled() or inPrepRoom then return end
	if not IsEnemyCaster(unit) then return end

	local now = GetTime()
	if now - lastInterruptAnnounceTime < 1 then return end
	lastInterruptAnnounceTime = now

	local path = ResolveInterruptSoundPath()
	if path then
		pcall(PlaySoundFile, path, Channel())
	end
end

local function OnMatchStateChanged()
	local matchState = C_PvP.GetActiveMatchState()
	inPrepRoom = matchState == Enum.PvPMatchState.StartUp
end

function M:Refresh()
	OnMatchStateChanged()
	cachedCastInterval = (db and db.Sound and db.Sound.CastInterval) or 0
end

function M:Init()
	local mini = addon.Core.Framework
	db = mini:GetSavedVars()
	cachedCastInterval = (db.Sound and db.Sound.CastInterval) or 0

	castFrame = CreateFrame("Frame")
	castFrame:RegisterEvent("UNIT_SPELLCAST_START")
	castFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	castFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	castFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	castFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
	castFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "PVP_MATCH_STATE_CHANGED" then
			OnMatchStateChanged()
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			OnCastInterrupted(unit)
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			OnCastSuccess(unit, spellID)
		else
			OnCastEvent(unit, spellID)
		end
	end)
end
