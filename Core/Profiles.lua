---@type string, Addon
local addonName, addon = ...

-- Multi-profile snapshots + import/export (forward-compatible payload).
---@class Profiles
local M = {}
addon.Core.Profiles = M

-- Bump when the *export envelope* changes (not when settings Version migrates).
M.FORMAT_VERSION = 1
M.EXPORT_PREFIX = "PVPS"

-- Active settings keys stored in a profile snapshot (not Profiles meta itself).
local SETTINGS_KEYS = {
	"Version",
	"VoicePack",
	"ExtraVoicePacks",
	"HealerCcSoundFile",
	"InterruptSoundFile",
	"Sound",
	"Zones",
	"DisabledEnemySpells",
	"DisabledSelfCcSpells",
	"Spells",
	"SelfCcSpells",
}

local function DeepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do
		out[DeepCopy(k, seen)] = DeepCopy(v, seen)
	end
	return out
end

-- Must be a method wrapper: `profiles:DeepCopy(x)` passes self; assigning the bare
-- DeepCopy function would deep-copy the Profiles module instead of `x`.
function M:DeepCopy(value)
	return DeepCopy(value)
end

---@param db table
---@return table
function M:CaptureSettings(db)
	local snap = {}
	if type(db) ~= "table" then
		return snap
	end
	for i = 1, #SETTINGS_KEYS do
		local key = SETTINGS_KEYS[i]
		if db[key] ~= nil then
			snap[key] = DeepCopy(db[key])
		end
	end
	return snap
end

---Copy snapshot fields onto live db (preserves Profiles / ActiveProfileName / WhatsNewVersion).
---@param db table
---@param snap table
function M:ApplySettings(db, snap)
	if type(db) ~= "table" or type(snap) ~= "table" then
		return
	end
	for i = 1, #SETTINGS_KEYS do
		local key = SETTINGS_KEYS[i]
		if snap[key] ~= nil then
			db[key] = DeepCopy(snap[key])
		end
	end
	-- Forward-compat: keep unknown keys from newer exports so later addon versions can read them.
	-- Never copy functions / module metadata (guards against bad snapshots).
	local skipMeta = {
		Profiles = true,
		ActiveProfileName = true,
		WhatsNewVersion = true,
		FORMAT_VERSION = true,
		EXPORT_PREFIX = true,
	}
	for key, value in pairs(snap) do
		local known = false
		for i = 1, #SETTINGS_KEYS do
			if SETTINGS_KEYS[i] == key then
				known = true
				break
			end
		end
		local vtype = type(value)
		if not known and not skipMeta[key] and (vtype == "table" or vtype == "string" or vtype == "number" or vtype == "boolean") then
			db[key] = DeepCopy(value)
		end
	end
end

