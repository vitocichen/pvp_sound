---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local consumables = addon.Data.Consumables

---@class ConsumableModule
local M = {}
addon.Modules.ConsumableModule = M

local eventsFrame
local popup
local lastAnnounceAt = {}
local DEDUP = 0.4
local pendingText

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) and true or false
end

local function ConsumableName(spellID)
	local info = consumables[spellID]
	if not info then return nil end
	return info.zh or info.en
end

local function BuildMessage(spellID)
	local name = ConsumableName(spellID)
	if not name then return nil end
	local prefix = addon.L["consumable_say_prefix"] or "【pvp_sound检测】我已吃下 "
	return prefix .. name
end

-- Midnight: addon SendChatMessage is protected. Auto-send from combat events
-- triggers ADDON_ACTION_FORBIDDEN. Only call after a hardware event (click/slash),
-- and never while C_ChatInfo.InChatMessagingLockdown() is true.
local function ChatLocked()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local locked = C_ChatInfo.InChatMessagingLockdown()
		if locked then return true end
	end
	return false
end

local function SendSay(text)
	if not text or text == "" then return false end
	if ChatLocked() then return false end
	if C_ChatInfo and C_ChatInfo.SendChatMessage then
		C_ChatInfo.SendChatMessage(text, "SAY")
		return true
	end
	if SendChatMessage then
		SendChatMessage(text, "SAY")
		return true
	end
	return false
end

local function HidePopup()
	if popup then
		popup:Hide()
	end
	pendingText = nil
end

local function EnsurePopup()
	if popup then return popup end

	popup = CreateFrame("Button", "PVPSoundConsumableSayButton", UIParent, "UIPanelButtonTemplate")
	popup:SetSize(520, 52)
	popup:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetFrameLevel(200)
	popup:RegisterForClicks("LeftButtonUp")
	popup:SetScript("OnClick", function(self)
		local text = pendingText
		HidePopup()
		if not text then return end
		-- This OnClick is a hardware event, so SAY is allowed when not locked.
		if SendSay(text) then return end
		-- PvP/raid lockdown: put the line in the chat box; player presses Enter.
		if ChatFrame_OpenChat then
			ChatFrame_OpenChat(text)
		else
			print("|cffffd100[PVP Sound]|r " .. text)
		end
	end)
	popup:Hide()
	return popup
end

local function ShowClickToSend(text)
	pendingText = text
	local btn = EnsurePopup()
	btn:SetText((addon.L["consumable_click_send"] or "点击发送：") .. text)
	btn:Show()
	C_Timer.After(8, function()
		if pendingText == text then
			HidePopup()
		end
	end)
end

local function Announce(spellID, fromHardware)
	if IsSecret(spellID) then return end
	spellID = tonumber(spellID)
	if not spellID or not consumables[spellID] then return end
	if not moduleUtil:IsConsumableSayEnabled() then return end

	local now = GetTime()
	if lastAnnounceAt[spellID] and (now - lastAnnounceAt[spellID]) < DEDUP then
		return
	end
	lastAnnounceAt[spellID] = now

	local text = BuildMessage(spellID)
	if not text then return end
	print("|cffffd100[PVP Sound]|r " .. text)

	-- Slash/button = hardware event. Potion-use event is not — never auto /say.
	if fromHardware and SendSay(text) then
		return
	end
	ShowClickToSend(text)
end

function M:DebugTest(spellID)
	spellID = tonumber(spellID) or 1234768
	Announce(spellID, true)
end

function M:Init()
	if eventsFrame then return end
	eventsFrame = CreateFrame("Frame")
	-- Same event as interrupt: only the player's own successful spell/item use.
	-- Do not use COMBAT_LOG — Midnight combat log is secret and will taint /say.
	eventsFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	eventsFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
			Announce(spellID, false)
		end
	end)
end

function M:Refresh()
end
