---@type string, Addon
local addonName, addon = ...

---@class WaSounds
local M = {}
addon.Utils.WaSounds = M

M.DEFAULT_FILE = "PS_Ping.ogg"

M.BUILTIN = {
	"夏一可_控制成功.ogg",
	"PS_Alert.ogg",
	"PS_Chime.ogg",
	"PS_Error.ogg",
	"PS_Horn.ogg",
	"PS_Impact.ogg",
	"PS_Ping.ogg",
	"PS_Pop.ogg",
	"PS_Radar.ogg",
	"PS_Shock.ogg",
	"PS_Swoosh.ogg",
	"PS_Warm.ogg",
}

M.PACKAGED = {
	"alterTimeDown.ogg",
	"AntiMagicShellDown.ogg",
	"Evasiondown.ogg",
}
for i = 1, #M.BUILTIN do
	builtinSet[M.BUILTIN[i]] = true
end

local CUSTOM_ADDON = "PVP_Sound_Custom"
local CUSTOM_FOLDER = "WASounds"

local function MediaRoot()
	return "Interface\\AddOns\\" .. addonName .. "\\Media\\"
end

local function CustomDirs()
	return {
		"Interface\\AddOns\\" .. CUSTOM_ADDON .. "\\" .. CUSTOM_FOLDER .. "\\",
		"Interface\\AddOns\\" .. addonName .. "\\" .. CUSTOM_ADDON .. "\\" .. CUSTOM_FOLDER .. "\\",
	}
end

function M:CustomDirDisplay()
	return "Interface\\AddOns\\" .. CUSTOM_ADDON .. "\\" .. CUSTOM_FOLDER .. "\\"
end

local function PathExists(path)
	if not path or path == "" or not GetFileIDFromPath then
		return false
	end
	local id = GetFileIDFromPath(path)
	return id and id ~= 0
end

local function IsAudioName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if name:find("[\\/]") or name:find("%.%.") then
		return false
	end
	return name:lower():match("%.ogg$") or name:lower():match("%.mp3$")
end

function M:IsBuiltin(fileName)
	return fileName and builtinSet[fileName] and true or false
end

---@param fileName string
---@return string?
function M:Resolve(fileName)
	if type(fileName) ~= "string" or fileName == "" then
		return nil
	end
	if self:IsBuiltin(fileName) then
		local media = MediaRoot() .. fileName
		if PathExists(media) or not GetFileIDFromPath then
			return media
		end
	end
	local dirs = CustomDirs()
	for i = 1, #dirs do
		local custom = dirs[i] .. fileName
		if PathExists(custom) then
			return custom
		end
	end
	if PathExists(MediaRoot() .. fileName) then
		return MediaRoot() .. fileName
	end
	local voicePack = addon.Core.VoicePack
	if voicePack and voicePack.TryPath then
		return voicePack:TryPath(fileName)
	end
	return nil
end

local function AddUnique(list, seen, name)
	if not IsAudioName(name) or seen[name] then
		return
	end
	seen[name] = true
	list[#list + 1] = name
end

local function EnumerateCustomDir()
	local found = {}
	local seen = {}
	local dirs = CustomDirs()
	for d = 1, #dirs do
		local dir = dirs[d]
		local probes = {
			function()
				if C_FileSystem and C_FileSystem.GetFiles then
					return C_FileSystem.GetFiles(dir)
				end
			end,
			function()
				if C_FileSystem and C_FileSystem.GetDirectoryContents then
					return C_FileSystem.GetDirectoryContents(dir)
				end
			end,
			function()
				if C_FileSystem and C_FileSystem.GetDirectoryItems then
					return C_FileSystem.GetDirectoryItems(dir)
				end
			end,
		}
		for i = 1, #probes do
			local ok, result = pcall(probes[i])
			if ok and type(result) == "table" then
				for _, name in ipairs(result) do
					local base = tostring(name):match("([^\\/]+)$") or tostring(name)
					if IsAudioName(base) and not seen[base] and PathExists(dir .. base) then
						seen[base] = true
						found[#found + 1] = base
					end
				end
			end
		end
	end
	return found
end

local function CollectKnownNames()
	local names = {}
	local function eat(map)
		if type(map) ~= "table" then
			return
		end
		for _, file in pairs(map) do
			if type(file) == "string" then
				names[#names + 1] = file
			end
		end
	end
	local data = addon.Data
	if data then
		eat(data.EnemyBuffSounds)
		eat(data.SelfCcSounds)
		eat(data.CcSounds)
		eat(data.CastSounds)
		eat(data.CastSuccessSounds)
		local list = data.Consumables and data.Consumables.List
		if list then
			for i = 1, #list do
				if list[i] and list[i].file then
					names[#names + 1] = list[i].file
				end
			end
		end
	end
	return names
end

---@return string[]
function M:List()
	local out = {}
	local seen = {}
	for i = 1, #M.BUILTIN do
		AddUnique(out, seen, M.BUILTIN[i])
	end
	local extra = {}
	local extraSeen = {}
	local function addExtra(name)
		if not IsAudioName(name) or seen[name] or extraSeen[name] then
			return
		end
		extraSeen[name] = true
		extra[#extra + 1] = name
	end
	local enumerated = EnumerateCustomDir()
	for i = 1, #enumerated do
		addExtra(enumerated[i])
	end
	for i = 1, #M.PACKAGED do
		addExtra(M.PACKAGED[i])
	end
	local dirs = CustomDirs()
	local known = CollectKnownNames()
	for i = 1, #known do
		local name = known[i]
		if IsAudioName(name) then
			for d = 1, #dirs do
				if PathExists(dirs[d] .. name) then
					addExtra(name)
					break
				end
			end
		end
	end
	local db = addon.Core.Framework and addon.Core.Framework.GetSavedVars and addon.Core.Framework:GetSavedVars()
	if not db then
		db = _G.PVPSoundDB
	end
	local rules = db and db.CustomAuras
	if type(rules) == "table" then
		for i = 1, #rules do
			local file = rules[i] and rules[i].file
			if type(file) == "string" and file ~= "" and self:Resolve(file) then
				addExtra(file)
			end
		end
	end
	table.sort(extra)
	for i = 1, #extra do
		AddUnique(out, seen, extra[i])
	end
	return out
end

---@param current string|nil
---@return string[]
function M:ListForDropdown(current)
	local list = self:List()
	if type(current) == "string" and current ~= "" then
		local found = false
		for i = 1, #list do
			if list[i] == current then
				found = true
				break
			end
		end
		if not found then
			list[#list + 1] = current
		end
	end
	return list
end
