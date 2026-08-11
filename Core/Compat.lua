---@type string, Addon
local _, addon = ...

-- Runtime engine selection: prefer AddAuraSound capability over TOC/version numbers.
---@class Compat
local M = {}
addon.Core.Compat = M

---@return boolean
function M:UseAddAuraSound()
	local aura = addon.Core.AuraSounds
	if aura and aura.IsAvailable then
		return aura:IsAvailable()
	end
	return C_UnitAuras ~= nil
		and C_UnitAuras.AddAuraSound ~= nil
		and Enum ~= nil
		and Enum.UnitAuraSoundTrigger ~= nil
		and Enum.UnitAuraSoundTrigger.Added ~= nil
end

---@return boolean
function M:UseLegacyEngine()
	return not self:UseAddAuraSound()
end
