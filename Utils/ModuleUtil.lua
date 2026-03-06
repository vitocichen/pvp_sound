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

function M:IsEnabled()
	if not db or not db.Enabled then
		return true
	end

	local settings = db.Enabled

	local inInstance, instanceType = IsInInstance()

	if not inInstance then
		return settings.World or false
	end

	if instanceType == "arena" then
		return settings.Arena
	elseif instanceType == "pvp" then
		return settings.BattleGrounds
	end

	return settings.PvE
end
