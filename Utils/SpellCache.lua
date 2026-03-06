---@type string, Addon
local _, addon = ...

---@class SpellCache
local M = {}
addon.Utils.SpellCache = M

local spellTextureCache = {}

function M:GetSpellTexture(spellId)
	if not spellId then return nil end
	if issecretvalue(spellId) then
		return C_Spell.GetSpellTexture(spellId)
	end
	local cached = spellTextureCache[spellId]
	if not cached then
		cached = C_Spell.GetSpellTexture(spellId)
		spellTextureCache[spellId] = cached
	end
	return cached
end

function M:ClearCache()
	spellTextureCache = {}
end
