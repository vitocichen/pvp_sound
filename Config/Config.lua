---@type string, Addon
local addonName, addon = ...
local mini = addon.Core.Framework
local L = addon.L
local verticalSpacing = mini.VerticalSpacing
local horizontalSpacing = mini.HorizontalSpacing

---@type Db
local db

local dbDefaults = {
	Version = 2,

	TTS = {
		VoiceID = false,
		Volume = 100,
		SpeechRate = 5,
		CastMinDuration = 1.0,
		CastInterval = 0.0,
	},

	Zones = {
		World = {
			Enabled = true,
			Important = true,
			Defensive = true,
			CastBar = true,
			InterruptAlert = true,
			CCMode = "Self",
			TargetFocusOnly = true,
		},
		Arena = {
			Enabled = true,
			Important = true,
			Defensive = true,
			CastBar = true,
			InterruptAlert = true,
			CCMode = "Self",
			TargetFocusOnly = false,
		},
		BattleGrounds = {
			Enabled = true,
			Important = true,
			Defensive = true,
			CastBar = true,
			InterruptAlert = true,
			CCMode = "Self",
			TargetFocusOnly = true,
		},
		PvE = {
			Enabled = false,
			Important = true,
			Defensive = true,
			CastBar = true,
			InterruptAlert = true,
			CCMode = "Off",
			TargetFocusOnly = true,
		},
	},
}

local M = addon.Config

function M:Apply()
	addon:Refresh()
end

-- Migrate old v1 format to v2
local function MigrateV1(savedDb)
	if not savedDb or savedDb.Version == 2 then return end

	local oldEnabled = savedDb.Enabled or {}
	local oldTTS = savedDb.TTS or {}
	local oldImportant = oldTTS.Important and oldTTS.Important.Enabled
	local oldDefensive = oldTTS.Defensive and oldTTS.Defensive.Enabled
	local oldCCMode = oldTTS.CC and oldTTS.CC.Mode or "Off"
	local oldTargetFocusOnly = savedDb.TargetFocusOnly

	if oldImportant == nil then oldImportant = true end
	if oldDefensive == nil then oldDefensive = true end
	if oldTargetFocusOnly == nil then oldTargetFocusOnly = true end

	local zones = {}
	for _, zoneKey in ipairs({ "World", "Arena", "BattleGrounds", "PvE" }) do
		local zoneEnabled
		if oldEnabled[zoneKey] ~= nil then
			zoneEnabled = oldEnabled[zoneKey]
		else
			zoneEnabled = dbDefaults.Zones[zoneKey].Enabled
		end
		zones[zoneKey] = {
			Enabled = zoneEnabled,
			Important = oldImportant,
			Defensive = oldDefensive,
			CCMode = oldCCMode,
			TargetFocusOnly = (zoneKey == "Arena") and false or oldTargetFocusOnly,
		}
	end

	savedDb.Enabled = nil
	savedDb.TargetFocusOnly = nil
	if savedDb.TTS then
		savedDb.TTS.Important = nil
		savedDb.TTS.Defensive = nil
		savedDb.TTS.CC = nil
	end

	savedDb.Zones = zones
	savedDb.Version = 2
end

-- ==================== Shared helpers ====================

local voiceItems = {}
local voiceNameById = {}

local function BuildVoiceList()
	if #voiceItems > 0 then return end
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
	if #voiceItems == 0 then
		local fallback = C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0) or 0
		voiceItems = { fallback }
		voiceNameById[fallback] = tostring(fallback)
	end
end

local function AutoSelectVoice()
	if db.TTS.VoiceID and db.TTS.VoiceID ~= false then return end
	for id, name in pairs(voiceNameById) do
		if name and name:lower():find("xiaoxiao") then
			db.TTS.VoiceID = id
			return
		end
	end
end

local function EnsureTtsOptions()
	if not db.TTS then
		db.TTS = { Volume = 100, SpeechRate = 0 }
	end
	if db.TTS.SpeechRate == nil then
		db.TTS.SpeechRate = 0
	end
end

local function DoTest()
	local voiceId = db.TTS and db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
	local vol = db.TTS and db.TTS.Volume or 100
	local rate = db.TTS and db.TTS.SpeechRate or 0
	C_VoiceChat.SpeakText(voiceId, "PVP Sound Test", rate, vol, true)
end

-- ==================== Build Home Tab ====================

