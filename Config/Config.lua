---@type string, Addon
local addonName, addon = ...
local mini = addon.Core.Framework
local L = addon.L
local verticalSpacing = mini.VerticalSpacing
local horizontalSpacing = mini.HorizontalSpacing

---@type Db
local db

local dbDefaults = {
	Version = 1,

	Enabled = {
		World = true,
		Arena = true,
		BattleGrounds = true,
		PvE = false,
	},

	TargetFocusOnly = true,

	TTS = {
		VoiceID = false,
		Volume = 100,
		SpeechRate = 5,
		Important = {
			Enabled = true,
		},
		Defensive = {
			Enabled = true,
		},
		CC = {
			Mode = "Self",
		},
	},
}

local M = addon.Config

function M:Apply()
	addon:Refresh()
end

function M:Init()
	db = mini:GetSavedVars(dbDefaults)

	-- Clean up any garbage from old versions
	mini:CleanTable(db, dbDefaults, true, true)

	local scroll = CreateFrame("ScrollFrame", nil, nil, "UIPanelScrollFrameTemplate")
	scroll.name = addonName

	local category = mini:AddCategory(scroll)
	if not category then return end

	local panel = CreateFrame("Frame", nil, scroll)
	local width, height = mini:SettingsSize()
	panel:SetWidth(width)
	panel:SetHeight(height * 2)
	scroll:SetScrollChild(panel)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(scrollSelf, delta)
		local step = 20
		local current = scrollSelf:GetVerticalScroll()
		local max = scrollSelf:GetVerticalScrollRange()
		if delta > 0 then
			scrollSelf:SetVerticalScroll(math.max(current - step, 0))
		else
			scrollSelf:SetVerticalScroll(math.min(current + step, max))
		end
	end)

	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)

	-- ==================== Title ====================
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local lines = mini:TextBlock({
		Parent = panel,
		Lines = {
			L["PVP Sound - TTS voice announcements for PvP spells."],
			L["Author: DK-姜世离（燃烧之刃）"],
		},
	})
	lines:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	-- ==================== Enable in: ====================
	local enabledDivider = mini:Divider({
		Parent = panel,
		Text = L["Enable in:"],
	})
	enabledDivider:SetPoint("LEFT", panel, "LEFT")
	enabledDivider:SetPoint("RIGHT", panel, "RIGHT")
	enabledDivider:SetPoint("TOP", lines, "BOTTOM", 0, -verticalSpacing)

	local enabledWorld = mini:Checkbox({
		Parent = panel,
		LabelText = L["World"],
		Tooltip = L["Enable this module in the open world."],
		GetValue = function() return db.Enabled.World end,
		SetValue = function(value)
			db.Enabled.World = value
			M:Apply()
		end,
	})
	enabledWorld:SetPoint("TOPLEFT", enabledDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local enabledArena = mini:Checkbox({
		Parent = panel,
		LabelText = L["Arena"],
		Tooltip = L["Enable this module in arena."],
		GetValue = function() return db.Enabled.Arena end,
		SetValue = function(value)
			db.Enabled.Arena = value
			M:Apply()
		end,
	})
	enabledArena:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)
	enabledArena:SetPoint("TOP", enabledWorld, "TOP", 0, 0)

	local enabledBG = mini:Checkbox({
		Parent = panel,
		LabelText = L["Battlegrounds"],
		Tooltip = L["Enable this module in battlegrounds."],
		GetValue = function() return db.Enabled.BattleGrounds end,
		SetValue = function(value)
			db.Enabled.BattleGrounds = value
			M:Apply()
		end,
	})
	enabledBG:SetPoint("LEFT", panel, "LEFT", columnWidth * 2, 0)
	enabledBG:SetPoint("TOP", enabledWorld, "TOP", 0, 0)

	local enabledPvE = mini:Checkbox({
		Parent = panel,
		LabelText = L["PvE"],
		Tooltip = L["Enable this module in PvE."],
		GetValue = function() return db.Enabled.PvE end,
		SetValue = function(value)
			db.Enabled.PvE = value
			M:Apply()
		end,
	})
	enabledPvE:SetPoint("LEFT", panel, "LEFT", columnWidth * 3, 0)
	enabledPvE:SetPoint("TOP", enabledWorld, "TOP", 0, 0)

	-- ==================== TTS Settings ====================
	local ttsDivider = mini:Divider({
		Parent = panel,
		Text = L["TTS Settings"],
	})
	ttsDivider:SetPoint("LEFT", panel, "LEFT")
	ttsDivider:SetPoint("RIGHT", panel, "RIGHT")
	ttsDivider:SetPoint("TOP", enabledWorld, "BOTTOM", 0, -verticalSpacing)

	local ttsIntro = mini:TextBlock({
		Parent = panel,
		Lines = {
			L["You must choose a voice in your language for this to work."],
		},
	})
	ttsIntro:SetPoint("TOPLEFT", ttsDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local function EnsureTtsOptions()
		if not db.TTS then
			db.TTS = { Volume = 100, SpeechRate = 0 }
		end
		if db.TTS.SpeechRate == nil then
			db.TTS.SpeechRate = 0
		end
	end

	-- Build voice list
	local voiceItems = {}
	local voiceNameById = {}
	do
		local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or nil
		if voices then
			for _, v in ipairs(voices) do
				if v and v.voiceID ~= nil then
					voiceItems[#voiceItems + 1] = v.voiceID
					voiceNameById[v.voiceID] = v.name or tostring(v.voiceID)
				end
			end
			table.sort(voiceItems, function(a, b)
				return (voiceNameById[a] or tostring(a)) < (voiceNameById[b] or tostring(b))
			end)
		end
	end

	if #voiceItems == 0 then
		local fallback = C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0) or 0
		voiceItems = { fallback }
		voiceNameById[fallback] = tostring(fallback)
	end

	-- Auto-select xiaoxiao voice as default if user hasn't chosen one
	if not db.TTS.VoiceID or db.TTS.VoiceID == false then
		for id, name in pairs(voiceNameById) do
			if name and name:lower():find("xiaoxiao") then
				db.TTS.VoiceID = id
				break
			end
		end
	end

	-- Voice dropdown
	local voiceLabel = mini:TextLine({
		Parent = panel,
		Text = L["Voice"],
	})
	voiceLabel:SetPoint("TOPLEFT", ttsIntro, "BOTTOMLEFT", 0, -verticalSpacing)

	local voiceDropdown = mini:Dropdown({
		Parent = panel,
		Items = voiceItems,
		Width = 240,
		GetValue = function()
			EnsureTtsOptions()
			return db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
		end,
		SetValue = function(value)
			EnsureTtsOptions()
			db.TTS.VoiceID = value
			local speechRate = db.TTS.SpeechRate or 0
			C_VoiceChat.SpeakText(value, L["Voice"], speechRate, db.TTS.Volume or 100, true)
			M:Apply()
		end,
		GetText = function(value)
			return voiceNameById[value] or tostring(value)
		end,
	})
	voiceDropdown:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)
	voiceDropdown:SetPoint("TOP", voiceLabel, "TOP", 0, 8)
	voiceDropdown:SetWidth(200)

	-- Volume slider
	local volumeSlider = mini:Slider({
		Parent = panel,
		Min = 0,
		Max = 100,
		Width = (columnWidth * 2) - horizontalSpacing,
		Step = 1,
		LabelText = L["TTS Volume"],
		GetValue = function()
			return db.TTS and db.TTS.Volume or 100
		end,
		SetValue = function(v)
			local newValue = mini:ClampInt(v, 0, 100, 100)
			EnsureTtsOptions()
			if db.TTS.Volume ~= newValue then
				db.TTS.Volume = newValue
				M:Apply()
			end
		end,
	})
	volumeSlider.Slider:SetPoint("TOPLEFT", voiceLabel, "BOTTOMLEFT", 4, -verticalSpacing * 3)

	-- Speech Rate slider
	local speechRateSlider = mini:Slider({
		Parent = panel,
		Min = -5,
		Max = 5,
		Width = (columnWidth * 2) - horizontalSpacing,
		Step = 1,
		LabelText = L["TTS Speech Rate"],
		GetValue = function()
			EnsureTtsOptions()
			return db.TTS.SpeechRate or 0
		end,
		SetValue = function(v)
			local newValue = mini:ClampInt(v, -5, 5, 0)
			EnsureTtsOptions()
			if db.TTS.SpeechRate ~= newValue then
				db.TTS.SpeechRate = newValue
				M:Apply()
			end
		end,
	})
	speechRateSlider.Slider:SetPoint("LEFT", volumeSlider.Slider, "RIGHT", horizontalSpacing, 0)

	-- ==================== Announce Categories ====================
	local categDivider = mini:Divider({
		Parent = panel,
		Text = L["Announce Categories"],
	})
	categDivider:SetPoint("LEFT", panel, "LEFT")
	categDivider:SetPoint("RIGHT", panel, "RIGHT")
	categDivider:SetPoint("TOP", volumeSlider.Slider, "BOTTOM", 0, -verticalSpacing * 2)

	-- Important spells checkbox
	local importantChk = mini:Checkbox({
		Parent = panel,
		LabelText = L["Important Spells"],
		Tooltip = L["Announce important (offensive) spell names via TTS when enemies cast them."],
		GetValue = function()
			return db.TTS and db.TTS.Important and db.TTS.Important.Enabled or false
		end,
		SetValue = function(value)
			EnsureTtsOptions()
			if not db.TTS.Important then
				db.TTS.Important = { Enabled = false }
			end
			db.TTS.Important.Enabled = value
			if value then
				local voiceId = db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
				local vol = db.TTS.Volume or 100
				local rate = db.TTS.SpeechRate or 0
				C_VoiceChat.SpeakText(voiceId, L["Important"], rate, vol, true)
			end
			M:Apply()
		end,
	})
	importantChk:SetPoint("TOPLEFT", categDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Defensive spells checkbox
	local defensiveChk = mini:Checkbox({
		Parent = panel,
		LabelText = L["Defensive Spells"],
		Tooltip = L["Announce defensive spell names via TTS when enemies cast them."],
		GetValue = function()
			return db.TTS and db.TTS.Defensive and db.TTS.Defensive.Enabled or false
		end,
		SetValue = function(value)
			EnsureTtsOptions()
			if not db.TTS.Defensive then
				db.TTS.Defensive = { Enabled = false }
			end
			db.TTS.Defensive.Enabled = value
			if value then
				local voiceId = db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
				local vol = db.TTS.Volume or 100
				local rate = db.TTS.SpeechRate or 0
				C_VoiceChat.SpeakText(voiceId, L["Defensive"], rate, vol, true)
			end
			M:Apply()
		end,
	})
	defensiveChk:SetPoint("TOPLEFT", importantChk, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Friendly CC mode
	local ccModeLabel = mini:TextLine({
		Parent = panel,
		Text = L["Friendly CC"],
		Tooltip = L["Announce CC on self or party via TTS."],
	})
	ccModeLabel:SetPoint("TOPLEFT", defensiveChk, "BOTTOMLEFT", 0, -verticalSpacing)

	local ccModeItems = { "Off", "Self", "All" }
	local ccModeDropdown = mini:Dropdown({
		Parent = panel,
		Items = ccModeItems,
		Width = 160,
		GetValue = function()
			return db.TTS and db.TTS.CC and db.TTS.CC.Mode or "Off"
		end,
		SetValue = function(value)
			EnsureTtsOptions()
			if not db.TTS.CC then
				db.TTS.CC = { Mode = "Off" }
			end
			db.TTS.CC.Mode = value

			if value ~= "Off" then
				local voiceId = db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
				local vol = db.TTS.Volume or 100
				local rate = db.TTS.SpeechRate or 0
				local testText = value == "Self" and L["Self Only"] or L["Self + Party"]
				C_VoiceChat.SpeakText(voiceId, testText, rate, vol, true)
			end
			M:Apply()
		end,
		GetText = function(value)
			if value == "Off" then return L["Off"]
			elseif value == "Self" then return L["Self Only"]
			else return L["Self + Party"]
			end
		end,
	})
	ccModeDropdown:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)
	ccModeDropdown:SetPoint("TOP", ccModeLabel, "TOP", 0, 8)
	ccModeDropdown:SetWidth(160)

	-- ==================== Miscellaneous ====================
	local miscDivider = mini:Divider({
		Parent = panel,
		Text = L["Settings:"],
	})
	miscDivider:SetPoint("LEFT", panel, "LEFT")
	miscDivider:SetPoint("RIGHT", panel, "RIGHT")
	miscDivider:SetPoint("TOP", ccModeLabel, "BOTTOM", 0, -verticalSpacing * 2)

	local targetFocusOnlyChk = mini:Checkbox({
		Parent = panel,
		LabelText = L["Target/Focus Only"],
		Tooltip = L["Only monitor your target and focus in battlegrounds and the open world."],
		GetValue = function()
			return db.TargetFocusOnly ~= false
		end,
		SetValue = function(value)
			db.TargetFocusOnly = value
			M:Apply()
		end,
	})
	targetFocusOnlyChk:SetPoint("TOPLEFT", miscDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Reset button
	local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 26)
	resetBtn:SetPoint("TOPLEFT", targetFocusOnlyChk, "BOTTOMLEFT", 0, -verticalSpacing * 2)
	resetBtn:SetText(L["Reset"])
	resetBtn:SetScript("OnClick", function()
		if InCombatLockdown() then
			mini:NotifyCombatLockdown()
			return
		end

		StaticPopup_Show("PVPSOUND_CONFIRM", L["Are you sure you wish to reset to factory settings?"], nil, {
			OnYes = function()
				mini:ResetSavedVars(dbDefaults)
				db = mini:GetSavedVars()
				panel:MiniRefresh()
				addon:Refresh()
				mini:Notify(L["Settings reset to default."])
			end,
		})
	end)

	-- Test button
	local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testBtn:SetSize(120, 26)
	testBtn:SetPoint("RIGHT", panel, "RIGHT", -horizontalSpacing, 0)
	testBtn:SetPoint("TOP", title, "TOP", 0, 0)
	testBtn:SetText(L["Test"])
	testBtn:SetScript("OnClick", function()
		local voiceId = db.TTS and db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
		local vol = db.TTS and db.TTS.Volume or 100
		local rate = db.TTS and db.TTS.SpeechRate or 0
		C_VoiceChat.SpeakText(voiceId, "PVP Sound Test", rate, vol, true)
	end)

	-- Confirm popup
	StaticPopupDialogs["PVPSOUND_CONFIRM"] = {
		text = "%s",
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			if data and data.OnYes then
				data.OnYes()
			end
		end,
		OnCancel = function(_, data)
			if data and data.OnNo then
				data.OnNo()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	-- Slash commands
	SLASH_PVPSOUND1 = "/pvpsound"
	SLASH_PVPSOUND2 = "/ps"

	SlashCmdList.PVPSOUND = function(msg)
		msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
		if msg == "test" then
			local voiceId = db.TTS and db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
			local vol = db.TTS and db.TTS.Volume or 100
			local rate = db.TTS and db.TTS.SpeechRate or 0
			C_VoiceChat.SpeakText(voiceId, "PVP Sound Test", rate, vol, true)
			return
		end
		mini:OpenSettings(category, panel)
	end

	panel:HookScript("OnShow", function()
		if panel.MiniRefresh then
			panel:MiniRefresh()
		end
	end)
end
