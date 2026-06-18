---@type string, Addon
local _, addon = ...
local mini = addon.Core.Framework
local scheduler = addon.Utils.Scheduler
local config = addon.Config
local soundModule = addon.Modules.SoundModule
local L = addon.L
local eventsFrame
local db

-- Bump this when there's a change worth popping a "What's New" dialog for.
-- The dialog body is the matching changelog string.
local WHATS_NEW_VERSION = "1.0.9"

local function ShowWhatsNew()
	if not db then return end
	if db.WhatsNewVersion == WHATS_NEW_VERSION then return end
	db.WhatsNewVersion = WHATS_NEW_VERSION

	local key = "changelog_v" .. WHATS_NEW_VERSION
	local body = L[key]
	-- L returns the key itself when a string is missing; skip if so.
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
	config:Init()
	scheduler:Init()
	addon.Utils.ModuleUtil:Init()

	soundModule:Init()

	db = mini:GetSavedVars()

	eventsFrame = CreateFrame("Frame")
	eventsFrame:SetScript("OnEvent", OnEvent)
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function addon:Refresh()
	soundModule:Refresh()
end

mini:WaitForAddonLoad(OnAddonLoaded)
