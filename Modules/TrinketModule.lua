---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local voicePack = addon.Core.VoicePack

-- Arena PvP trinket (medallion) voice. Detection matches sArena Reloaded on 12.x:
-- CompactArenaFrameMemberN.CcRemoverFrame cooldown start, not combat-log spell IDs.
-- Healer vs DPS: same spec-ID table as sArena. Healers play HealerTrinket.ogg;
-- others play trinket<CLASS>.ogg (e.g. trinketWARRIOR.ogg). Missing clip → Trinket.ogg.
---@class TrinketModule
local M = {}
addon.Modules.TrinketModule = M

local TRINKET_FILE = "Trinket.ogg"
local HEALER_TRINKET_FILE = "HealerTrinket.ogg"
local TRINKET_SPELL_ID = 336126
local MAX_ARENA = 3
local DEDUP = 0.4

-- Copied from sArena Reloaded healerSpecIDs.
local HEALER_SPEC_IDS = {
	[65] = true, -- Holy Paladin
	[105] = true, -- Restoration Druid
	[256] = true, -- Discipline Priest
	[257] = true, -- Holy Priest
	[264] = true, -- Restoration Shaman
	[270] = true, -- Mistweaver Monk
	[1468] = true, -- Preservation Evoker
}

local hooked = {}
local cdActive = {}
local lastPlay = 0
local eventsFrame

local function Channel()
	local db = addon.Core.Framework:GetSavedVars()
	return (db and db.Sound and db.Sound.Channel) or "Master"
end

local function InArena()
	local _, instanceType = IsInInstance()
	return instanceType == "arena"
end

local function InPrepRoom()
	if not (C_PvP and C_PvP.GetActiveMatchState and Enum and Enum.PvPMatchState) then
		return false
	end
	return C_PvP.GetActiveMatchState() == Enum.PvPMatchState.StartUp
end

local function TrinketChecked()
	local aura = addon.Modules.AuraSoundModule
	if aura and aura.IsSpellEnabled then
		return aura:IsSpellEnabled(TRINKET_SPELL_ID)
	end
	return true
end

local function ShouldPlay()
	if not InArena() then return false end
	if InPrepRoom() then return false end
	if not moduleUtil:IsEnabled() then return false end
	return TrinketChecked()
end

---@param index number
---@return number?
local function ArenaSpecID(index)
	if not GetArenaOpponentSpec then return nil end
	local ok, specID = pcall(GetArenaOpponentSpec, index)
	if not ok then return nil end
	specID = units:PublicNumber(specID)
	if not specID or specID <= 0 then return nil end
	return specID
end

---@param specID number
---@return string?
local function ArenaClassFile(specID)
	if not GetSpecializationInfoByID then return nil end
	local ok, _, _, _, _, _, classFile = pcall(GetSpecializationInfoByID, specID)
	if not ok or type(classFile) ~= "string" or classFile == "" then return nil end
	if issecretvalue and issecretvalue(classFile) then return nil end
	return classFile
end

local function PlayPath(path)
	if not path then return false end
	local ok = pcall(PlaySoundFile, path, Channel())
	return ok and true or false
end

---Prefer TryPath so a missing class/healer clip falls through to generic 徽章.
local function PlayNamed(fileName)
	if voicePack.TryPath then
		return PlayPath(voicePack:TryPath(fileName))
	end
	return PlayPath(voicePack:Path(fileName))
end

---@param index number
local function PlayTrinket(index)
	local now = GetTime()
	if now - lastPlay < DEDUP then return end

	local played = false
	local specID = ArenaSpecID(index)
	if specID then
		if HEALER_SPEC_IDS[specID] then
			played = PlayNamed(HEALER_TRINKET_FILE)
		else
			local classFile = ArenaClassFile(specID)
			if classFile then
				played = PlayNamed("trinket" .. classFile .. ".ogg")
			end
		end
	end
	if not played then
		played = PlayNamed(TRINKET_FILE)
	end
	if played then
		lastPlay = now
	end
end

local function OnCooldownSet(index, cooldown)
	if not cooldown then return end
	local shown = cooldown:IsShown()
	if not shown then
		cdActive[index] = false
		return
	end
	if cdActive[index] then return end
	cdActive[index] = true
	if ShouldPlay() then
		PlayTrinket(index)
	end
end

local function HookCooldown(cooldown, index)
	if not cooldown or hooked[cooldown] then return end
	hooked[cooldown] = index
	hooksecurefunc(cooldown, "SetCooldown", function(self)
		OnCooldownSet(index, self)
	end)
	if cooldown.SetCooldownFromDurationObject then
		hooksecurefunc(cooldown, "SetCooldownFromDurationObject", function(self)
			OnCooldownSet(index, self)
		end)
	end
	if cooldown.Clear then
		hooksecurefunc(cooldown, "Clear", function()
			cdActive[index] = false
		end)
	end
end

function M:InstallHooks()
	for i = 1, MAX_ARENA do
		local member = _G["CompactArenaFrameMember" .. i]
		local remover = member and member.CcRemoverFrame
		local cooldown = remover and remover.Cooldown
		HookCooldown(cooldown, i)
	end
end

function M:Reset()
	wipe(cdActive)
	lastPlay = 0
end

function M:Refresh()
	self:InstallHooks()
end

function M:Init()
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	if C_PvP then
		eventsFrame:RegisterEvent("PVP_MATCH_ACTIVE")
		eventsFrame:RegisterEvent("PVP_MATCH_COMPLETE")
	end
	eventsFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" or event == "PVP_MATCH_COMPLETE" then
			M:Reset()
		end
		M:InstallHooks()
	end)
	self:InstallHooks()
end
