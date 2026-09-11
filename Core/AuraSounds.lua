---@type string, Addon
local _, addon = ...

-- Engine-side aura sounds via C_UnitAuras.AddAuraSound (12.1+).
-- Match MiniAuras: AddAuraSound(Enum.UnitAuraSoundTrigger.Added, info).
---@class AuraSounds
local M = {}
addon.Core.AuraSounds = M

-- MiniCC: combat does not block registration in the open world / BGs / arena.
-- Instanced PvE combat turns AddAuraSound into ADDON_ACTION_BLOCKED.
local COMBAT_SAFE_PLACES = {
	none = true,
	pvp = true,
	arena = true,
}

local infoScratch = { unitToken = nil, spellID = nil, soundFileName = nil, outputChannel = nil }
local idListPool = {}
local signatureScratch = {}
local skipped = false

---Raw instance type from the client: "none", "pvp", "arena", "party", "raid", ...
---@return string
local function InstanceType()
	local _, instanceType = IsInInstance()
	return instanceType or "none"
end

---Whether AddAuraSound is safe right now (MiniCC CanRegister).
---@return boolean
function M:CanRegister()
	return COMBAT_SAFE_PLACES[InstanceType()] == true or not InCombatLockdown()
end

function M:NoteSkipped()
	skipped = true
end

---@return boolean
function M:ConsumeSkipped()
	local refused = skipped
	skipped = false
	return refused
end

---@param kind string|nil added | removed | stacks
---@return number?
function M:ResolveTrigger(kind)
	local e = Enum and Enum.UnitAuraSoundTrigger
	if not e then
		return nil
	end
	if kind == "removed" then
		return e.Removed
	end
	if kind == "stacks" then
		return e.ApplicationCountChanged or e.ApplicationsChanged or e.StackCountChanged
	end
	return e.Added
end

---@param info table
---@param trigger number|nil
---@return number?
local function AddOne(info, trigger)
	if not C_UnitAuras or not C_UnitAuras.AddAuraSound then
		return nil
	end
	if not M:CanRegister() then
		M:NoteSkipped()
		return nil
	end
	trigger = trigger or (Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added)
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
	if not self:CanRegister() then
		self:NoteSkipped()
		return ids
	end

	local info = infoScratch
	info.unitToken = unitToken
	info.outputChannel = channel or "Master"

	local voicePack = addon.Core.VoicePack
	for spellId, file in pairs(filesBySpellId) do
		info.spellID = spellId
		local full = voicePack and voicePack.Path and voicePack:Path(file)
		info.soundFileName = full or (basePath .. file)

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
	if not self:CanRegister() then
		self:NoteSkipped()
		return ids
	end

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

---One spell on one unit, with Added / Removed / stack-change trigger.
---@param ids number[]?
---@param unitToken string
---@param spellID number
---@param soundFile string full path
---@param channel string
---@param triggerKind string|nil
---@return number[] ids
function M:RegisterOne(ids, unitToken, spellID, soundFile, channel, triggerKind)
	ids = ids or table.remove(idListPool) or {}
	if not self:CanRegister() then
		self:NoteSkipped()
		return ids
	end
	local trigger = self:ResolveTrigger(triggerKind)
	if not trigger or not spellID or not soundFile or soundFile == "" then
		return ids
	end
	local info = infoScratch
	info.unitToken = unitToken
	info.spellID = spellID
	info.soundFileName = soundFile
	info.outputChannel = channel or "Master"
	local handle = AddOne(info, trigger)
	if handle then
		ids[#ids + 1] = handle
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
