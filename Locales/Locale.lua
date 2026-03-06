---@type string, Addon
local _, addon = ...

---@class Localization
local L = {}
addon.L = L

local locale = GetLocale()
local strings = {}
local defaultStrings = {}

function L:SetString(key, value)
	strings[key] = value
end

function L:SetStrings(stringTable)
	for key, value in pairs(stringTable) do
		strings[key] = value
	end
end

function L:SetDefaultStrings(stringTable)
	for key, value in pairs(stringTable) do
		defaultStrings[key] = value
	end
end

function L:Get(key)
	return strings[key] or defaultStrings[key] or key
end

setmetatable(L, {
	__index = function(t, key)
		if type(key) == "string" then
			return strings[key] or defaultStrings[key] or key
		end
		return rawget(t, key)
	end,
})

function L:GetLocale()
	return locale
end
