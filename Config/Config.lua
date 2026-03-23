---@type string, Addon
local addonName, addon = ...
local mini = addon.Core.Framework
local L = addon.L
local verticalSpacing = mini.VerticalSpacing
local horizontalSpacing = mini.HorizontalSpacing

---@type Db
local db

local dbDefaults = {
	Version = 7,

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
			ImportantEnabled = true,
			Important = true,
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = true,
			CCMode = "Self",
			CastBar = true,
			CastBarTargetOnly = true,
			InterruptAlert = true,
		},
		Arena = {
			Enabled = true,
			ImportantEnabled = true,
			Important = true,
			Defensive = true,
			TargetFocusOnly = false,
			CCEnabled = true,
			CCMode = "Self",
			CastBar = true,
			CastBarTargetOnly = true,
			InterruptAlert = true,
			HealerCC = true,
			HealerCCMode = "TTS",
			HealerCCText = "治疗被控",
			HealerCCSoundFile = "夏一可_控制成功.ogg",
		},
		BattleGrounds = {
			Enabled = true,
			ImportantEnabled = true,
			Important = true,
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = true,
			CCMode = "Self",
			CastBar = true,
			CastBarTargetOnly = true,
			InterruptAlert = true,
			HealerCC = true,
			HealerCCMode = "TTS",
			HealerCCText = "治疗被控",
			HealerCCSoundFile = "夏一可_控制成功.ogg",
		},
		PvE = {
			Enabled = false,
			ImportantEnabled = true,
			Important = true,
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = false,
			CCMode = "Off",
			CastBar = true,
			CastBarTargetOnly = true,
			InterruptAlert = true,
		},
	},
}

local M = addon.Config

function M:Apply()
	addon:Refresh()
end

-- Migrate old v1 format to v2
local function MigrateV1(savedDb)
	if not savedDb or (savedDb.Version and savedDb.Version >= 2) then return end

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

