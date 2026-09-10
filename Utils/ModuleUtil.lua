---@type string, Addon
local _, addon = ...

---@type Db
local db

---@class ModuleUtil
local M = {}
addon.Utils.ModuleUtil = M

function M:Init()
	db = addon.Core.Framework:GetSavedVars()
end

-- Returns the zone key for the current instance type
function M:GetZoneKey()
	local inInstance, instanceType = IsInInstance()

	if not inInstance then
		return "World"
	end

	if instanceType == "arena" then
		return "Arena"
	elseif instanceType == "pvp" then
		return "BattleGrounds"
	end

	return "PvE"
end

-- Returns the zone config table for the current zone
function M:GetZoneConfig()
	if not db or not db.Zones then return nil end
	return db.Zones[self:GetZoneKey()]
end

-- Returns whether enemy-buff alerts are enabled for the current zone.
function M:IsEnabled()
	local zone = self:GetZoneConfig()
	if not zone then return true end
	return zone.Enabled or false
end

-- Cast-start / channel / instant-cast voice: independent per-zone CastBar toggle.
function M:IsCastAlertsEnabled()
	local zone = self:GetZoneConfig()
	if not zone then return false end
	return zone.CastBar == true
end

-- Interrupt alert is an independent per-zone toggle (InterruptAlert); default off.
function M:IsInterruptAlertsEnabled()
	local zone = self:GetZoneConfig()
	if not zone then return false end
	return zone.InterruptAlert == true
end

-- Enemy kick-name voice: World / Arena / Battlegrounds only. Never PvE.
function M:IsEnemyKickAlertsEnabled()
	local key = self:GetZoneKey()
	if key ~= "World" and key ~= "Arena" and key ~= "BattleGrounds" then
		return false
	end
	local zone = self:GetZoneConfig()
	if not zone then return false end
	return zone.EnemyKickAlert == true
end

-- Consumable honesty yell: World only. Arena / BG / PvE never arm keyboard wait.
function M:IsConsumableSayEnabled()
	return self:GetZoneKey() == "World"
end

-- Watch nearby players (friend or foe) while spectating world duels.
-- Only while YOU are out of combat. Uses UNIT_SPELLCAST_*/UNIT_AURA, not CLEU.
function M:IsPlayerOutOfCombat()
	if InCombatLockdown() then
		return false
	end
	local inCombat = UnitAffectingCombat("player")
	if issecretvalue and issecretvalue(inCombat) then
		return false
	end
	return not inCombat
end

function M:IsDuelPotionWatchEnabled()
	if self:GetZoneKey() ~= "World" then
		return false
	end
	if not (db and db.DuelPotionWatch == true) then
		return false
	end
	return self:IsPlayerOutOfCombat()
end
