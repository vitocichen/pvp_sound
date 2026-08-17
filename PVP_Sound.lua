---@type string, Addon
local _, addon = ...
local mini = addon.Core.Framework
local scheduler = addon.Utils.Scheduler
local L = addon.L
local eventsFrame
local db

-- Bump when there's a change worth popping a "What's New" dialog.
local WHATS_NEW_VERSION = "3.0.7"

local function UseModern()
	return addon.Core.Compat:UseAddAuraSound()
end

local function ShowWhatsNew()
	if not db then return end
	local version = WHATS_NEW_VERSION
	if db.WhatsNewVersion == version then return end
	db.WhatsNewVersion = version

	local key = "changelog_v" .. version
	local body = L[key]
	if not body or body == "" or body == key then return end

	C_Timer.After(3, function()
		mini:ShowDialog({
			Title = L["PVP Sound - What's New?"],
			Text = body,
			Width = 480,
		})
	end)
end

local function OnEvent(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		addon:Refresh()
		ShowWhatsNew()
	end
end

local function OnAddonLoaded()
	local modern = UseModern()
	addon.Config = modern and addon.ConfigModern or addon.ConfigLegacy
	addon.Config:Init()

	scheduler:Init()
	addon.Utils.ModuleUtil:Init()

	if modern then
		addon.Modules.AuraSoundModule:Init()
		addon.Modules.SoundModule:Init()
	else
		addon.Modules.SoundModuleLegacy:Init()
	end
	if addon.Modules.ConsumableModule then
		addon.Modules.ConsumableModule:Init()
	end

	db = mini:GetSavedVars()

	eventsFrame = CreateFrame("Frame")
	eventsFrame:SetScript("OnEvent", OnEvent)
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function addon:Refresh()
	if UseModern() then
		if addon.Modules.SoundModule and addon.Modules.SoundModule.Refresh then
			addon.Modules.SoundModule:Refresh()
		end
		if addon.Modules.AuraSoundModule and addon.Modules.AuraSoundModule.Refresh then
			addon.Modules.AuraSoundModule:Refresh("addon:Refresh")
		end
	else
		if addon.Modules.SoundModuleLegacy and addon.Modules.SoundModuleLegacy.Refresh then
			addon.Modules.SoundModuleLegacy:Refresh()
		end
	end
	if addon.Modules.ConsumableModule and addon.Modules.ConsumableModule.Refresh then
		addon.Modules.ConsumableModule:Refresh()
	end
end

mini:WaitForAddonLoad(OnAddonLoaded)
