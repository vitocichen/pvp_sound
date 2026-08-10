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

-- Cast-start / totems / interrupt must not follow buff-only `Enabled`.
-- Active when any zone alert is on (buff, debuff, or healer-CC).
function M:IsCastAlertsEnabled()
	local zone = self:GetZoneConfig()
	if not zone then return true end
	if zone.Enabled then return true end
	if zone.CcEnabled ~= false then return true end
	if zone.HealerCcEnabled ~= false then return true end
	return false
end
