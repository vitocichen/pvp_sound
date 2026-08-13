---@type string, Addon
local addonName, addon = ...

-- Voice packs live under Interface\AddOns\PVP_Sound\Media\<PackName>\ as .ogg/.mp3.
---@class VoicePack
local M = {}
addon.Core.VoicePack = M

local CACHED_BASE
local CACHED_PACK
local db

local DEFAULT_PACK = "夏一可1.25x"

local function MediaRoot()
	return "Interface\\AddOns\\" .. addonName .. "\\Media\\"
end

local function PackFolderPath(packName)
	return MediaRoot() .. packName .. "\\"
end

---@param path string
---@return boolean
local function PathExists(path)
	if GetFileIDFromPath then
		local id = GetFileIDFromPath(path)
		if id and id ~= 0 then
			return true
		end
	end
	return false
end

---Resolve clip path: try given name, then swap .ogg/.mp3.
---@param basePath string
---@param fileName string
---@return string
local function ResolveClip(basePath, fileName)
	local stem = fileName:gsub("%.ogg$", ""):gsub("%.mp3$", ""):gsub("%.OGG$", ""):gsub("%.MP3$", "")
	local candidates = {
		basePath .. fileName,
		basePath .. stem .. ".ogg",
		basePath .. stem .. ".mp3",
	}
	for i = 1, #candidates do
		local p = candidates[i]
		if PathExists(p) then
			return p
		end
	end
	-- Prefer .ogg for AddAuraSound even if we cannot probe (engine resolves at play time).
	return basePath .. stem .. ".ogg"
end

function M:Init()
	db = addon.Core.Framework:GetSavedVars()
end

---@return string
function M:GetSelectedPack()
	local pack = db and db.VoicePack
	if type(pack) == "string" and pack ~= "" then
		return pack
	end
	return DEFAULT_PACK
end

---@param packName string
function M:SetSelectedPack(packName)
	if not db then return end
	if type(packName) ~= "string" or packName == "" then return end
	db.VoicePack = packName
	self:Invalidate()
end

---Packs shown in the dropdown: manifest + user extras (deduped, default pack first).
---@return string[]
function M:ListPacks()
	local seen = {}
	local list = {}

	local function add(name)
		if not name or name == "" or seen[name] then return end
		seen[name] = true
		list[#list + 1] = name
	end

	-- Prefer default pack first.
	add(DEFAULT_PACK)

	local manifest = addon.Data.VoicePackManifest
	if manifest then
		for i = 1, #manifest do
			add(manifest[i])
		end
	end

	if db and db.ExtraVoicePacks then
		for i = 1, #db.ExtraVoicePacks do
			add(db.ExtraVoicePacks[i])
		end
	end

	return list
end

---Register a custom Media\<name> pack for the dropdown.
---@param packName string
---@return boolean
function M:RegisterExtraPack(packName)
	if not db or not packName or packName == "" then return false end
	packName = packName:match("^%s*(.-)%s*$")
	if packName == "" then return false end
	-- Disallow path tricks.
	if packName:find("[\\/]") or packName:find("%.%.") then return false end

	db.ExtraVoicePacks = db.ExtraVoicePacks or {}
	for i = 1, #db.ExtraVoicePacks do
		if db.ExtraVoicePacks[i] == packName then
			return true
		end
	end
	db.ExtraVoicePacks[#db.ExtraVoicePacks + 1] = packName
	return true
end

---@return string
function M:GetBasePath()
	local pack = self:GetSelectedPack()
	if CACHED_BASE ~= nil and CACHED_PACK == pack then
		return CACHED_BASE
	end
	CACHED_PACK = pack
	CACHED_BASE = PackFolderPath(pack)
	return CACHED_BASE
end

---@param fileName string e.g. "IceboundFortitude.ogg"
---@return string?
function M:Path(fileName)
	if not fileName or fileName == "" then return nil end
	return ResolveClip(self:GetBasePath(), fileName)
end

---Legacy path used before multi-pack layout (Media\Voice_zhCN).
---@return string
function M:LegacyPath()
	return MediaRoot() .. "Voice_zhCN\\"
end

function M:Invalidate()
	CACHED_BASE = nil
	CACHED_PACK = nil
end

---@return string
function M:DefaultPack()
	return DEFAULT_PACK
end
