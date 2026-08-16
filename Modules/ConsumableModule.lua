---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local consumables = addon.Data.Consumables

---@class ConsumableModule
local M = {}
addon.Modules.ConsumableModule = M

local eventsFrame
local lastAnnounceAt = {}
local DEDUP = 0.4

local function ConsumableName(spellID)
	local info = consumables[spellID]
	if not info then return nil end
	-- Spec names are Chinese (nearby players need to read the honesty line).
	return info.zh or info.en
end

local function SendSay(text)
	if C_ChatInfo and C_ChatInfo.SendChatMessage then
		pcall(C_ChatInfo.SendChatMessage, text, "SAY")
	elseif SendChatMessage then
		pcall(SendChatMessage, text, "SAY")
	end
end

local function Announce(spellID)
	spellID = tonumber(spellID)
	if not spellID or not consumables[spellID] then return end
	if not moduleUtil:IsConsumableSayEnabled() then return end

	local now = GetTime()
	if lastAnnounceAt[spellID] and (now - lastAnnounceAt[spellID]) < DEDUP then
		return
	end
	lastAnnounceAt[spellID] = now

	local name = ConsumableName(spellID)
	if not name then return end
	local prefix = addon.L["consumable_say_prefix"] or "【pvp_sound检测】我已吃下 "
	SendSay(prefix .. name)
end

function M:DebugTest(spellID)
	spellID = tonumber(spellID) or 1234768
	Announce(spellID)
	print("|cffffd100[PVP Sound]|r consumable test id=" .. tostring(spellID)
		.. " name=" .. tostring(ConsumableName(spellID)))
end

function M:Init()
	if eventsFrame then return end
	eventsFrame = CreateFrame("Frame")
	-- Same event BBF / interrupt uses to know "I just used this spell".
	eventsFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	-- Instant item use sometimes only shows up in combat log.
	eventsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventsFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if unit == "player" then
				Announce(spellID)
			end
			return
		end
		if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end
		local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, logSpellID = CombatLogGetCurrentEventInfo()
		if subevent ~= "SPELL_CAST_SUCCESS" then return end
		if sourceGUID ~= UnitGUID("player") then return end
		Announce(logSpellID)
	end)
end

function M:Refresh()
end
