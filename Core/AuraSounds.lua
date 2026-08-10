---@type string, Addon
local _, addon = ...

-- Engine-side aura sounds via C_UnitAuras.AddAuraSound (12.1+).
-- Match MiniAuras: AddAuraSound(Enum.UnitAuraSoundTrigger.Added, info).
---@class AuraSounds
local M = {}
addon.Core.AuraSounds = M

local infoScratch = { unitToken = nil, spellID = nil, soundFileName = nil, outputChannel = nil }
local idListPool = {}
local signatureScratch = {}

---@param info table
---@return number?
local function AddOne(info)
	if not C_UnitAuras or not C_UnitAuras.AddAuraSound then
		return nil
	end
	local trigger = Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added
	if trigger == nil then
		return nil
	end
	return C_UnitAuras.AddAuraSound(trigger, info)
end

---@param handle number
local function RemoveOne(handle)
	if not handle or not C_UnitAuras then return end
	if C_UnitAuras.RemoveAuraSound then
		C_UnitAuras.RemoveAuraSound(handle)
	end
end

---Registers Added-trigger sounds: each spellID -> its own file under basePath.
---@param ids number[]?
---@param unitToken string
---@param filesBySpellId table<number, string> spellID -> file name
---@param basePath string
---@param channel string
---@return number[] ids
function M:RegisterMappedSet(ids, unitToken, filesBySpellId, basePath, channel)
	ids = ids or table.remove(idListPool) or {}

	local info = infoScratch
	info.unitToken = unitToken
	info.outputChannel = channel or "Master"

	for spellId, file in pairs(filesBySpellId) do
		info.spellID = spellId
		info.soundFileName = basePath .. file

		local handle = AddOne(info)
		if handle then
			ids[#ids + 1] = handle
		end
	end

	return ids
end

---Registers the same sound file for every spellID in a set.
---@param ids number[]?
---@param unitToken string
---@param spellIds table<number, boolean>
---@param soundFile string full path
---@param channel string
---@return number[] ids
function M:RegisterSet(ids, unitToken, spellIds, soundFile, channel)
	ids = ids or table.remove(idListPool) or {}

	local info = infoScratch
	info.unitToken = unitToken
	info.soundFileName = soundFile
	info.outputChannel = channel or "Master"

	for spellId in pairs(spellIds) do
		info.spellID = spellId
		local handle = AddOne(info)
		if handle then
			ids[#ids + 1] = handle
		end
	end

	return ids
end

---@param ids number[]?
function M:RemoveSet(ids)
	if not ids then return end
	for i = #ids, 1, -1 do
		RemoveOne(ids[i])
		ids[i] = nil
	end
	idListPool[#idListPool + 1] = ids
end

---@param ... any
---@return string
function M:Signature(...)
	local count = select("#", ...)
	for i = 1, count do
		signatureScratch[i] = tostring((select(i, ...)))
	end
	return table.concat(signatureScratch, "|", 1, count)
end

---@return boolean
function M:IsAvailable()
	return C_UnitAuras ~= nil
		and C_UnitAuras.AddAuraSound ~= nil
		and Enum ~= nil
		and Enum.UnitAuraSoundTrigger ~= nil
		and Enum.UnitAuraSoundTrigger.Added ~= nil
end