---@param db table
---@return string[]
function M:ListNames(db)
	local list = {}
	local profiles = db and db.Profiles
	if type(profiles) ~= "table" then
		return list
	end
	for name in pairs(profiles) do
		if type(name) == "string" and name ~= "" then
			list[#list + 1] = name
		end
	end
	table.sort(list)
	return list
end

---@param db table
---@param name string
---@return boolean
function M:Save(db, name)
	if type(db) ~= "table" or type(name) ~= "string" then
		return false
	end
	name = name:match("^%s*(.-)%s*$") or ""
	if name == "" then
		return false
	end
	db.Profiles = db.Profiles or {}
	db.Profiles[name] = self:CaptureSettings(db)
	db.ActiveProfileName = name
	return true
end

---@param db table
---@param name string
---@return table?
function M:Get(db, name)
	if type(db) ~= "table" or type(name) ~= "string" then
		return nil
	end
	local profiles = db.Profiles
	if type(profiles) ~= "table" then
		return nil
	end
	local snap = profiles[name]
	if type(snap) ~= "table" then
		return nil
	end
	return DeepCopy(snap)
end

---@param db table
---@param name string
---@return boolean
function M:Delete(db, name)
	if type(db) ~= "table" or type(name) ~= "string" then
		return false
	end
	if type(db.Profiles) ~= "table" or db.Profiles[name] == nil then
		return false
	end
	db.Profiles[name] = nil
	if db.ActiveProfileName == name then
		db.ActiveProfileName = nil
	end
	return true
end

-- ---------- encode / decode (JSON+Base64 when available, else custom) ----------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function EncodeBase64(data)
	if C_EncodingUtil and C_EncodingUtil.EncodeBase64 then
		return C_EncodingUtil.EncodeBase64(data)
	end
	return (
		(data:gsub(".", function(x)
			local r, b = "", x:byte()
			for i = 8, 1, -1 do
				r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
			if #x < 6 then
				return ""
			end
			local c = 0
			for i = 1, 6 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
			end
			return B64:sub(c + 1, c + 1)
		end) .. ({ "", "==", "=" })[#data % 3 + 1]
	)
end

local function DecodeBase64(data)
	if C_EncodingUtil and C_EncodingUtil.DecodeBase64 then
		return C_EncodingUtil.DecodeBase64(data)
	end
	data = data:gsub("[^" .. B64 .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local r, f = "", (B64:find(x, 1, true) or 1) - 1
			for i = 6, 1, -1 do
				r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

---Minimal table serializer (no loadstring). Numbers/strings/bools/tables only.
local function SerializeValue(value, buf)
	local t = type(value)
	if t == "nil" then
		buf[#buf + 1] = "n"
	elseif t == "boolean" then
		buf[#buf + 1] = value and "B" or "b"
	elseif t == "number" then
		buf[#buf + 1] = "N"
		buf[#buf + 1] = tostring(value)
		buf[#buf + 1] = ";"
	elseif t == "string" then
		buf[#buf + 1] = "S"
		buf[#buf + 1] = tostring(#value)
		buf[#buf + 1] = ";"
		buf[#buf + 1] = value
	elseif t == "table" then
		buf[#buf + 1] = "T"
		for k, v in pairs(value) do
			SerializeValue(k, buf)
			SerializeValue(v, buf)
		end
		buf[#buf + 1] = "t"
	else
		buf[#buf + 1] = "n"
	end
end

local function DeserializeValue(str, i)
	local tag = str:sub(i, i)
	i = i + 1
	if tag == "n" then
		return nil, i
	elseif tag == "B" then
		return true, i
	elseif tag == "b" then
		return false, i
	elseif tag == "N" then
		local semi = str:find(";", i, true)
		local num = tonumber(str:sub(i, semi - 1))
		return num, semi + 1
	elseif tag == "S" then
		local semi = str:find(";", i, true)
		local len = tonumber(str:sub(i, semi - 1)) or 0
		local start = semi + 1
		local finish = start + len - 1
		return str:sub(start, finish), finish + 1
	elseif tag == "T" then
		local tbl = {}
		while str:sub(i, i) ~= "t" do
			local k
			k, i = DeserializeValue(str, i)
			local v
			v, i = DeserializeValue(str, i)
			tbl[k] = v
		end
		return tbl, i + 1
	end
	error("bad serialize tag")
end

local function EncodePayload(payload)
	if C_EncodingUtil and C_EncodingUtil.SerializeJSON then
		local ok, json = pcall(C_EncodingUtil.SerializeJSON, payload)
		if ok and type(json) == "string" then
			return "J" .. json
		end
	end
	local buf = { "C" }
	SerializeValue(payload, buf)
	return table.concat(buf)
end

local function DecodePayload(raw)
	local kind = raw:sub(1, 1)
	local body = raw:sub(2)
	if kind == "J" then
		if not (C_EncodingUtil and C_EncodingUtil.DeserializeJSON) then
			return nil, "json_unsupported"
		end
		local ok, payload = pcall(C_EncodingUtil.DeserializeJSON, body)
		if not ok or type(payload) ~= "table" then
			return nil, "json_bad"
		end
		return payload
	elseif kind == "C" then
		local ok, payload = pcall(function()
			local v, nextI = DeserializeValue(body, 1)
			return v
		end)
		if not ok or type(payload) ~= "table" then
			return nil, "custom_bad"
		end
		return payload
	end
	return nil, "unknown_codec"
end

---@param settings table
---@param name string?
---@return string
function M:Export(settings, name)
	local payload = {
		format = "PVP_Sound_Profile",
		formatVersion = M.FORMAT_VERSION,
		addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "",
		dbVersion = type(settings) == "table" and tonumber(settings.Version) or nil,
		name = name or "",
		exportedAt = time(),
		settings = DeepCopy(settings),
	}
	local encoded = EncodePayload(payload)
	return string.format("%s%d:%s", M.EXPORT_PREFIX, M.FORMAT_VERSION, EncodeBase64(encoded))
end

---@param text string
---@return table? payload
---@return string? err
function M:Import(text)
	if type(text) ~= "string" then
		return nil, "empty"
	end
	text = text:match("^%s*(.-)%s*$") or ""
	text = text:gsub("%s+", "")
	if text == "" then
		return nil, "empty"
	end

	local ver, b64 = text:match("^" .. M.EXPORT_PREFIX .. "(%d+):(.+)$")
	if not ver then
		return nil, "bad_prefix"
	end
	ver = tonumber(ver) or 0
	-- Accept current and older envelope versions; reject only if somehow 0.
	if ver < 1 then
		return nil, "bad_format_version"
	end
	-- Newer envelope: still try decode (forward-compatible if codec+fields understood).
	local raw = DecodeBase64(b64)
	if type(raw) ~= "string" or raw == "" then
		return nil, "b64_bad"
	end
	local payload, err = DecodePayload(raw)
	if not payload then
		return nil, err or "decode_bad"
	end
	if payload.format ~= "PVP_Sound_Profile" then
		return nil, "bad_format"
	end
	if type(payload.settings) ~= "table" then
		return nil, "no_settings"
	end
	return payload
end

return M
