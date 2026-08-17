---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local voicePack = addon.Core.VoicePack

-- Arena PvP trinket (medallion) voice. Detection matches sArena Reloaded on 12.x:
-- CompactArenaFrameMemberN.CcRemoverFrame cooldown start, not combat-log spell IDs.
---@class TrinketModule
local M = {}
addon.Modules.TrinketModule = M

local TRINKET_FILE = "Trinket.ogg"
local TRINKET_SPELL_ID = 336126
local MAX_ARENA = 3
local DEDUP = 0.4

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

local function PlayTrinket()
	local now = GetTime()
	if now - lastPlay < DEDUP then return end
	lastPlay = now
	local path = voicePack:Path(TRINKET_FILE)
	if not path then return end
	pcall(PlaySoundFile, path, Channel())
end

local function OnCooldownSet(index, cooldown)
	if not cooldown then return end
	addon.DbgCall("Trinket:SetCooldown:" .. tostring(index), function()
		if addon.Dbg then
			addon.Dbg("trinket CD index=%s shown=%s", tostring(index), addon.DbgVal(cooldown:IsShown()))
		end
		local shown = cooldown:IsShown()
		if not shown then
			cdActive[index] = false
			return
		end
		if cdActive[index] then return end
		cdActive[index] = true
		if ShouldPlay() then
			PlayTrinket()
		end
	end)
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