local function BuildHomeTab(content)
	-- Introduction
	local introBlock = mini:TextBlock({
		Parent = content,
		Lines = {
			L["home_intro_1"],
			" ",
			L["home_intro_2"],
			L["home_intro_3"],
			L["home_intro_4"],
			L["home_intro_5"],
			" ",
			L["home_intro_6"],
			" ",
			L["home_intro_7"],
		},
	})
	introBlock:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)

	-- ==================== TTS Settings ====================
	local ttsDivider = mini:Divider({
		Parent = content,
		Text = L["TTS Settings"],
	})
	ttsDivider:SetPoint("LEFT", content, "LEFT")
	ttsDivider:SetPoint("RIGHT", content, "RIGHT")
	ttsDivider:SetPoint("TOP", introBlock, "BOTTOM", 0, -verticalSpacing)

	local ttsIntro = mini:TextBlock({
		Parent = content,
		Lines = {
			L["You must choose a voice in your language for this to work."],
		},
	})
	ttsIntro:SetPoint("TOPLEFT", ttsDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Voice dropdown
	local voiceLabel = mini:TextLine({
		Parent = content,
		Text = L["Voice"],
	})
	voiceLabel:SetPoint("TOPLEFT", ttsIntro, "BOTTOMLEFT", 0, -verticalSpacing)

	local voiceDropdown = mini:Dropdown({
		Parent = content,
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
	voiceDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	voiceDropdown:SetPoint("TOP", voiceLabel, "TOP", 0, 8)
	voiceDropdown:SetWidth(200)

	-- Volume slider
	local volumeSlider = mini:Slider({
		Parent = content,
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
		Parent = content,
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

	-- Cast Interval slider
	local castIntervalSlider = mini:Slider({
		Parent = content,
		Min = 0,
		Max = 5,
		Width = (columnWidth * 2) - horizontalSpacing,
		Step = 0.5,
		LabelText = L["Cast Interval"],
		GetValue = function()
			EnsureTtsOptions()
			return db.TTS.CastInterval or 0
		end,
		SetValue = function(v)
			EnsureTtsOptions()
			local newValue = tonumber(string.format("%.1f", v)) or 0
			if newValue < 0 then newValue = 0 end
			if newValue > 5 then newValue = 5 end
			if db.TTS.CastInterval ~= newValue then
				db.TTS.CastInterval = newValue
				M:Apply()
			end
		end,
	})
	castIntervalSlider.Slider:SetPoint("TOPLEFT", volumeSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	-- Test button
	local testBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	testBtn:SetSize(120, 26)
	testBtn:SetPoint("TOPLEFT", castIntervalSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 2)
	testBtn:SetText(L["Test"])
	testBtn:SetScript("OnClick", DoTest)

	-- Reset button
	local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 26)
	resetBtn:SetPoint("LEFT", testBtn, "RIGHT", horizontalSpacing, 0)
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
				addon:Refresh()
				mini:Notify(L["Settings reset to default."])
			end,
		})
	end)
end

-- ==================== Build Zone Tab ====================

local function BuildZoneTab(content, zoneKey)
	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)

	local function GetZone()
		return db.Zones[zoneKey]
	end

	-- Enabled checkbox
	local enabledChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Enabled"],
		Tooltip = L["Enable announcements in this zone."],
		GetValue = function() return GetZone().Enabled end,
		SetValue = function(value)
			GetZone().Enabled = value
			M:Apply()
		end,
	})
	enabledChk:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	-- Important Spells
	local importantChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Important Spells"],
		Tooltip = L["Announce important (offensive) spell names via TTS when enemies cast them."],
		GetValue = function() return GetZone().Important end,
		SetValue = function(value)
			GetZone().Important = value
			M:Apply()
		end,
	})
	importantChk:SetPoint("TOPLEFT", enabledChk, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Defensive Spells
	local defensiveChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Defensive Spells"],
		Tooltip = L["Announce defensive spell names via TTS when enemies cast them."],
		GetValue = function() return GetZone().Defensive end,
		SetValue = function(value)
			GetZone().Defensive = value
			M:Apply()
		end,
	})
	defensiveChk:SetPoint("TOPLEFT", importantChk, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Cast Bar
	local castBarChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Target Cast Bar"],
		Tooltip = L["Announce your target's spell casts via TTS."],
		GetValue = function() return GetZone().CastBar end,
		SetValue = function(value)
			GetZone().CastBar = value
			M:Apply()
		end,
	})
	castBarChk:SetPoint("TOPLEFT", defensiveChk, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Interrupt Alert
	local interruptChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Interrupt Alert"],
		Tooltip = L["Announce via TTS when you successfully interrupt an enemy cast."],
		GetValue = function() return GetZone().InterruptAlert end,
		SetValue = function(value)
			GetZone().InterruptAlert = value
			M:Apply()
		end,
	})
	interruptChk:SetPoint("TOPLEFT", castBarChk, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Friendly CC dropdown
	local ccModeLabel = mini:TextLine({
		Parent = content,
		Text = L["Friendly CC"],
		Tooltip = L["Announce CC on self or party via TTS."],
	})
	ccModeLabel:SetPoint("TOPLEFT", interruptChk, "BOTTOMLEFT", 0, -verticalSpacing)

	local ccModeItems = { "Off", "Self", "All" }
	local ccModeDropdown = mini:Dropdown({
		Parent = content,
		Items = ccModeItems,
		Width = 160,
		GetValue = function()
			return GetZone().CCMode or "Off"
		end,
		SetValue = function(value)
			GetZone().CCMode = value
			M:Apply()
		end,
		GetText = function(value)
			if value == "Off" then return L["Off"]
			elseif value == "Self" then return L["Self Only"]
			else return L["Self + Party"]
			end
		end,
	})
	ccModeDropdown:SetPoint("TOPLEFT", ccModeLabel, "BOTTOMLEFT", 0, -verticalSpacing + 4)
	ccModeDropdown:SetWidth(160)

	-- TargetFocusOnly (not for Arena)
	if zoneKey ~= "Arena" then
		local targetFocusChk = mini:Checkbox({
			Parent = content,
			LabelText = L["Target/Focus Only"],
			Tooltip = L["Only monitor your target and focus instead of all enemy nameplates."],
			GetValue = function() return GetZone().TargetFocusOnly ~= false end,
			SetValue = function(value)
				GetZone().TargetFocusOnly = value
				M:Apply()
			end,
		})
		targetFocusChk:SetPoint("TOPLEFT", ccModeDropdown, "BOTTOMLEFT", 0, -verticalSpacing * 1.5)
	end
end

-- ==================== Init ====================

function M:Init()
	local rawDb = mini:GetSavedVars()
	MigrateV1(rawDb)

	db = mini:GetSavedVars(dbDefaults)
	mini:CleanTable(db, dbDefaults, true, true)

	BuildVoiceList()
	AutoSelectVoice()

	-- ==================== Main scroll panel ====================
	local scroll = CreateFrame("ScrollFrame", nil, nil, "UIPanelScrollFrameTemplate")
	scroll.name = addonName

	local category = mini:AddCategory(scroll)
	if not category then return end

	local panel = CreateFrame("Frame", nil, scroll)
	local width, height = mini:SettingsSize()
	panel:SetWidth(width)
	panel:SetHeight(height * 3)
	scroll:SetScrollChild(panel)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(scrollSelf, delta)
		local step = 30
		local current = scrollSelf:GetVerticalScroll()
		local max = scrollSelf:GetVerticalScrollRange()
		if delta > 0 then
			scrollSelf:SetVerticalScroll(math.max(current - step, 0))
		else
			scrollSelf:SetVerticalScroll(math.min(current + step, max))
		end
	end)

	-- ==================== Title ====================
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local lines = mini:TextBlock({
		Parent = panel,
		Lines = {
			L["addon_description"],
			L["Author: DK-姜世离（燃烧之刃）"],
		},
	})
	lines:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	-- ==================== Tabs ====================
	local tabsPanel = CreateFrame("Frame", nil, panel)
	tabsPanel:SetPoint("TOPLEFT", lines, "BOTTOMLEFT", 0, -verticalSpacing)
	tabsPanel:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	tabsPanel:SetPoint("BOTTOM", panel, "BOTTOM", 0, verticalSpacing * 2)

	local tabController = mini:CreateTabs({
		Parent = tabsPanel,
		InitialKey = "Home",
		ContentInsets = { Top = verticalSpacing },
		Tabs = {
			{
				Key = "Home",
				Title = addonName,
				Build = function(content) BuildHomeTab(content) end,
			},
			{
				Key = "World",
				Title = L["World"],
				Build = function(content) BuildZoneTab(content, "World") end,
			},
			{
				Key = "Arena",
				Title = L["Arena"],
				Build = function(content) BuildZoneTab(content, "Arena") end,
			},
			{
				Key = "BattleGrounds",
				Title = L["Battlegrounds"],
				Build = function(content) BuildZoneTab(content, "BattleGrounds") end,
			},
			{
				Key = "PvE",
				Title = L["PvE"],
				Build = function(content) BuildZoneTab(content, "PvE") end,
			},
		},
	})

	M.TabController = tabController

	-- ==================== Confirm popup ====================
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

	-- ==================== Slash commands ====================
	SLASH_PVPSOUND1 = "/pvpsound"
	SLASH_PVPSOUND2 = "/ps"

	SlashCmdList.PVPSOUND = function(msg)
		msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
		if msg == "test" then
			DoTest()
			return
		end
		mini:OpenSettings(category, scroll)
	end
end
