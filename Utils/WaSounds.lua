---@type string, Addon
local addonName, addon = ...

---@class WaSounds
local M = {}
addon.Utils.WaSounds = M

M.DEFAULT_FILE = "PS_Ping.ogg"

-- Fixed examples in Media\. Dropdown shows only these.
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
	"AntiMagicShellDown.ogg",
	"Evasiondown.ogg",
	"alterTimeDown.ogg",
	"mortalStrike.ogg",
	"mortalStrikeDown.ogg",
}

local builtinSet = {}
for i = 1, #M.BUILTIN do
	builtinSet[M.BUILTIN[i]] = true
end

local CUSTOM_ADDON = "PVP_Sound_Custom"
local CUSTOM_FOLDER = "WASounds"

local function MediaRoot()
	return "Interface\\AddOns\\" .. addonName .. "\\Media\\"
end

function M:CustomDirDisplay()
	return "Interface\\AddOns\\" .. CUSTOM_ADDON .. "\\" .. CUSTOM_FOLDER .. "\\"
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
	if not IsAudioName(fileName) then
		return nil
	end
	if self:IsBuiltin(fileName) then
		return MediaRoot() .. fileName
	end
	return self:CustomDirDisplay() .. fileName
end

---@return string[]
function M:List()
	return M.BUILTIN
end
