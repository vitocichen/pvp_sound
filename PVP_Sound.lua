---@type string, Addon
local _, addon = ...
local mini = addon.Core.Framework
local scheduler = addon.Utils.Scheduler
local config = addon.Config
local soundModule = addon.Modules.SoundModule
local eventsFrame

local function OnEvent(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		addon:Refresh()
	end
end

local function OnAddonLoaded()
	config:Init()
	scheduler:Init()
	addon.Utils.ModuleUtil:Init()

	soundModule:Init()

	eventsFrame = CreateFrame("Frame")
	eventsFrame:SetScript("OnEvent", OnEvent)
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function addon:Refresh()
	soundModule:Refresh()
end

mini:WaitForAddonLoad(OnAddonLoaded)