-- Migrate v2 format to v3: add CastBarTargetOnly and HealerCC
local function MigrateV2(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 3 then return end

	if savedDb.Zones then
		for zoneKey, zone in pairs(savedDb.Zones) do
			-- Add CastBarTargetOnly (default true = current behavior)
			if zone.CastBarTargetOnly == nil then
				zone.CastBarTargetOnly = true
			end
			-- Add HealerCC for Arena
			if zoneKey == "Arena" then
				if zone.HealerCC == nil then
					zone.HealerCC = true
				end
				if zone.HealerCCText == nil then
					zone.HealerCCText = "治疗被控"
				end
			end
		end
	end

	savedDb.Version = 3
end

-- Migrate v3 format to v4: add ImportantEnabled
local function MigrateV3(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 4 then return end

	if savedDb.Zones then
		for _, zone in pairs(savedDb.Zones) do
			if zone.ImportantEnabled == nil then
				zone.ImportantEnabled = true
			end
		end
	end

	savedDb.Version = 4
end

-- Migrate v4 format to v5: add CCEnabled
local function MigrateV4(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 5 then return end

	if savedDb.Zones then
		for _, zone in pairs(savedDb.Zones) do
			if zone.CCEnabled == nil then
				-- If CCMode was "Off", set CCEnabled to false; otherwise true
				zone.CCEnabled = (zone.CCMode ~= "Off")
			end
		end
	end

	savedDb.Version = 5
end

-- Migrate v5 format to v6: add HealerCCMode and HealerCCSoundFile
local function MigrateV5(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 6 then return end

	if savedDb.Zones and savedDb.Zones.Arena then
		local arena = savedDb.Zones.Arena
		if arena.HealerCCMode == nil then
			arena.HealerCCMode = "TTS"
		end
		if arena.HealerCCSoundFile == nil then
			arena.HealerCCSoundFile = "夏一可_控制成功.ogg"
		end
	end

	savedDb.Version = 6
end

-- Migrate v6 format to v7: add HealerCC to BattleGrounds
local function MigrateV6(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 7 then return end

	if savedDb.Zones and savedDb.Zones.BattleGrounds then
		local bg = savedDb.Zones.BattleGrounds
		if bg.HealerCC == nil then
			bg.HealerCC = true
		end
		if bg.HealerCCMode == nil then
			bg.HealerCCMode = "TTS"
		end
		if bg.HealerCCText == nil then
			bg.HealerCCText = "治疗被控"
		end
		if bg.HealerCCSoundFile == nil then
			bg.HealerCCSoundFile = "夏一可_控制成功.ogg"
		end
	end

	savedDb.Version = 7
end

-- ==================== Sound files ====================

local soundFiles = {}
local mediaPath = "Interface\\AddOns\\PVP_Sound\\Media\\"

local function BuildSoundFileList()
	if #soundFiles > 0 then return end
	-- Hardcoded list of available sound files in Media folder
	local files = {
		"PS_Alert.ogg",
		"PS_Chime.ogg",
		"PS_Error.ogg",
		"PS_Horn.ogg",
		"PS_Impact.ogg",
		"PS_Ping.ogg",
		"PS_Pop.ogg",
		"PS_Radar.ogg",
		"PS_Shock.ogg",
		"PS_Swoosh.ogg",
		"PS_Warm.ogg",
		"夏一可_控制成功.ogg",
	}
	for _, f in ipairs(files) do
		soundFiles[#soundFiles + 1] = f
	end
end

local function PreviewSoundFile(fileName)
	if not fileName then return end
	local path = mediaPath .. fileName
	PlaySoundFile(path, "Master")
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
			L["home_intro_5b"],
			L["home_intro_5c"],
			L["home_intro_5d"],
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

-- ==================== Build Changelog Tab ====================

local function BuildChangelogTab(content)
	local changelogBlock = mini:TextBlock({
		Parent = content,
		Lines = {
			L["changelog_v1.0.4"],
			" ",
			L["changelog_v1.0.3"],
			" ",
			L["changelog_v1.0.2"],
			" ",
			L["changelog_v1.0.1"],
			" ",
			L["changelog_v1.0.0"],
		},
	})
	changelogBlock:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
end

-- ==================== Build Zone Tab ====================

local function BuildZoneTab(content, zoneKey)
	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)

	local function GetZone()
		return db.Zones[zoneKey]
	end

	-- Global Enabled checkbox at top (总开关)
	local enabledChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Enabled (Master)"],
		Tooltip = L["Master switch: enable all announcements in this zone."],
		GetValue = function() return GetZone().Enabled end,
		SetValue = function(value)
			GetZone().Enabled = value
			M:Apply()
		end,
	})
	enabledChk:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

	-- ==================== Section 1: Important Spells ====================
	local importantDivider = mini:Divider({
		Parent = content,
		Text = L["Important Spells Section"],
	})
	importantDivider:SetPoint("LEFT", content, "LEFT")
	importantDivider:SetPoint("RIGHT", content, "RIGHT")
	importantDivider:SetPoint("TOP", enabledChk, "BOTTOM", 0, -verticalSpacing * 1.5)

	local importantEnabledChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Enabled"],
		Tooltip = L["Enable important and defensive spell announcements."],
		GetValue = function() return GetZone().ImportantEnabled ~= false end,
		SetValue = function(value)
			GetZone().ImportantEnabled = value
			M:Apply()
		end,
	})
	importantEnabledChk:SetPoint("TOPLEFT", importantDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Monitor Range dropdown (not for Arena — arena always monitors all arena units)
	local importantLastElement = importantEnabledChk
	if zoneKey ~= "Arena" then
		local monitorRangeLabel = mini:TextLine({
			Parent = content,
			Text = L["Important Monitor Range"],
			Tooltip = L["Only monitor your target and focus instead of all enemy nameplates."],
		})
		monitorRangeLabel:SetPoint("TOPLEFT", importantEnabledChk, "BOTTOMLEFT", 0, -verticalSpacing)

		local monitorRangeItems = { "TargetFocus", "All" }
		local monitorRangeDropdown = mini:Dropdown({
			Parent = content,
			Items = monitorRangeItems,
			Width = 200,
			GetValue = function()
				return GetZone().TargetFocusOnly ~= false and "TargetFocus" or "All"
			end,
			SetValue = function(value)
				GetZone().TargetFocusOnly = (value == "TargetFocus")
				M:Apply()
			end,
			GetText = function(value)
				if value == "TargetFocus" then return L["Target/Focus Only Short"]
				else return L["All Enemies"]
				end
			end,
		})
		monitorRangeDropdown:SetPoint("TOPLEFT", monitorRangeLabel, "BOTTOMLEFT", 0, -verticalSpacing * 0.5)
		monitorRangeDropdown:SetWidth(200)

		importantLastElement = monitorRangeDropdown
	end

	-- Important Spells checkbox
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
	importantChk:SetPoint("TOPLEFT", importantLastElement, "BOTTOMLEFT", 0, -verticalSpacing)

	-- Defensive Spells checkbox (same row as Important)
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
	defensiveChk:SetPoint("LEFT", importantChk, "RIGHT", 160, 0)

	-- ==================== Section 2: CC Spells ====================
	local ccDivider = mini:Divider({
		Parent = content,
		Text = L["CC Spells Section"],
	})
	ccDivider:SetPoint("LEFT", content, "LEFT")
	ccDivider:SetPoint("RIGHT", content, "RIGHT")
	ccDivider:SetPoint("TOP", importantChk, "BOTTOM", 0, -verticalSpacing * 1.5)

	local ccEnabledChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Enabled"],
		Tooltip = L["Enable CC spell announcements."],
		GetValue = function() return GetZone().CCEnabled ~= false end,
		SetValue = function(value)
			GetZone().CCEnabled = value
			M:Apply()
		end,
	})
	ccEnabledChk:SetPoint("TOPLEFT", ccDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local ccModeLabel = mini:TextLine({
		Parent = content,
		Text = L["CC Mode"],
		Tooltip = L["Announce CC on self or party via TTS."],
	})
	ccModeLabel:SetPoint("TOPLEFT", ccEnabledChk, "BOTTOMLEFT", 0, -verticalSpacing)

	local ccModeItems = { "Self", "All" }
	local ccModeDropdown = mini:Dropdown({
		Parent = content,
		Items = ccModeItems,
		Width = 160,
		GetValue = function()
			local mode = GetZone().CCMode or "Self"
			if mode == "Off" then mode = "Self" end
			return mode
		end,
		SetValue = function(value)
			GetZone().CCMode = value
			M:Apply()
		end,
		GetText = function(value)
			if value == "Self" then return L["Self Only"]
			else return L["Self + Party"]
			end
		end,
	})
	ccModeDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	ccModeDropdown:SetPoint("TOP", ccModeLabel, "TOP", 0, 8)
	ccModeDropdown:SetWidth(160)

	-- ==================== Section 3: Cast Bar ====================
	local castDivider = mini:Divider({
		Parent = content,
		Text = L["CastBar Section"],
	})
	castDivider:SetPoint("LEFT", content, "LEFT")
	castDivider:SetPoint("RIGHT", content, "RIGHT")
	castDivider:SetPoint("TOP", ccModeLabel, "BOTTOM", 0, -verticalSpacing * 2.5)

	local castBarChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Enabled"],
		Tooltip = L["Announce enemy spell casts via TTS."],
		GetValue = function() return GetZone().CastBar end,
		SetValue = function(value)
			GetZone().CastBar = value
			M:Apply()
		end,
	})
	castBarChk:SetPoint("TOPLEFT", castDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	-- CastBar range dropdown (Target Only / All Enemies)
	local castRangeLabel = mini:TextLine({
		Parent = content,
		Text = L["CastBar Range"],
		Tooltip = L["Choose which enemies' casts to announce."],
	})
	castRangeLabel:SetPoint("TOPLEFT", castBarChk, "BOTTOMLEFT", 0, -verticalSpacing)

	local castRangeItems = { "TargetOnly", "All" }
	local castRangeDropdown = mini:Dropdown({
		Parent = content,
		Items = castRangeItems,
		Width = 160,
		GetValue = function()
			return GetZone().CastBarTargetOnly ~= false and "TargetOnly" or "All"
		end,
		SetValue = function(value)
			GetZone().CastBarTargetOnly = (value == "TargetOnly")
			M:Apply()
		end,
		GetText = function(value)
			if value == "TargetOnly" then return L["Target Only"]
			else return L["All Enemies"]
			end
		end,
	})
	castRangeDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	castRangeDropdown:SetPoint("TOP", castRangeLabel, "TOP", 0, 8)
	castRangeDropdown:SetWidth(160)

	-- ==================== Section 4: Interrupt Alert ====================
	local interruptDivider = mini:Divider({
		Parent = content,
		Text = L["Interrupt Section"],
	})
	interruptDivider:SetPoint("LEFT", content, "LEFT")
	interruptDivider:SetPoint("RIGHT", content, "RIGHT")
	interruptDivider:SetPoint("TOP", castRangeLabel, "BOTTOM", 0, -verticalSpacing * 2.5)

	local interruptChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Enabled"],
		Tooltip = L["Announce via TTS when you successfully interrupt an enemy cast."],
		GetValue = function() return GetZone().InterruptAlert end,
		SetValue = function(value)
			GetZone().InterruptAlert = value
			M:Apply()
		end,
	})
	interruptChk:SetPoint("TOPLEFT", interruptDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local lastElement = interruptChk

	-- ==================== Section 5: Healer CC (Arena and BattleGrounds) ====================
	if zoneKey == "Arena" or zoneKey == "BattleGrounds" then
		local healerCCDivider = mini:Divider({
			Parent = content,
			Text = L["Healer CC Section"],
		})
		healerCCDivider:SetPoint("LEFT", content, "LEFT")
		healerCCDivider:SetPoint("RIGHT", content, "RIGHT")
		healerCCDivider:SetPoint("TOP", lastElement, "BOTTOM", 0, -verticalSpacing * 1.5)

		local healerCCChk = mini:Checkbox({
			Parent = content,
			LabelText = L["Enabled"],
			Tooltip = L["Announce via TTS when the enemy healer is crowd controlled."],
			GetValue = function() return GetZone().HealerCC end,
			SetValue = function(value)
				GetZone().HealerCC = value
				M:Apply()
			end,
		})
		healerCCChk:SetPoint("TOPLEFT", healerCCDivider, "BOTTOMLEFT", 0, -verticalSpacing)

		-- Mode: TTS or Sound File
		local healerCCModeLabel = mini:TextLine({
			Parent = content,
			Text = L["Healer CC Mode"],
		})
		healerCCModeLabel:SetPoint("TOPLEFT", healerCCChk, "BOTTOMLEFT", 0, -verticalSpacing)

		local healerCCModeItems = { "TTS", "Sound" }
		local healerCCModeDropdown = mini:Dropdown({
			Parent = content,
			Items = healerCCModeItems,
			Width = 160,
			GetValue = function()
				return GetZone().HealerCCMode or "TTS"
			end,
			SetValue = function(value)
				GetZone().HealerCCMode = value
				M:Apply()
				-- Refresh to show/hide TTS text vs sound file controls
				if content.MiniRefresh then content:MiniRefresh() end
			end,
			GetText = function(value)
				if value == "TTS" then return L["TTS Mode"]
				else return L["Sound File Mode"]
				end
			end,
		})
		healerCCModeDropdown:SetPoint("TOPLEFT", healerCCModeLabel, "BOTTOMLEFT", 0, -verticalSpacing * 0.5)
		healerCCModeDropdown:SetWidth(160)

		-- TTS text input (shown when mode == TTS)
		local healerCCTextLabel = mini:TextLine({
			Parent = content,
			Text = L["Healer CC TTS Text"],
			Tooltip = L["The text to speak when enemy healer is CCed."],
		})
		healerCCTextLabel:SetPoint("TOPLEFT", healerCCModeDropdown, "BOTTOMLEFT", 0, -verticalSpacing)

		local healerCCTextBox = mini:EditBox({
			Parent = content,
			Width = 200,
			GetValue = function()
				return GetZone().HealerCCText or "治疗被控"
			end,
			SetValue = function(value)
				GetZone().HealerCCText = value
				M:Apply()
			end,
		})
		healerCCTextBox:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
		healerCCTextBox:SetPoint("TOP", healerCCTextLabel, "TOP", 0, 4)

		-- Sound file dropdown (shown when mode == Sound)
		local soundFileLabel = mini:TextLine({
			Parent = content,
			Text = L["Healer CC Sound File"],
		})
		soundFileLabel:SetPoint("TOPLEFT", healerCCModeDropdown, "BOTTOMLEFT", 0, -verticalSpacing)

		local soundFileDropdown = mini:Dropdown({
			Parent = content,
			Items = soundFiles,
			Width = 200,
			GetValue = function()
				return GetZone().HealerCCSoundFile or "夏一可_控制成功.ogg"
			end,
			SetValue = function(value)
				GetZone().HealerCCSoundFile = value
				M:Apply()
			end,
			GetText = function(value)
				return value and value:gsub("%.ogg$", "") or ""
			end,
		})
		soundFileDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
		soundFileDropdown:SetPoint("TOP", soundFileLabel, "TOP", 0, 8)
		soundFileDropdown:SetWidth(200)

		-- Preview button (always visible)
		local previewBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
		previewBtn:SetSize(80, 22)
		previewBtn:SetPoint("LEFT", healerCCModeDropdown, "RIGHT", horizontalSpacing, 0)
		previewBtn:SetText(L["Preview"])
		previewBtn:SetScript("OnClick", function()
			local mode = GetZone().HealerCCMode or "TTS"
			if mode == "Sound" then
				PreviewSoundFile(GetZone().HealerCCSoundFile or "夏一可_控制成功.ogg")
			else
				local voiceId = db.TTS and db.TTS.VoiceID or 0
				local vol = db.TTS and db.TTS.Volume or 100
				local rate = db.TTS and db.TTS.SpeechRate or 0
				local text = GetZone().HealerCCText or "治疗被控"
				C_VoiceChat.SpeakText(voiceId, text, rate, vol, true)
			end
		end)

		-- Show/hide based on mode
		local function RefreshHealerCCMode()
			local mode = GetZone().HealerCCMode or "TTS"
			local isTTS = (mode == "TTS")
			healerCCTextLabel:SetShown(isTTS)
			healerCCTextBox:SetShown(isTTS)
			soundFileLabel:SetShown(not isTTS)
			soundFileDropdown:SetShown(not isTTS)
		end

		RefreshHealerCCMode()

		content.OnMiniRefresh = function()
			RefreshHealerCCMode()
		end
	end
end

-- ==================== Init ====================

function M:Init()
	local rawDb = mini:GetSavedVars()
	MigrateV1(rawDb)
	MigrateV2(rawDb)
	MigrateV3(rawDb)
	MigrateV4(rawDb)
	MigrateV5(rawDb)
	MigrateV6(rawDb)

	db = mini:GetSavedVars(dbDefaults)
	mini:CleanTable(db, dbDefaults, true, true)

	BuildVoiceList()
	AutoSelectVoice()
	BuildSoundFileList()

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
			{
				Key = "Changelog",
				Title = L["Changelog"],
				Build = function(content) BuildChangelogTab(content) end,
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
