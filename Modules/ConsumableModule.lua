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
	return info.zh or info.en
end

-- Do not call SendChatMessage inside UNIT_SPELLCAST_SUCCEEDED: that is a
-- secure context and pops ADDON_ACTION_FORBIDDEN. Defer to the next frame.
local function SendSay(text)
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return end
	send(text, "SAY")
end

local function Announce(spellID)
	if issecretvalue and issecretvalue(spellID) then return end
	spellID = tonumber(spellID)
	if not spellID then return end
	local name = ConsumableName(spellID)
	if not name then return end
	if not moduleUtil:IsConsumableSayEnabled() then return end

	local now = GetTime()
	if lastAnnounceAt[spellID] and (now - lastAnnounceAt[spellID]) < DEDUP then
		return
	end
	lastAnnounceAt[spellID] = now

	local text = (addon.L["consumable_say_prefix"] or "【pvp_sound检测】我已吃下 ") .. name
	C_Timer.After(0, function()
		SendSay(text)
	end)
end

function M:DebugTest(spellID)
	if issecretvalue and issecretvalue(spellID) then return end
	Announce(tonumber(spellID) or 1234768)
end

function M:Init()
	if eventsFrame then return end
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	eventsFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
		if unit ~= "player" then return end
		if not spellID then return end
		Announce(spellID)
	end)
end

function M:Refresh()
end
