---@type string, Addon
local _, addon = ...
local units = addon.Utils.Units
local moduleUtil = addon.Utils.ModuleUtil
local voicePack = addon.Core.VoicePack
local kickData = addon.Data.EnemyKicks

-- World / arena / battlegrounds (zone EnemyKickAlert): when our team’s cast is cut,
-- play the interrupter’s interrupt clip. PvE never. Same detection as MiniCC
-- EnemyKickTracker (interruptedBy on player/party1/party2).
-- Arena specs: GetArenaOpponentSpec. World/BG specs: inspect the kicker if found.
-- No generic interrupted.ogg; unknown/secret class → silence.
---@class EnemyKickModule
local M = {}
addon.Modules.EnemyKickModule = M

local WATCHED_UNITS = {
	"player",
	"party1",
	"party2",
}

local START_EVENTS = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_EMPOWER_START",
}

local STOP_EVENTS = {
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_EMPOWER_STOP",
}

local START_LOOKUP = {}
for i = 1, #START_EVENTS do
	START_LOOKUP[START_EVENTS[i]] = true
end

local eventFrames = {}
local kickedByUnits = {}
local opponentSpecIds = {}
local watching = false
local eventsFrame

local function Channel()
	local db = addon.Core.Framework:GetSavedVars()
	return (db and db.Sound and db.Sound.Channel) or "Master"
end

local function IsArena()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "arena"
end

local function IsOpenWorld()
	local inInstance = IsInInstance()
	return not inInstance
end

local function IsBattleground()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "pvp"
end

local function PublicText(value)
	if value == nil then
		return nil
	end
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	return tostring(value)
end

