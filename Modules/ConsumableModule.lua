---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local consumables = addon.Data.Consumables

---@class ConsumableModule
local M = {}
addon.Modules.ConsumableModule = M

local eventsFrame
local hwFrame
local worldHooked
local pendingText
local lastAnnounceAt = {}
local DEDUP = 0.4

local function ConsumableName(spellID)
	local info = consumables[spellID]
	if not info then return nil end
	return info.zh or info.en
end

local function ChatLocked()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		return C_ChatInfo.InChatMessagingLockdown() and true or false
	end
	return false
end

local function StopHardwareWait()
	if not hwFrame then return end
	hwFrame:EnableKeyboard(false)
	hwFrame:Hide()
end

-- SAY is a protected function: calling it from UNIT_SPELLCAST_SUCCEEDED or
-- C_Timer.After(0) yields "插件导致界面行为失效". Must run on a real key/click.
local function FlushPendingSay()
	local text = pendingText
	if not text then return end
	if ChatLocked() then return end
	pendingText = nil
	StopHardwareWait()
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if send then
		send(text, "SAY")
	end
end

local function EnsureHardwareWait()
	if not hwFrame then
		hwFrame = CreateFrame("Frame", nil, UIParent)
		hwFrame:SetPoint("CENTER")
		hwFrame:SetSize(1, 1)
		hwFrame:SetScript("OnKeyDown", function(self)
			self:SetPropagateKeyboardInput(true)
			FlushPendingSay()
		end)
	end
	if not worldHooked and WorldFrame then
		worldHooked = true
		WorldFrame:HookScript("OnMouseDown", function()
			FlushPendingSay()
		end)
	end
end

local function QueueSay(text)
	pendingText = text
	EnsureHardwareWait()
	hwFrame:Show()
	hwFrame:EnableKeyboard(true)
	hwFrame:SetPropagateKeyboardInput(true)
end

local function Announce(spellID, sendNow)
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
	if sendNow then
		pendingText = text
		FlushPendingSay()
		if pendingText then
			QueueSay(text)
		end
		return
	end
	QueueSay(text)
end

function M:DebugTest(spellID)
	Announce(tonumber(spellID) or 1234768, true)
end

function M:Init()
	if eventsFrame then return end
	EnsureHardwareWait()
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	eventsFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
		if unit ~= "player" then return end
		if not spellID then return end
		Announce(spellID, false)
	end)
end

function M:Refresh()
end
