---@type string, Addon
local _, addon = ...
local eventsFrame

---@class SchedulerUtil
local M = {}
addon.Utils.Scheduler = M

local combatEndCallbacks = {}
local combatEndKeyedCallbacks = {}

local function OnCombatEnded()
	for _, callback in ipairs(combatEndCallbacks) do
		callback()
	end
	for _, callback in pairs(combatEndKeyedCallbacks) do
		callback()
	end
	wipe(combatEndCallbacks)
	wipe(combatEndKeyedCallbacks)
end

local function OnEvent(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		OnCombatEnded()
	end
end

function M:RunWhenCombatEnds(callback, key)
	if not callback then return end
	if not InCombatLockdown() then
		callback()
		return
	end
	if key then
		combatEndKeyedCallbacks[key] = callback
	else
		combatEndCallbacks[#combatEndCallbacks + 1] = callback
	end
end

function M:Init()
	eventsFrame = CreateFrame("Frame")
	eventsFrame:SetScript("OnEvent", OnEvent)
	eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
end
