---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local data = addon.Data.Consumables
local spellWatch = data.Spells

---@class ConsumableModule
local M = {}
addon.Modules.ConsumableModule = M

local eventsFrame
local hwFrame
local primed
local pendingText
local lastAnnounceAt = 0
local lastAnnounceText
local seenAura = {}
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
	-- Do not HookScript WorldFrame: that taints click-to-target and shows
	-- 插件导致界面行为失效 after /reload. Potion yell waits for the next keypress.
	if hwFrame then return end
	hwFrame = CreateFrame("Frame", nil, UIParent)
	hwFrame:SetPoint("CENTER")
	hwFrame:SetSize(1, 1)
	hwFrame:EnableKeyboard(false)
	hwFrame:Hide()
	hwFrame:SetScript("OnKeyDown", function(self)
		self:SetPropagateKeyboardInput(true)
		FlushPendingSay()
	end)
end

local function ConsumableName(info)
	if not info then return "" end
	if addon.L:IsChinese() then
		return info.zh or info.en or ""
	end
	return info.en or info.zh or ""
end

local function QueueSay(name)
	if not name or name == "" then return end
	if not moduleUtil:IsConsumableSayEnabled() then return end
	local now = GetTime()
	local fmt = addon.L["consumable_say_format"]
	local text = string.format(fmt, name)
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

---Hardcoded spellID only. Do not read cooldown start/duration (secret in combat).
local function PlayerHasAura(spellID)
	if not spellID then
		return false
	end
	if issecretvalue and issecretvalue(spellID) then
		return false
	end
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
		return false
	end
	local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
	if not ok or aura == nil then
		return false
	end
	if issecretvalue and issecretvalue(aura) then
		return false
	end
	return true
end

local function ScanPlayerAuras(announce)
	for spellID, info in pairs(spellWatch) do
		local has = PlayerHasAura(spellID)
		if announce and has and not seenAura[spellID] then
			QueueSay(ConsumableName(info))
		end
		seenAura[spellID] = has
	end
end

local function AnnounceSpell(spellID)
	spellID = addon.Utils.Units:PublicNumber(spellID)
	if not spellID then return end
	local info = spellWatch[spellID]
	if not info then return end
	QueueSay(ConsumableName(info))
end

function M:DebugTest(spellID)
	spellID = tonumber(spellID) or 1234768
	local info = spellWatch[spellID] or { zh = "生命药水", en = "Health Potion" }
	QueueSay(ConsumableName(info))
	FlushPendingSay()
	if pendingText then
		EnsureHardwareWait()
		hwFrame:Show()
		hwFrame:EnableKeyboard(true)
	end
end

function M:Init()
	if eventsFrame then return end
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterUnitEvent("UNIT_AURA", "player")
	eventsFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "PLAYER_ENTERING_WORLD" then
			ScanPlayerAuras(false)
			primed = true
			return
		end
		if event == "UNIT_AURA" then
			if primed then
				ScanPlayerAuras(true)
			end
			return
		end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
			AnnounceSpell(spellID)
		end
	end)
end

function M:Refresh()
end
