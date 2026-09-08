---@type string, Addon
local _, addon = ...

-- Name/id suggestions for the WA spell picker. MiniAuras-style: type an id or
-- part of the localized name. Index is our catalog ids plus a few extra auras.
---@class SpellSearch
local M = {}
addon.Utils.SpellSearch = M

local MAX_RESULTS = 8
-- WA 页自带的三条示例（其余搜索词来自本插件目录）。操控时间光环只有 342246。
local EXTRA_IDS = {
	342246, -- 操控时间
	48707, -- 反魔法护罩
	5277, -- 闪避
}

---@type { Id: number, Name: string, Lower: string }[]?
local entries
local results = {}

local function AddId(seen, list, spellId)
	spellId = tonumber(spellId)
	if not spellId or spellId <= 0 or seen[spellId] then
		return
	end
	seen[spellId] = true
	list[#list + 1] = spellId
end

local function CollectIds()
	local seen, list = {}, {}
	local function eatMap(map)
		if type(map) ~= "table" then
			return
		end
		for id in pairs(map) do
			AddId(seen, list, id)
		end
	end
	local data = addon.Data
	if data then
		eatMap(data.EnemyBuffSounds)
		eatMap(data.SelfCcSounds)
		eatMap(data.CastSuccessSounds)
		eatMap(data.CastSounds)
		eatMap(data.CcSounds)
	end
	for i = 1, #EXTRA_IDS do
		AddId(seen, list, EXTRA_IDS[i])
	end
	return list
end

local function EnsureIndex()
	if entries then
		return
	end
	entries = {}
	if not (C_Spell and C_Spell.GetSpellName) then
		return
	end
	local ids = CollectIds()
	for i = 1, #ids do
		local id = ids[i]
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and type(name) == "string" and name ~= "" then
			if not (issecretvalue and issecretvalue(name)) then
				entries[#entries + 1] = {
					Id = id,
					Name = name,
					Lower = name:lower(),
				}
			end
		end
	end
	table.sort(entries, function(a, b)
		return a.Lower < b.Lower
	end)
end

---@param spellId number
---@return { Id: number, Name: string, Lower: string }?
function M:Entry(spellId)
	spellId = tonumber(spellId)
	if not spellId or spellId <= 0 or not (C_Spell and C_Spell.GetSpellName) then
		return nil
	end
	EnsureIndex()
	for i = 1, #entries do
		if entries[i].Id == spellId then
			return entries[i]
		end
	end
	local ok, name = pcall(C_Spell.GetSpellName, spellId)
	if ok and type(name) == "string" and name ~= "" then
		if not (issecretvalue and issecretvalue(name)) then
			return { Id = spellId, Name = name, Lower = name:lower() }
		end
	end
	return nil
end

---Shared result table; copy if you keep it past the next Search.
---@param query string
---@param limit number?
---@return { Id: number, Name: string, Lower: string }[]
function M:Search(query, limit)
	wipe(results)
	query = (query or ""):match("^%s*(.-)%s*$") or ""
	if query == "" then
		return results
	end
	EnsureIndex()
	limit = limit or MAX_RESULTS
	local numeric = tonumber(query)
	if numeric and numeric == math.floor(numeric) and numeric > 0 then
		local entry = self:Entry(numeric)
		if entry then
			results[#results + 1] = entry
		end
	end
	local lower = query:lower()
	local prefixes, contains = {}, {}
	for i = 1, #entries do
		local entry = entries[i]
		if entry.Id ~= numeric then
			local at = entry.Lower:find(lower, 1, true)
			if at == 1 then
				prefixes[#prefixes + 1] = entry
			elseif at then
				contains[#contains + 1] = entry
			elseif numeric and tostring(entry.Id):find(query, 1, true) == 1 then
				contains[#contains + 1] = entry
			end
		end
	end
	for _, list in ipairs({ prefixes, contains }) do
		for i = 1, #list do
			if #results >= limit then
				return results
			end
			results[#results + 1] = list[i]
		end
	end
	return results
end
