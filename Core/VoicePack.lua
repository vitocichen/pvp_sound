---@type string, Addon
local addonName, addon = ...

-- Shipped packs: Interface\AddOns\PVP_Sound\Media\<PackName>\
-- DIY packs:     Interface\AddOns\PVP_Sound_Custom\<PackName>\  (sibling addon; survives updates)
-- Legacy DIY:    Media\<PackName>\ is still probed as fallback.
---@class VoicePack
local M = {}
addon.Core.VoicePack = M

local CACHED_BASE
local CACHED_PACK
local db

local DEFAULT_PACK = "夏一可1.25x"
local CUSTOM_ADDON = "PVP_Sound_Custom"

local function MediaRoot()
	return "Interface\\AddOns\\" .. addonName .. "\\Media\\"
end

local function CustomRoot()
	return "Interface\\AddOns\\" .. CUSTOM_ADDON .. "\\"
end

local function PackFolderPath(packName)
	return MediaRoot() .. packName .. "\\"
end

local function CustomFolderPath(packName)
	return CustomRoot() .. packName .. "\\"
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

---@param packName string
---@return boolean
local function IsShippedPack(packName)
	if packName == DEFAULT_PACK then
		return true
	end
	local manifest = addon.Data.VoicePackManifest
	if not manifest then
		return false
	end
	for i = 1, #manifest do
		if manifest[i] == packName then
			return true
		end
	end
	return false
end

---Resolve clip path: try given name, then swap .ogg/.mp3. Returns nil if none exist.
---@param basePath string
---@param fileName string
---@return string?
local function TryResolveClip(basePath, fileName)
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
	return nil
end

---Resolve clip path: try given name, then swap .ogg/.mp3.
---@param basePath string
---@param fileName string
---@return string
local function ResolveClip(basePath, fileName)
	local found = TryResolveClip(basePath, fileName)
	if found then
		return found
	end
	local stem = fileName:gsub("%.ogg$", ""):gsub("%.mp3$", ""):gsub("%.OGG$", ""):gsub("%.MP3$", "")
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

---Register a custom pack name (files live under PVP_Sound_Custom\<name>\).
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
	if IsShippedPack(pack) then
		CACHED_BASE = PackFolderPath(pack)
	else
		CACHED_BASE = CustomFolderPath(pack)
	end
	return CACHED_BASE
end

---@param fileName string e.g. "IceboundFortitude.ogg"
---@return string?
function M:Path(fileName)
	if not fileName or fileName == "" then return nil end
	local pack = self:GetSelectedPack()
	if IsShippedPack(pack) then
		return ResolveClip(PackFolderPath(pack), fileName)
	end
	local custom = TryResolveClip(CustomFolderPath(pack), fileName)
	if custom then
		return custom
	end
	-- Legacy DIY that was still placed under Media\<name>\.
	local legacy = TryResolveClip(PackFolderPath(pack), fileName)
	if legacy then
		return legacy
	end
	return CustomFolderPath(pack) .. fileName:gsub("%.mp3$", ".ogg"):gsub("%.MP3$", ".ogg")
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

---Localized dropdown label; folder names stay Chinese on disk.
---@param packName string?
---@return string
function M:DisplayName(packName)
	if type(packName) ~= "string" or packName == "" then
		return packName or ""
	end
	local L = addon.L
	if L and L.IsChinese and L:IsChinese() then
		return packName
	end
	local mapped = packName
	mapped = mapped:gsub("英语女声", (L and L["pack_english_female"]) or "English Female")
	mapped = mapped:gsub("夏一可", (L and L["pack_xia_yike"]) or "Xia Yike")
	mapped = mapped:gsub("晓晓", (L and L["pack_xiaoxiao"]) or "Xiaoxiao")
	mapped = mapped:gsub("(%a)(%d)", "%1 %2", 1)
	return mapped
end

---@return string
function M:DefaultPack()
	return DEFAULT_PACK
end

---@return string
function M:CustomAddonFolder()
	return CUSTOM_ADDON
end