local function FindUnitForGuid(guid)
	if guid == nil then
		return nil
	end
	if issecretvalue and issecretvalue(guid) then
		return nil
	end
	local tokens = { "target", "focus", "mouseover", "pet", "arena1", "arena2", "arena3" }
	for i = 1, 40 do
		tokens[#tokens + 1] = "nameplate" .. i
	end
	for i = 1, #tokens do
		local unit = tokens[i]
		if UnitExists(unit) then
			local ok, other = pcall(UnitGUID, unit)
			if ok and PublicText(other) and other == guid then
				return unit
			end
		end
	end
	return nil
end

local lastInspectAt = 0

local function LocalizedSpecName(specId)
	local getter = GetSpecializationInfoByID
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID then
		getter = C_SpecializationInfo.GetSpecializationInfoByID
	end
	if not getter then
		return nil
	end
	local ok, _, specName = pcall(getter, specId)
	if ok then
		return PublicText(specName)
	end
	return nil
end

-- Mouseover tooltip is live (updates after talent swap). Inspect cache is not.
local function SpecIdFromTooltip(unit, class)
	if not unit or not class then
		return nil
	end
	if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
		return nil
	end
	local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
	if not ok or not data or not data.lines then
		return nil
	end
	local names = {}
	for specId, info in pairs(kickData.SpecData) do
		if info.Class == class then
			local specName = LocalizedSpecName(specId)
			if specName then
				names[#names + 1] = { specId = specId, name = specName }
			end
		end
	end
	table.sort(names, function(a, b)
		return #a.name > #b.name
	end)
	for i = 1, #data.lines do
		local text = data.lines[i] and PublicText(data.lines[i].leftText)
		if text then
			for n = 1, #names do
				if text:find(names[n].name, 1, true) then
					return names[n].specId
				end
			end
		end
	end
	return nil
end

local function InspectSpecId(unit)
	if not unit or not GetInspectSpecialization then
		return nil
	end
	local ok, specId = pcall(GetInspectSpecialization, unit)
	if not ok then
		return nil
	end
	specId = units:PublicNumber(specId)
	if specId and specId > 0 then
		return specId
	end
	return nil
end

local function RequestInspectRefresh(unit)
	if not unit or not NotifyInspect then
		return
	end
	local now = GetTime()
	if now - lastInspectAt < 1.5 then
		return
	end
	if CanInspect then
		local ok, can = pcall(CanInspect, unit)
		if ok and can == false then
			return
		end
	end
	lastInspectAt = now
	pcall(NotifyInspect, unit)
end

---World: tooltip first (current spec), inspect only if tooltip has no spec line.
---Inspect stays on the old talent loadout until NotifyInspect / rematch.
local function CollectKickerSpecIds(interruptedBy, class)
	local specs = {}
	local unit = FindUnitForGuid(interruptedBy)
	if not unit then
		return specs
	end
	local fromTooltip = SpecIdFromTooltip(unit, class)
	local fromInspect = InspectSpecId(unit)
	local specId = fromTooltip or fromInspect
	if specId then
		specs[#specs + 1] = specId
	end
	RequestInspectRefresh(unit)
	return specs
end

local function InPrepRoom()
	if not (C_PvP and C_PvP.GetActiveMatchState and Enum and Enum.PvPMatchState) then
		return false
	end
	return C_PvP.GetActiveMatchState() == Enum.PvPMatchState.StartUp
end

local function PublicClass(class)
	if class == nil then
		return nil
	end
	if issecretvalue and issecretvalue(class) then
		return nil
	end
	if type(class) ~= "string" or class == "" then
		return nil
	end
	return class
end

---@param event string
---@return any interruptedBy
local function GetInterrupter(event, ...)
	if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		local _, _, _, interruptedBy = ...
		return interruptedBy
	end
	if event == "UNIT_SPELLCAST_EMPOWER_STOP" then
		local _, _, _, _, interruptedBy = ...
		return interruptedBy
	end
	return nil
end

local function IsKickEnabled(spellId)
	spellId = kickData:CanonicalSpellId(spellId)
	if not spellId then
		return false
	end
	local db = addon.Core.Framework:GetSavedVars()
	if db and db.DisabledEnemyKickSpells and db.DisabledEnemyKickSpells[spellId] then
		return false
	end
	return true
end

local function PlayKick(file)
	if not file then
		return
	end
	local path = voicePack:Path(file)
	if not path then
		return
	end
	pcall(PlaySoundFile, path, Channel())
end

local function UpdateOpponents()
	wipe(opponentSpecIds)
	local n = 3
	if GetNumArenaOpponentSpecs then
		local ok, specs = pcall(GetNumArenaOpponentSpecs)
		if ok then
			local parsed = units:PublicNumber(specs)
			if parsed and parsed > 0 then
				n = parsed
			end
		end
	end
	if not GetArenaOpponentSpec then
		return
	end
	for i = 1, n do
		local ok, specId = pcall(GetArenaOpponentSpec, i)
		if ok then
			specId = units:PublicNumber(specId)
			if specId and specId > 0 then
				opponentSpecIds[#opponentSpecIds + 1] = specId
			end
		end
	end
end

-- Pets inherit the owner's class (DK ghoul → DEATHKNIGHT) but do not have Mind Freeze.
-- Warlock Spell Lock *is* the pet kick — still announce those.
local function IsNonPlayerKicker(interruptedBy)
	local text = PublicText(interruptedBy)
	if text then
		local guidType = text:match("^([%a]+)%-")
		if guidType and guidType ~= "Player" then
			return true
		end
	end
	local unit = FindUnitForGuid(interruptedBy)
	if not unit then
		return false
	end
	if units:IsPetOrMinion(unit) then
		return true
	end
	local ok, isPlayer = pcall(UnitIsPlayer, unit)
	if ok and isPlayer == false then
		return true
	end
	return false
end

local function OnKicked(class, interruptedBy)
	if InPrepRoom() then
		return
	end
	if not moduleUtil:IsEnemyKickAlertsEnabled() then
		return
	end
	class = PublicClass(class)
	if not class then
		return
	end
	-- DK (and other non-warlock) pets: skip. Warlock pet: Spell Lock, keep announcing.
	if IsNonPlayerKicker(interruptedBy) and class ~= "WARLOCK" then
		return
	end
	local specIds = opponentSpecIds
	if not IsArena() then
		specIds = CollectKickerSpecIds(interruptedBy, class)
	end
	local spellId, file = kickData:ResolveKick(class, specIds)
	if not spellId or not file then
		return
	end
	if not IsKickEnabled(spellId) then
		return
	end
	PlayKick(file)
end

---@param unit string
---@param event string
local function OnUnitEvent(unit, _, event, ...)
	if START_LOOKUP[event] then
		kickedByUnits[unit] = false
		return
	end
	if kickedByUnits[unit] then
		return
	end
	local kickedBy = GetInterrupter(event, ...)
	if not kickedBy then
		return
	end
	kickedByUnits[unit] = true
	-- GUID is secret in instances: only pass it into FromGUID / unit match helpers.
	OnKicked(select(2, UnitClassFromGUID(kickedBy)), kickedBy)
end

local function EnableWatch()
	if watching then
		return
	end
	for i = 1, #WATCHED_UNITS do
		local unit = WATCHED_UNITS[i]
		local frame = eventFrames[unit]
		if frame then
			for e = 1, #START_EVENTS do
				frame:RegisterUnitEvent(START_EVENTS[e], unit)
			end
			for e = 1, #STOP_EVENTS do
				frame:RegisterUnitEvent(STOP_EVENTS[e], unit)
			end
			frame:SetScript("OnEvent", function(...)
				OnUnitEvent(unit, ...)
			end)
		end
	end
	watching = true
end

local function DisableWatch()
	if not watching then
		return
	end
	for i = 1, #WATCHED_UNITS do
		local unit = WATCHED_UNITS[i]
		local frame = eventFrames[unit]
		if frame then
			for e = 1, #START_EVENTS do
				frame:UnregisterEvent(START_EVENTS[e])
			end
			for e = 1, #STOP_EVENTS do
				frame:UnregisterEvent(STOP_EVENTS[e])
			end
			frame:SetScript("OnEvent", nil)
		end
		kickedByUnits[unit] = nil
	end
	watching = false
end

function M:Refresh()
	if not moduleUtil:IsEnemyKickAlertsEnabled() then
		DisableWatch()
		wipe(opponentSpecIds)
		return
	end
	if IsArena() then
		UpdateOpponents()
		EnableWatch()
	elseif IsOpenWorld() or IsBattleground() then
		wipe(opponentSpecIds)
		EnableWatch()
	else
		DisableWatch()
		wipe(opponentSpecIds)
	end
end

function M:Init()
	local meta = addon.Core.PackMeta
	if not (meta and meta.Synced and meta:Synced()) then
		return
	end

	for i = 1, #WATCHED_UNITS do
		local unit = WATCHED_UNITS[i]
		eventFrames[unit] = eventFrames[unit] or CreateFrame("Frame")
	end

	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	eventsFrame:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
	if C_PvP then
		eventsFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
		eventsFrame:RegisterEvent("PVP_MATCH_ACTIVE")
		eventsFrame:RegisterEvent("PVP_MATCH_COMPLETE")
	end
	eventsFrame:SetScript("OnEvent", function()
		M:Refresh()
	end)
	self:Refresh()
end
