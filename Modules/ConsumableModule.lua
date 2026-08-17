---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local data = addon.Data.Consumables
local spellWatch = data.Spells
local itemWatch = data.Items

---@class ConsumableModule
local M = {}
addon.Modules.ConsumableModule = M

local eventsFrame
local hwFrame
local worldHooked
local primed
local pendingText
local lastAnnounceAt = 0
local lastAnnounceText
local lastSpellStart = {}
local lastItemStart = {}
local DEDUP = 0.8

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

local function FlushPendingSay()
	local text = pendingText
	if not text then return end
	if ChatLocked() then return end
	pendingText = nil
	StopHardwareWait()
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if send then
		send(text, "YELL")
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

local function QueueSay(name)
	if not name or name == "" then return end
	if not moduleUtil:IsConsumableSayEnabled() then return end
	local now = GetTime()
	local prefix = addon.L["consumable_say_prefix"] or "！！【PVP_SOUND检测】我已吃下"
	local text = prefix .. "【" .. name .. "】药水！！"
	if lastAnnounceText == text and (now - lastAnnounceAt) < DEDUP then
		return
	end
	lastAnnounceAt = now
	lastAnnounceText = text
	pendingText = text
	EnsureHardwareWait()
	hwFrame:Show()
	hwFrame:EnableKeyboard(true)
	hwFrame:SetPropagateKeyboardInput(true)
end

local function ReadSpellCooldown(spellID)
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if ok and type(info) == "table" then
			return tonumber(info.startTime) or 0, tonumber(info.duration) or 0
		end
	end
	if GetSpellCooldown then
		local start, duration = GetSpellCooldown(spellID)
		return tonumber(start) or 0, tonumber(duration) or 0
	end
	return 0, 0
end

local function ReadItemCooldown(itemID)
	if C_Container and C_Container.GetItemCooldown then
		local start, duration = C_Container.GetItemCooldown(itemID)
		return tonumber(start) or 0, tonumber(duration) or 0
	end
	if C_Item and C_Item.GetItemCooldown then
		local ok, info = pcall(C_Item.GetItemCooldown, itemID)
		if ok and type(info) == "table" then
			return tonumber(info.startTime) or 0, tonumber(info.duration) or 0
		end
	end
	if GetItemCooldown then
		local start, duration = GetItemCooldown(itemID)
		return tonumber(start) or 0, tonumber(duration) or 0
	end
	return 0, 0
end

-- Query our hardcoded IDs. Do not use secret values from combat events.
local function ScanCooldowns(announce)
	local hit
	for itemID, info in pairs(itemWatch) do
		local start, duration = ReadItemCooldown(itemID)
		if start > 0 and duration > 60 then
			if announce and lastItemStart[itemID] and lastItemStart[itemID] ~= start then
				hit = hit or info.zh
			end
			lastItemStart[itemID] = start
		end
	end
	for spellID, info in pairs(spellWatch) do
		local start, duration = ReadSpellCooldown(spellID)
		if start > 0 and duration > 60 then
			if announce and lastSpellStart[spellID] and lastSpellStart[spellID] ~= start then
				hit = hit or info.zh
			end
			lastSpellStart[spellID] = start
		end
	end
	if hit then
		QueueSay(hit)
	end
end

local function AnnounceSpell(spellID)
	if issecretvalue and issecretvalue(spellID) then return end
	spellID = tonumber(spellID)
	if not spellID then return end
	local info = spellWatch[spellID]
	if not info then return end
	QueueSay(info.zh)
end

function M:DebugTest(spellID)
	spellID = tonumber(spellID) or 1234768
	local info = spellWatch[spellID] or { zh = "生命药水" }
	QueueSay(info.zh)
	local prefix = addon.L["consumable_say_prefix"] or "！！【PVP_SOUND检测】我已吃下"
	pendingText = prefix .. "【" .. info.zh .. "】药水！！"
	FlushPendingSay()
	if pendingText then
		EnsureHardwareWait()
		hwFrame:Show()
		hwFrame:EnableKeyboard(true)
	end
end

function M:Init()
	if eventsFrame then return end
	EnsureHardwareWait()
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	eventsFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	eventsFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "PLAYER_ENTERING_WORLD" then
			ScanCooldowns(false)
			primed = true
			return
		end
		if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
			if primed then
				ScanCooldowns(true)
			end
			return
		end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
			AnnounceSpell(spellID)
			if primed then
				ScanCooldowns(true)
			end
		end
	end)
end

function M:Refresh()
end
