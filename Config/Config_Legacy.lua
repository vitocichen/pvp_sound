---@type string, Addon
local addonName, addon = ...
local mini = addon.Core.Framework
local L = addon.L
local verticalSpacing = mini.VerticalSpacing
local horizontalSpacing = mini.HorizontalSpacing

---@type Db
local db

local dbDefaults = {
	Version = 10,

	-- Tracks the version whose "What's New" dialog has already been shown.
	WhatsNewVersion = false,

	TTS = {
		VoiceID = false,
		Volume = 100,
		SpeechRate = 7,
		CastMinDuration = 1.0,
		CastInterval = 0.0,
	},

	Zones = {
		World = {
			Enabled = true,
			ImportantEnabled = true,
			Important = true,
			ImportantFilterMode = "Simple",
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = true,
			CCMode = "All",
			CastBar = true,
			CastBarTargetOnly = false,
			CastBarExcludePets = false,
			InterruptAlert = true,
			InterruptMode = "All",
			InterruptExcludePets = false,
		},
		Arena = {
			Enabled = true,
			ImportantEnabled = true,
			Important = true,
			ImportantFilterMode = "Simple",
			Defensive = true,
			TargetFocusOnly = false,
			CCEnabled = true,
			CCMode = "All",
			CastBar = true,
			CastBarTargetOnly = false,
			CastBarExcludePets = true,
			InterruptAlert = true,
			InterruptMode = "Target",
			InterruptExcludePets = true,
			HealerCC = true,
			HealerCCMode = "TTS",
			HealerCCText = "治疗被控",
			HealerCCSoundFile = "夏一可_控制成功.ogg",
		},
		BattleGrounds = {
			Enabled = true,
			ImportantEnabled = true,
			Important = true,
			ImportantFilterMode = "Simple",
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = true,
			CCMode = "All",
			CastBar = true,
			CastBarTargetOnly = true,
			CastBarExcludePets = true,
			InterruptAlert = true,
			InterruptMode = "Target",
			InterruptExcludePets = true,
			HealerCC = true,
			HealerCCMode = "TTS",
			HealerCCText = "治疗被控",
			HealerCCSoundFile = "夏一可_控制成功.ogg",
		},
		PvE = {
			Enabled = true,
			ImportantEnabled = true,
			Important = true,
			ImportantFilterMode = "Simple",
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = true,
			CCMode = "Self",
			CastBar = true,
			CastBarTargetOnly = true,
			CastBarExcludePets = true,
			InterruptAlert = true,
			InterruptMode = "Target",
			InterruptExcludePets = true,
		},
	},
}

local M = addon.ConfigLegacy

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

-- Migrate v7 format to v8: update default CCMode/CastBar/PvE settings
local function MigrateV7(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 8 then return end

	if savedDb.Zones then
		-- World: CCMode -> All, CastBarTargetOnly -> false
		if savedDb.Zones.World then
			local world = savedDb.Zones.World
			if world.CCMode == "Self" or world.CCMode == "Off" then
				world.CCMode = "All"
			end
			world.CastBarTargetOnly = false
			-- Ensure CCEnabled is true
			world.CCEnabled = true
		end

		-- Arena: CCMode -> All, CastBarTargetOnly -> false, CCEnabled -> true
		if savedDb.Zones.Arena then
			local arena = savedDb.Zones.Arena
			if arena.CCMode == "Self" or arena.CCMode == "Off" then
				arena.CCMode = "All"
			end
			arena.CastBarTargetOnly = false
			arena.CCEnabled = true
		end

		-- BattleGrounds: CCMode -> All, CCEnabled -> true
		if savedDb.Zones.BattleGrounds then
			local bg = savedDb.Zones.BattleGrounds
			if bg.CCMode == "Self" or bg.CCMode == "Off" then
				bg.CCMode = "All"
			end
			bg.CCEnabled = true
		end

		-- PvE: Enabled -> true, CCEnabled -> true, CCMode -> Self (if Off)
		if savedDb.Zones.PvE then
			local pve = savedDb.Zones.PvE
			pve.Enabled = true
			pve.CCEnabled = true
			if pve.CCMode == "Off" then
				pve.CCMode = "Self"
			end
		end
	end

	savedDb.Version = 8
end

-- Migrate v8 format to v9: add CastBarExcludePets and InterruptExcludePets
local function MigrateV8(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 9 then return end

	if savedDb.Zones then
		for zoneKey, zone in pairs(savedDb.Zones) do
			-- World defaults to false (include pets/NPCs), others default to true (exclude pets)
			local defaultExclude = (zoneKey ~= "World")
			if zone.CastBarExcludePets == nil then
				zone.CastBarExcludePets = defaultExclude
			end
			if zone.InterruptExcludePets == nil then
				zone.InterruptExcludePets = defaultExclude
			end
		end
	end

	savedDb.Version = 9
end

-- Migrate to v10: add ImportantFilterMode (default Simple)
local function MigrateV9(savedDb)
	if not savedDb or not savedDb.Version or savedDb.Version >= 10 then return end

	if savedDb.Zones then
		for _, zone in pairs(savedDb.Zones) do
			if zone.ImportantFilterMode == nil then
				zone.ImportantFilterMode = "Simple"
			end
		end
	end

	savedDb.Version = 10
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
		db.TTS = { Volume = 100, SpeechRate = 7 }
	end
	if db.TTS.SpeechRate == nil then
		db.TTS.SpeechRate = 7
	end
end

local function DoTest()
	local voiceId = db.TTS and db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
	local vol = db.TTS and db.TTS.Volume or 100
	local rate = db.TTS and db.TTS.SpeechRate or 7
	C_VoiceChat.SpeakText(voiceId, "PVP Sound Test", rate, vol, true)
end

-- ==================== Build Home Tab ====================

local function BuildHomeTab(content)
	-- Introduction
	local introBlock = mini:TextBlock({
		Parent = content,
		Lines = {
			L["home_intro_1"],
			L["home_intro_tts_warning"],
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
		GridMode = true,
		GetValue = function()
			EnsureTtsOptions()
			return db.TTS.VoiceID or (C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(0)) or 0
		end,
		SetValue = function(value)
			EnsureTtsOptions()
			db.TTS.VoiceID = value
			local speechRate = db.TTS.SpeechRate or 7
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

	local voiceHint = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	voiceHint:SetText(L["Voice Recommend Hint"])
	voiceHint:SetPoint("TOPLEFT", voiceLabel, "BOTTOMLEFT", 0, -verticalSpacing * 0.5)

	local tutorialEditBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	tutorialEditBox:SetSize(280, 20)
	tutorialEditBox:SetPoint("TOPLEFT", voiceHint, "BOTTOMLEFT", 4, -verticalSpacing * 0.5)
	tutorialEditBox:SetAutoFocus(false)
	tutorialEditBox:SetText(L["Voice Tutorial URL"])
	tutorialEditBox:SetCursorPosition(0)
	tutorialEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	tutorialEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	tutorialEditBox:SetScript("OnTextChanged", function(self)
		self:SetText(L["Voice Tutorial URL"])
		self:HighlightText()
	end)

	local copyBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	copyBtn:SetSize(60, 22)
	copyBtn:SetPoint("LEFT", tutorialEditBox, "RIGHT", horizontalSpacing, 0)
	copyBtn:SetText(L["Copy"])
	copyBtn:SetScript("OnClick", function(self)
		tutorialEditBox:SetText(L["Voice Tutorial URL"])
		tutorialEditBox:HighlightText()
		tutorialEditBox:SetFocus()
		self:SetText(L["Copied"])
		C_Timer.After(1.5, function() self:SetText(L["Copy"]) end)
	end)

	-- ---- Volume divider ----
	local volumeDivider = mini:Divider({
		Parent = content,
		Text = L["TTS Volume"],
	})
	volumeDivider:SetPoint("LEFT", content, "LEFT")
	volumeDivider:SetPoint("RIGHT", content, "RIGHT")
	volumeDivider:SetPoint("TOP", tutorialEditBox, "BOTTOM", 0, -verticalSpacing * 2)

	local volumeSlider = mini:Slider({
		Parent = content,
		Min = 0,
		Max = 100,
		Width = (columnWidth * 3) - horizontalSpacing,
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
	volumeSlider.Slider:SetPoint("TOPLEFT", volumeDivider, "BOTTOMLEFT", 4, -verticalSpacing)

	-- ---- Speech Rate divider ----
	local speechRateDivider = mini:Divider({
		Parent = content,
		Text = L["TTS Speech Rate"],
	})
	speechRateDivider:SetPoint("LEFT", content, "LEFT")
	speechRateDivider:SetPoint("RIGHT", content, "RIGHT")
	speechRateDivider:SetPoint("TOP", volumeSlider.Slider, "BOTTOM", 0, -verticalSpacing * 2)

	local speechRateSlider = mini:Slider({
		Parent = content,
		Min = -10,
		Max = 10,
		Width = (columnWidth * 3) - horizontalSpacing,
		Step = 1,
		LabelText = L["TTS Speech Rate"],
		GetValue = function()
			EnsureTtsOptions()
			return db.TTS.SpeechRate or 7
		end,
		SetValue = function(v)
			local newValue = mini:ClampInt(v, -10, 10, 0)
			EnsureTtsOptions()
			if db.TTS.SpeechRate ~= newValue then
				db.TTS.SpeechRate = newValue
				M:Apply()
			end
		end,
	})
	speechRateSlider.Slider:SetPoint("TOPLEFT", speechRateDivider, "BOTTOMLEFT", 4, -verticalSpacing)

	local speechRateHint = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	speechRateHint:SetText(L["Speech Rate Recommend Hint"])
	speechRateHint:SetPoint("TOPLEFT", speechRateSlider.Slider, "BOTTOMLEFT", -4, -verticalSpacing * 1.5)

	-- ---- Cast Interval divider ----
	local castIntervalDivider = mini:Divider({
		Parent = content,
		Text = L["Cast Interval"],
	})
	castIntervalDivider:SetPoint("LEFT", content, "LEFT")
	castIntervalDivider:SetPoint("RIGHT", content, "RIGHT")
	castIntervalDivider:SetPoint("TOP", speechRateHint, "BOTTOM", 0, -verticalSpacing * 2)

	local castIntervalSlider = mini:Slider({
		Parent = content,
		Min = 0,
		Max = 5,
		Width = (columnWidth * 3) - horizontalSpacing,
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
	castIntervalSlider.Slider:SetPoint("TOPLEFT", castIntervalDivider, "BOTTOMLEFT", 4, -verticalSpacing)

	-- Test button
	local testBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	testBtn:SetSize(120, 26)
	testBtn:SetPoint("TOPLEFT", castIntervalSlider.Slider, "BOTTOMLEFT", -4, -verticalSpacing * 2)
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
			L["changelog_v3.0.7"],
			" ",
			L["changelog_v3.0.6"],
			" ",
			L["changelog_v3.0.5"],
			" ",
			L["changelog_v3.0.4"],
			" ",
			L["changelog_v3.0.3"],
			" ",
			L["changelog_v3.0.2"],
			" ",
			L["changelog_v3.0.1"],
			" ",
			L["changelog_v3.0.0"],
			" ",
			L["changelog_v2.0.3"],
			" ",
			L["changelog_v2.0.2"],
			" ",
			L["changelog_v2.0.1"],
			" ",
			L["changelog_v2.0.0"],
			" ",
			L["changelog_v1.0.12"],
			" ",
			L["changelog_v1.0.11"],
			" ",
			L["changelog_v1.0.10"],
			" ",
			L["changelog_v1.0.9"],
			" ",
			L["changelog_v1.0.8"],
			" ",
			L["changelog_v1.0.7"],
			" ",
			L["changelog_v1.0.6"],
			" ",
			L["changelog_v1.0.5"],
			" ",
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

	-- Important filter mode (Detailed / Simple)
	local importantModeLabel = mini:TextLine({
		Parent = content,
		Text = L["Important Filter Mode"],
		Tooltip = L["Choose how strictly important buffs are filtered."],
	})
	importantModeLabel:SetPoint("TOPLEFT", importantChk, "BOTTOMLEFT", 0, -verticalSpacing)

	-- "AllBuffs" (verbose, v1.0.8-style) is offered only in the World zone.
	local importantModeItems = (zoneKey == "World")
		and { "Detailed", "Simple", "AllBuffs" }
		or { "Detailed", "Simple" }
	local importantModeDropdown = mini:Dropdown({
		Parent = content,
		Items = importantModeItems,
		Width = 260,
		GetValue = function()
			return GetZone().ImportantFilterMode or "Simple"
		end,
		SetValue = function(value)
			GetZone().ImportantFilterMode = value
			M:Apply()
		end,
		GetText = function(value)
			if value == "Simple" then return L["Important Mode Simple"]
			elseif value == "AllBuffs" then return L["Important Mode AllBuffs"]
			else return L["Important Mode Detailed"]
			end
		end,
	})
	importantModeDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	importantModeDropdown:SetPoint("TOP", importantModeLabel, "TOP", 0, 8)
	importantModeDropdown:SetWidth(260)

	-- ==================== Section 2: CC Spells ====================
	local ccDivider = mini:Divider({
		Parent = content,
		Text = L["CC Spells Section"],
	})
	ccDivider:SetPoint("LEFT", content, "LEFT")
	ccDivider:SetPoint("RIGHT", content, "RIGHT")
	ccDivider:SetPoint("TOP", importantModeLabel, "BOTTOM", 0, -verticalSpacing * 2.5)

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

	local ccModeItems = { "Self", "Party", "All" }
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
			elseif value == "Party" then return L["Party Only"]
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

	local castRangeItems = { "TargetOnly", "TargetingMe", "All" }
	local castRangeDropdown = mini:Dropdown({
		Parent = content,
		Items = castRangeItems,
		Width = 160,
		GetValue = function()
			local val = GetZone().CastBarTargetOnly
			if val == "TargetingMe" then return "TargetingMe" end
			if val ~= false then return "TargetOnly" end
			return "All"
		end,
		SetValue = function(value)
			if value == "TargetingMe" then
				GetZone().CastBarTargetOnly = "TargetingMe"
			else
				GetZone().CastBarTargetOnly = (value == "TargetOnly")
			end
			M:Apply()
		end,
		GetText = function(value)
			if value == "TargetOnly" then return L["Target Only"]
			elseif value == "TargetingMe" then return L["Targeting Me"]
			else return L["All Enemies"]
			end
		end,
	})
	castRangeDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	castRangeDropdown:SetPoint("TOP", castRangeLabel, "TOP", 0, 8)
	castRangeDropdown:SetWidth(160)

	local castExcludePetsChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Exclude Pets"],
		Tooltip = L["Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts."],
		GetValue = function() return GetZone().CastBarExcludePets ~= false end,
		SetValue = function(value)
			GetZone().CastBarExcludePets = value
			M:Apply()
		end,
	})
	castExcludePetsChk:SetPoint("TOPLEFT", castRangeLabel, "BOTTOMLEFT", 0, -verticalSpacing)

	-- ==================== Section 4: Interrupt Alert ====================
	local interruptDivider = mini:Divider({
		Parent = content,
		Text = L["Interrupt Section"],
	})
	interruptDivider:SetPoint("LEFT", content, "LEFT")
	interruptDivider:SetPoint("RIGHT", content, "RIGHT")
	interruptDivider:SetPoint("TOP", castExcludePetsChk, "BOTTOM", 0, -verticalSpacing * 2.5)

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

	-- Interrupt Range dropdown
	local interruptRangeLabel = mini:TextLine({
		Parent = content,
		Text = L["Interrupt Range"],
	})
	interruptRangeLabel:SetPoint("TOPLEFT", interruptChk, "BOTTOMLEFT", 0, -verticalSpacing)

	local interruptRangeItems = { "Target", "TargetFocus", "All" }
	local interruptRangeDropdown = mini:Dropdown({
		Parent = content,
		Items = interruptRangeItems,
		Width = 160,
		GetValue = function()
			return GetZone().InterruptMode or "Target"
		end,
		SetValue = function(value)
			GetZone().InterruptMode = value
			M:Apply()
		end,
		GetText = function(value)
			if value == "Target" then return L["Target Only"]
			elseif value == "TargetFocus" then return L["Target + Focus"]
			else return L["All Enemies"]
			end
		end,
	})
	interruptRangeDropdown:SetPoint("LEFT", content, "LEFT", columnWidth, 0)
	interruptRangeDropdown:SetPoint("TOP", interruptRangeLabel, "TOP", 0, 8)
	interruptRangeDropdown:SetWidth(160)

	local interruptExcludePetsChk = mini:Checkbox({
		Parent = content,
		LabelText = L["Exclude Pets"],
		Tooltip = L["Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts."],
		GetValue = function() return GetZone().InterruptExcludePets ~= false end,
		SetValue = function(value)
			GetZone().InterruptExcludePets = value
			M:Apply()
		end,
	})
	interruptExcludePetsChk:SetPoint("TOPLEFT", interruptRangeLabel, "BOTTOMLEFT", 0, -verticalSpacing)

	local lastElement = interruptExcludePetsChk

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
				local rate = db.TTS and db.TTS.SpeechRate or 7
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


-- If DB was upgraded on a 12.1+ client (modern schema), rebuild a usable main/legacy profile.
local function DowngradeFromModernSchema(savedDb)
	if not savedDb then return end
	if not savedDb.Version or savedDb.Version < 12 then return end
	if savedDb.TTS then return end

	local zoneEnabled = {}
	if type(savedDb.Zones) == "table" then
		for key, zone in pairs(savedDb.Zones) do
			if type(zone) == "table" then
				zoneEnabled[key] = zone.Enabled ~= false
			end
		end
	end

	savedDb.TTS = {
		VoiceID = false,
		Volume = 100,
		SpeechRate = 7,
		CastMinDuration = 1.0,
		CastInterval = (savedDb.Sound and savedDb.Sound.CastInterval) or 0.0,
	}
	savedDb.Sound = nil
	savedDb.VoicePack = nil
	savedDb.ExtraVoicePacks = nil
	savedDb.Spells = nil
	savedDb.SelfCcSpells = nil

	local function Zone(enabled, extra)
		local z = {
			Enabled = enabled ~= false,
			ImportantEnabled = enabled ~= false,
			Important = true,
			ImportantFilterMode = "Simple",
			Defensive = true,
			TargetFocusOnly = true,
			CCEnabled = true,
			CCMode = "All",
			CastBar = true,
			CastBarTargetOnly = false,
			CastBarExcludePets = false,
			InterruptAlert = true,
			InterruptMode = "All",
			InterruptExcludePets = false,
		}
		if extra then
			for k, v in pairs(extra) do z[k] = v end
		end
		return z
	end

	savedDb.Zones = {
		World = Zone(zoneEnabled.World, {
			TargetFocusOnly = true,
			ImportantFilterMode = "Simple",
			CastBarExcludePets = false,
			InterruptExcludePets = false,
		}),
		Arena = Zone(zoneEnabled.Arena, {
			TargetFocusOnly = false,
			CastBarExcludePets = true,
			InterruptExcludePets = true,
			InterruptMode = "Target",
			HealerCC = true,
			HealerCCMode = "TTS",
			HealerCCText = "治疗被控",
			HealerCCSoundFile = "夏一可_控制成功.ogg",
		}),
		BattleGrounds = Zone(zoneEnabled.BattleGrounds, {
			TargetFocusOnly = true,
			CastBarExcludePets = true,
			InterruptExcludePets = true,
			InterruptMode = "Target",
			CastBarTargetOnly = true,
			HealerCC = true,
			HealerCCMode = "TTS",
			HealerCCText = "治疗被控",
			HealerCCSoundFile = "夏一可_控制成功.ogg",
		}),
		PvE = Zone(false, {
			ImportantEnabled = false,
			CCEnabled = false,
			CastBar = false,
			InterruptAlert = false,
		}),
	}
	savedDb.Version = 10
end

local function ApplyLegacyLocaleOverrides()
	local L = addon.L
	if not L or not L.SetStrings then return end
	if GetLocale() == "zhCN" then
		L:SetStrings({
			["addon_description"] = "一款PVP语音播报插件，可以播报PVP战斗中的重要技能、防御技能、控制技能、读条监控和打断提醒等。",
			["Author: DK-姜世离（燃烧之刃）"] = "作者：DK-姜世离（燃烧之刃）",
			["General"] = "常规",
			["home_intro_1"] = "PVP Sound 实时监控敌方增益/减益/施法/被控制效果，通过TTS语音播报PvP中的重要技能。",
			["home_intro_tts_warning"] = "|cFFFF2020注：请关闭系统/其他插件的语音播报，否则会造成重复和延时！！！|r",
			["home_intro_2"] = "支持六种播报类型：",
			["home_intro_3"] = "|cFF00FF00重要法术|r — 进攻性技能，如复仇之怒、自由之手、操控时间等。",
			["home_intro_4"] = "|cFF00BFFF防御法术|r — 防御性技能，如保护之手、暗影斗篷、无敌、冰箱等。",
			["home_intro_5"] = "|cFFFF6060友方被控|r — 施加在你或队友身上的控制技能（窒息、制裁、变羊、闷棍等）。",
			["home_intro_5b"] = "|cFFFFD100读条监控|r — 实时播报敌方施法/引导技能名称。",
			["home_intro_5c"] = "|cFFFFA500打断提醒|r — 当目标施法停止时播报打断成功。",
			["home_intro_5d"] = "|cFFFF69B4治疗被控|r — 当治疗被控时候播放提示音效。",
			["home_intro_6"] = "每种区域（野外、竞技场、战场、PvE）都有独立的设置 — 请在上方的标签页中分别配置。",
			["home_intro_7"] = "输入 |cFFFFD100/pvpsound|r 或 |cFFFFD100/ps|r 打开设置面板，|cFFFFD100/ps test|r 可测试TTS语音输出。",
			["Reset"] = "重置",
			["Are you sure you wish to reset to factory settings?"] = "您确定要重置为出厂设置吗？",
			["Settings reset to default."] = "设置已重置为默认值。",
			["Can't do that during combat."] = "战斗中无法执行该操作。",
			["Test"] = "测试",
			["TTS Settings"] = "TTS语音设置",
			["Voice"] = "语音",
			["You must choose a voice in your language for this to work."] = "必须选择与你的语言匹配的语音才能使其生效。",
			["TTS Volume"] = "TTS音量",
			["TTS Speech Rate"] = "TTS语速",
			["Voice Recommend Hint"] = "|cFFFFD100推荐 Xiaoxiao（实测 Huihui 会有播放乱序和延迟的BUG），教程如下：|r",
			["Voice Tutorial URL"] = "nga.178.com/read.php?tid=45648904",
			["Copy"] = "复制",
			["Copied"] = "已复制",
			["Speech Rate Recommend Hint"] = "|cFFFFD100推荐 Huihui 最低7，Xiaoxiao 最低5，否则会延迟播报|r",
			["Cast Interval"] = "读条播报间隔",
			["World"] = "野外",
			["Arena"] = "竞技场",
			["Battlegrounds"] = "战场",
			["PvE"] = "PvE",
			["Enabled"] = "启用",
			["Enabled (Master)"] = "启用（总开关）",
			["Master switch: enable all announcements in this zone."] = "总开关：在此区域中启用所有语音播报。",
			["Enable announcements in this zone."] = "在此区域中启用语音播报。",
			["Important Spells Section"] = "重要技能语音",
			["Enable important and defensive spell announcements."] = "启用重要进攻技能和防御技能的语音播报。",
			["Important Monitor Range"] = "监控范围 |cFF00BFFF（建议选仅目标/焦点）|r",
			["Target/Focus Only Short"] = "仅目标/焦点",
			["Important Spells"] = "重要法术（进攻技能）",
			["Announce important (offensive) spell names via TTS when enemies cast them."] = "当敌人施放重要进攻技能时，用TTS语音播报技能名称。",
			["Defensive Spells"] = "防御法术",
			["Announce defensive spell names via TTS when enemies cast them."] = "当敌人施放防御技能时，用TTS语音播报技能名称。",
			["Only monitor your target and focus instead of all enemy nameplates."] = "仅监控你的目标和焦点，而不是所有敌方姓名板。",
			["Important Filter Mode"] = "重要法术过滤",
			["Choose how strictly important buffs are filtered."] = "选择重要法术的过滤严格程度。",
			["Important Mode Detailed"] = "详细版（含自由祝福，可能多回春/智力等）",
			["Important Mode Simple"] = "简易版（过滤可驱散非减伤，同MiniCC）",
			["Important Mode AllBuffs"] = "全部增益（全部buff播放，推荐插旗环境使用）",
			["CC Spells Section"] = "控制技能语音",
			["Enable CC spell announcements."] = "启用控制技能语音播报。",
			["CC Mode"] = "播报范围",
			["Announce CC on self or party via TTS."] = "当你或队友被控制时用TTS语音播报控制技能名称。",
			["Self Only"] = "仅自己",
			["Party Only"] = "仅队友",
			["Self + Party"] = "自己+队友",
			["CastBar Section"] = "读条监控",
			["Announce enemy spell casts via TTS."] = "用TTS语音播报敌方施法。",
			["CastBar Range"] = "监控范围",
			["Choose which enemies' casts to announce."] = "选择播报哪些敌人的施法。",
			["Target Only"] = "仅目标",
			["Targeting Me"] = "仅对我施放",
			["All Enemies"] = "所有敌人",
			["Exclude Pets"] = "排除宠物",
			["Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts."] = "排除宠物和守护者的施法（如水元素），仅播报玩家施法。",
			["Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts."] = "排除宠物和守护者的打断（如水元素），仅播报玩家打断。",
			["Interrupt Section"] = "打断监控 |cFF00BFFF（只能判断目标施法是否停止，无法区分被打断还是自行取消）|r",
			["Announce via TTS when you successfully interrupt an enemy cast."] = "当目标被打断或停止施法时播报。",
			["Interrupted"] = "打断成功",
			["Interrupt Range"] = "监控范围",
			["Choose which enemies' interrupts to announce."] = "选择监控哪些敌人的施法中断。",
			["Target + Focus"] = "目标+焦点",
			["Healer CC Section"] = "治疗被控语音",
			["Announce via TTS when the enemy healer is crowd controlled."] = "当友方治疗被控制时，用TTS语音播报。",
			["Healer CC Mode"] = "播报方式",
			["TTS Mode"] = "TTS语音",
			["Sound File Mode"] = "自定义音效",
			["Healer CC TTS Text"] = "TTS播报文本",
			["The text to speak when enemy healer is CCed."] = "当友方治疗被控制时播报的文本。",
			["Healer CC Sound File"] = "音效文件",
			["Preview"] = "试听",
			["Changelog"] = "更新记录",
			["PVP Sound - What's New?"] = "PVP Sound — 更新内容",
			["Auto-enable Enemy Buffs"] = "自动开启姓名板「敌方增益」",
			["Auto-enable Enemy Buffs Tooltip"] = "进攻播报依赖系统姓名板的「敌方增益」显示。开启后插件会在登录/进场时自动把它打开（BetterBlizzPlates 等插件常会关掉它）。关闭本项则不再自动设置，需要你自己在暴雪界面里开启。",
			["changelog_v1.0.0"] = "|cFFFFD100v1.0.0|r — 初版本发布。",
			["changelog_v1.0.1"] = "|cFFFFD100v1.0.1|r — 新增野外/竞技场/战场/PvE场景区分。",
			["changelog_v1.0.2"] = "|cFFFFD100v1.0.2|r — 新增读条和打断监控。",
			["changelog_v1.0.3"] = "|cFFFFD100v1.0.3|r — 新增治疗被控监控。",
			["changelog_v1.0.5"] = "|cFFFFD100v1.0.5|r — 修复了读条重复播放的问题，新增多目标的打断成功监控。",
			["changelog_v2.0.3"] = "|cFFFFD100v2.0.3|r — 野外新增「全部增益」模式，如暗影步/君王/腥红之瓶均能播放，但是也会伴随诸多无用 buff，适用于插旗单人 PK。",
			["changelog_v2.0.2"] = "|cFFFFD100v2.0.2|r — 简易版重要法术播报已与 MiniCC 保持一致；新增 1 秒播报间隔，一定程度修复了愈合导言的频繁播放。",
			["changelog_v2.0.1"] = "|cFFFFD100v2.0.1|r — 重要法术新增「详细版/简易版」过滤模式：详细版含自由祝福（可能多回春/智力等），简易版过滤可驱散非减伤 buff（同 MiniCC）。",
			["changelog_v2.0.0"] = "|cFFFFD100v2.0.0|r — 现在重要法术播放已经实现，可以只播放重要的进攻技能，忽略常驻buff和不必要的buff。",
			["changelog_v1.0.13"] = "|cFFFFD100v1.0.13|r — 进攻播报改为读取姓名板内部的「重要增益」数据列表（与 Platynator 相同方式），不再依赖屏幕上的增益图标，也不再强制修改暴雪「敌方增益」设置。耐力/智力等无用常驻增益不会再被播报。",
			["changelog_v1.0.12"] = "|cFFFFD100v1.0.12|r — 升级被控语音模块，添加了仅队友选项，支持只播放队友的控制技能，适用于治疗职业。",
			["changelog_v1.0.11"] = "|cFFFFD100v1.0.11|r — 修复与 BetterBlizzPlates 等姓名板插件冲突：它们常会关掉系统的「敌方增益」显示，导致进攻播报失效。现在插件会在登录/进场时自动开启该显示（位域 nameplateEnemyPlayerAuraDisplay 的 Buffs 位）。可在设置里「自动开启姓名板敌方增益」关闭此行为。",
			["changelog_v1.0.10"] = "|cFFFFD100v1.0.10|r — 修复：①重要技能偶尔不播报（如法师镜像首次施放）——改用光环「新增事件」判定是否为新 buff，免疫光环编号复用与图标渲染时序问题，并加补扫兜底；②常驻增益（如德鲁伊全能）被姓名板2格上限挤出后回归时被重复播报（身上已有的 buff 一律视为旧的、永不播报，只播报你监视期间新出现的）；③读条/打断的「排除宠物」现在也能正确排除法师镜像、术士宝宝等守护者类单位，且即使你把它们设为目标也不会播报。",
			["changelog_v1.0.9"] = "|cFFFFD100v1.0.9|r — 适配12.0.7：暴雪移除了「重要」技能名单，进攻类无法再用光环数据精准识别。改为直接读取暴雪姓名板「敌方增益」已经精选好的 buff 图标来播报进攻技能，效果与系统姓名板一致；防御/控制播报不受影响。\n\n|cffff3030【必读】进攻播报依赖系统姓名板，请在暴雪原版界面设置里：①开启「显示敌方姓名板」（按 V 或在「界面-姓名板」里勾选）；②把姓名板的「敌方增益」勾上。否则进攻技能不会播报！|r",
			["changelog_v1.0.8"] = "|cFFFFD100v1.0.8|r — 真实目标施法监控仅支持检测「目标是我」的施法，焦点/鼠标指向施法受API限制无法实现过滤。",
			["changelog_v1.0.7"] = "|cFFFFD100v1.0.7|r — TTS语速调节范围扩大至-10~10，推荐Xiaoxiao最低5，Huihui最低7，否则会延时播报。",
			["changelog_v1.0.6"] = "|cFFFFD100v1.0.6|r — 新增读条/打断的「排除宠物」选项；适配Mac语音选择多列布局。",
			["changelog_v1.0.4"] = "|cFFFFD100v1.0.4|r — 修复了技能会重复播放的问题。",
			["Donate"] = "打赏支持",
			["Donate Popup Title"] = "打赏支持",
			["Donate Popup Hint"] = "复制链接，在浏览器中打开即可扫码打赏：",
			["Donate Open Hint"] = "|cFF888888打不开？请尝试使用浏览器直接访问上方网址|r",
			["Important"] = "重要",
			["Defensive"] = "防御",
			["Notification"] = "通知",
		})
	else
		L:SetStrings({
			["addon_description"] = "A PvP TTS addon that announces important spells, defensive cooldowns, crowd control, enemy cast bars, and interrupt alerts during PvP combat.",
			["Author: DK-姜世离（燃烧之刃）"] = "Author: DK-姜世离（燃烧之刃）",
			["General"] = "General",
			["home_intro_1"] = "PVP Sound monitors enemy buffs/debuffs, casts, and CC effects, using Text-to-Speech (TTS) to announce important PvP spells in real time.",
			["home_intro_tts_warning"] = "|cFFFF2020NOTE: Please disable system/other addon voice alerts, otherwise it will cause duplicate and delay!!!|r",
			["home_intro_2"] = "It supports six announcement categories:",
			["home_intro_3"] = "|cFF00FF00Important Spells|r - Offensive abilities such as Avenging Wrath, Blessing of Freedom, Alter Time, etc.",
			["home_intro_4"] = "|cFF00BFFFDefensive Spells|r - Defensive cooldowns such as Blessing of Protection, Cloak of Shadows, Divine Shield, Ice Block, etc.",
			["home_intro_5"] = "|cFFFF6060Friendly CC|r - Crowd control effects applied to you or your party (Asphyxiate, Hammer of Justice, Polymorph, Sap, etc.).",
			["home_intro_5b"] = "|cFFFFD100Cast Bar|r - Announces enemy spell casts and channels in real time.",
			["home_intro_5c"] = "|cFFFFA500Interrupt Alert|r - Announces when your target's cast is stopped.",
			["home_intro_5d"] = "|cFFFF69B4Healer CC|r - Plays an alert sound when the healer is crowd controlled.",
			["home_intro_6"] = "Each zone type (World, Arena, Battlegrounds, PvE) has independent settings — configure them in the tabs above.",
			["home_intro_7"] = "Use |cFFFFD100/pvpsound|r or |cFFFFD100/ps|r to open this panel, or |cFFFFD100/ps test|r to test TTS output.",
			["Reset"] = "Reset",
			["Are you sure you wish to reset to factory settings?"] = "Are you sure you wish to reset to factory settings?",
			["Settings reset to default."] = "Settings reset to default.",
			["Can't do that during combat."] = "Can't do that during combat.",
			["Test"] = "Test",
			["TTS Settings"] = "TTS Settings",
			["Voice"] = "Voice",
			["You must choose a voice in your language for this to work."] = "You must choose a voice in your language for this to work.",
			["TTS Volume"] = "TTS Volume",
			["TTS Speech Rate"] = "TTS Speech Rate",
			["Voice Recommend Hint"] = "|cFFFFD100Recommend: Xiaoxiao (Huihui has playback order and delay bugs). Tutorial:|r",
			["Voice Tutorial URL"] = "nga.178.com/read.php?tid=45648904",
			["Copy"] = "Copy",
			["Copied"] = "Copied",
			["Speech Rate Recommend Hint"] = "|cFFFFD100Recommend: Huihui min 7, Xiaoxiao min 5, or TTS may be delayed|r",
			["Cast Interval"] = "Cast Interval",
			["World"] = "World",
			["Arena"] = "Arena",
			["Battlegrounds"] = "Battlegrounds",
			["PvE"] = "PvE",
			["Enabled"] = "Enabled",
			["Enabled (Master)"] = "Enabled (Master Switch)",
			["Master switch: enable all announcements in this zone."] = "Master switch: enable all announcements in this zone.",
			["Enable announcements in this zone."] = "Enable announcements in this zone.",
			["Important Spells Section"] = "Important Spells",
			["Enable important and defensive spell announcements."] = "Enable important and defensive spell announcements.",
			["Important Monitor Range"] = "Monitor Range |cFF00BFFF(Recommend: Target/Focus)|r",
			["Target/Focus Only Short"] = "Target/Focus Only",
			["Important Spells"] = "Important Spells",
			["Announce important (offensive) spell names via TTS when enemies cast them."] = "Announce important (offensive) spell names via TTS when enemies cast them.",
			["Defensive Spells"] = "Defensive Spells",
			["Announce defensive spell names via TTS when enemies cast them."] = "Announce defensive spell names via TTS when enemies cast them.",
			["Only monitor your target and focus instead of all enemy nameplates."] = "Only monitor your target and focus instead of all enemy nameplates.",
			["Important Filter Mode"] = "Important Filter Mode",
			["Choose how strictly important buffs are filtered."] = "Choose how strictly important buffs are filtered.",
			["Important Mode Detailed"] = "Detailed (incl. Blessing of Freedom, may add Rejuv/Intellect etc.)",
			["Important Mode Simple"] = "Simple (filters purgeable non-defensive, like MiniCC)",
			["Important Mode AllBuffs"] = "All Buffs (World only, announces every new buff, for duels)",
			["CC Spells Section"] = "CC Spells",
			["Enable CC spell announcements."] = "Enable CC spell announcements.",
			["CC Mode"] = "Mode",
			["Announce CC on self or party via TTS."] = "Announce CC on self or party via TTS.",
			["Self Only"] = "Self Only",
			["Party Only"] = "Party Only",
			["Self + Party"] = "Self + Party",
			["CastBar Section"] = "Cast Bar",
			["Announce enemy spell casts via TTS."] = "Announce enemy spell casts via TTS.",
			["CastBar Range"] = "Range",
			["Choose which enemies' casts to announce."] = "Choose which enemies' casts to announce.",
			["Target Only"] = "Target Only",
			["Targeting Me"] = "Targeting Me",
			["All Enemies"] = "All Enemies",
			["Exclude Pets"] = "Exclude Pets",
			["Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts."] = "Exclude pet and guardian casts (e.g. Water Elemental). Only announce player casts.",
			["Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts."] = "Exclude pet and guardian interrupts (e.g. Water Elemental). Only announce player interrupts.",
			["Interrupt Section"] = "Interrupt Alert |cFF00BFFF(Detects cast stop only, not actual interrupt)|r",
			["Announce via TTS when you successfully interrupt an enemy cast."] = "Announces when your target is interrupted or stops casting.",
			["Interrupted"] = "Interrupted",
			["Interrupt Range"] = "Range",
			["Choose which enemies' interrupts to announce."] = "Choose which enemies' interrupts to announce.",
			["Target + Focus"] = "Target + Focus",
			["Healer CC Section"] = "Healer CC",
			["Announce via TTS when the enemy healer is crowd controlled."] = "Announce via TTS when the friendly healer is crowd controlled.",
			["Healer CC Mode"] = "Alert Mode",
			["TTS Mode"] = "TTS Voice",
			["Sound File Mode"] = "Sound File",
			["Healer CC TTS Text"] = "TTS Text",
			["The text to speak when enemy healer is CCed."] = "The text to speak when the friendly healer is CCed.",
			["Healer CC Sound File"] = "Sound File",
			["Preview"] = "Preview",
			["Changelog"] = "Changelog",
			["PVP Sound - What's New?"] = "PVP Sound - What's New?",
			["Auto-enable Enemy Buffs"] = "Auto-enable nameplate 'Enemy Buffs'",
			["Auto-enable Enemy Buffs Tooltip"] = "Offensive announcements rely on Blizzard's nameplate 'Enemy Buffs' display. When enabled, the addon turns it on automatically at login/zone-in (other nameplate addons like BetterBlizzPlates often turn it off). Disable this to stop auto-setting it and manage it yourself in the Blizzard options.",
			["changelog_v1.0.0"] = "|cFFFFD100v1.0.0|r — Initial release.",
			["changelog_v1.0.1"] = "|cFFFFD100v1.0.1|r — Added World / Arena / Battlegrounds / PvE zone detection.",
			["changelog_v1.0.2"] = "|cFFFFD100v1.0.2|r — Added Cast Bar and Interrupt monitoring.",
			["changelog_v1.0.3"] = "|cFFFFD100v1.0.3|r — Added Healer CC monitoring.",
			["changelog_v1.0.5"] = "|cFFFFD100v1.0.5|r — Fixed cast bar duplicate announcements; added multi-target interrupt alert monitoring.",
			["changelog_v2.0.3"] = "|cFFFFD100v2.0.3|r — New \"All Buffs\" mode for the World zone: announces skills like Shadowstep / Sovereign / Crimson Vial, but also many useless buffs — best for open-world 1v1 duels.",
			["changelog_v2.0.2"] = "|cFFFFD100v2.0.2|r — Simple mode for important spells now matches MiniCC. Added a 1-second announcement gap to reduce Prayer of Mending spam.",
			["changelog_v2.0.1"] = "|cFFFFD100v2.0.1|r — Added Detailed/Simple filter modes for important spells: Detailed includes Blessing of Freedom (may also announce Rejuv/Intellect etc.); Simple filters purgeable non-defensive buffs (like MiniCC).",
			["changelog_v2.0.0"] = "|cFFFFD100v2.0.0|r — Important spell playback is now implemented, only playing important offensive skills and ignoring permanent/unnecessary buffs.",
			["changelog_v1.0.13"] = "|cFFFFD100v1.0.13|r — Offensive announcements now read the nameplate's internal important-buff data list (same approach as Platynator), not on-screen buff icons. No more auto-forcing Blizzard's 'Enemy Buffs' CVar. Stamina/intel and other junk permanent buffs are no longer announced.",
			["changelog_v1.0.12"] = "|cFFFFD100v1.0.12|r — CC voice module update: added 'Party Only' mode—announce teammates' crowd control without announcing your own. Ideal for healers.",
			["changelog_v1.0.11"] = "|cFFFFD100v1.0.11|r — Fixes a conflict with nameplate addons like BetterBlizzPlates, which often turn off Blizzard's 'Enemy Buffs' nameplate display and thereby break offensive announcements. The addon now auto-enables that display at login/zone-in (the Buffs bit of the nameplateEnemyPlayerAuraDisplay bitfield). Toggle it off via the 'Auto-enable nameplate Enemy Buffs' option.",
			["changelog_v1.0.10"] = "|cFFFFD100v1.0.10|r — Fixes: (1) an important spell sometimes wasn't announced (e.g. a Mage's first Mirror Image) - new buffs are now detected from UNIT_AURA added-aura events, which is immune to auraInstanceID reuse and icon render timing, plus a catch-up scan; (2) a persistent buff (e.g. a Druid's versatility buff) was re-announced when Blizzard's 2-slot nameplate cap cycled it back into view (anything the enemy already had is treated as old and never announced; only buffs gained while you're watching are announced); (3) the Cast Bar / Interrupt 'Exclude Pets' option now also excludes guardians like Mage Mirror Images and Warlock minions, and keeps ignoring them even when you target them.",
			["changelog_v1.0.9"] = "|cFFFFD100v1.0.9|r — 12.0.7 fix: Blizzard removed the IMPORTANT spell whitelist, so offensive buffs can no longer be identified from aura data. Important announcements now read the buff icons Blizzard already curates onto the enemy nameplate, matching the default UI exactly. Defensive/CC announcements are unaffected.\n\n|cffff3030[REQUIRED] Important announcements rely on the default nameplates: in Blizzard's UI options, (1) enable showing enemy nameplates (press V, or check it under Interface > Nameplates), and (2) enable the nameplate 'Enemy Buffs' option. Otherwise offensive spells won't be announced!|r",
			["changelog_v1.0.8"] = "|cFFFFD100v1.0.8|r — Real-target cast detection only supports 'targeting me' casts; focus/mouseover cast filtering is not possible due to API limitations.",
			["changelog_v1.0.7"] = "|cFFFFD100v1.0.7|r — Expanded TTS speech rate range to -10~10. Recommend Xiaoxiao min 5, Huihui min 7, or TTS may be delayed.",
			["changelog_v1.0.6"] = "|cFFFFD100v1.0.6|r — Added 'Exclude Pets' option for Cast Bar and Interrupt; adapted voice dropdown layout for Mac.",
			["changelog_v1.0.4"] = "|cFFFFD100v1.0.4|r — Fixed an issue where spell announcements could be played repeatedly.",
			["Donate"] = "Donate",
			["Donate Popup Title"] = "Support PVP Sound",
			["Donate Popup Hint"] = "Copy the link and open in your browser to donate:",
			["Donate Open Hint"] = "|cFF888888Can't open? Try visiting the URL above in your browser|r",
			["Important"] = "Important",
			["Defensive"] = "Defensive",
			["Notification"] = "Notification",
		})
	end
end

function M:Init()
	local rawDb = mini:GetSavedVars()
	DowngradeFromModernSchema(rawDb)
	ApplyLegacyLocaleOverrides()
	MigrateV1(rawDb)
	MigrateV2(rawDb)
	MigrateV3(rawDb)
	MigrateV4(rawDb)
	MigrateV5(rawDb)
	MigrateV6(rawDb)
	MigrateV7(rawDb)
	MigrateV8(rawDb)
	MigrateV9(rawDb)

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

	local descBlock = mini:TextBlock({
		Parent = panel,
		Lines = {
			L["addon_description"],
		},
	})
	descBlock:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local authorLine = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	authorLine:SetText(L["Author: DK-姜世离（燃烧之刃）"])
	authorLine:SetPoint("TOPLEFT", descBlock, "BOTTOMLEFT", 0, -verticalSpacing)

	-- ==================== Donate button ====================
	local donateBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	donateBtn:SetSize(80, 22)
	donateBtn:SetPoint("LEFT", authorLine, "RIGHT", horizontalSpacing, 2)
	donateBtn:SetText(L["Donate"])

	local donatePopup = CreateFrame("Frame", "PVPSoundDonatePopup", UIParent, "BasicFrameTemplateWithInset")
	donatePopup:SetSize(440, 140)
	donatePopup:SetPoint("CENTER")
	donatePopup:SetFrameStrata("DIALOG")
	donatePopup:EnableMouse(true)
	donatePopup:SetMovable(true)
	donatePopup:RegisterForDrag("LeftButton")
	donatePopup:SetScript("OnDragStart", donatePopup.StartMoving)
	donatePopup:SetScript("OnDragStop", donatePopup.StopMovingOrSizing)
	donatePopup:Hide()
	donatePopup.TitleText:SetText(L["Donate Popup Title"])

	local donateHint = donatePopup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	donateHint:SetText(L["Donate Popup Hint"])
	donateHint:SetPoint("TOP", donatePopup, "TOP", 0, -32)

	local donateURL = "https://vitocichen.github.io/DK-jiangshili/"
	local donateEditBox = CreateFrame("EditBox", nil, donatePopup, "InputBoxTemplate")
	donateEditBox:SetSize(300, 20)
	donateEditBox:SetPoint("TOP", donateHint, "BOTTOM", -20, -12)
	donateEditBox:SetAutoFocus(false)
	donateEditBox:SetText(donateURL)
	donateEditBox:SetCursorPosition(0)
	donateEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	donateEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	donateEditBox:SetScript("OnTextChanged", function(self)
		self:SetText(donateURL)
		self:HighlightText()
	end)

	local donateCopyBtn = CreateFrame("Button", nil, donatePopup, "UIPanelButtonTemplate")
	donateCopyBtn:SetSize(60, 22)
	donateCopyBtn:SetPoint("LEFT", donateEditBox, "RIGHT", 8, 0)
	donateCopyBtn:SetText(L["Copy"])
	donateCopyBtn:SetScript("OnClick", function(self)
		donateEditBox:SetText(donateURL)
		donateEditBox:HighlightText()
		donateEditBox:SetFocus()
		self:SetText(L["Copied"])
		C_Timer.After(1.5, function() self:SetText(L["Copy"]) end)
	end)

	local donateOpenHint = donatePopup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	donateOpenHint:SetText(L["Donate Open Hint"])
	donateOpenHint:SetPoint("TOP", donateEditBox, "BOTTOM", -20, -8)

	donateBtn:SetScript("OnClick", function()
		if donatePopup:IsShown() then
			donatePopup:Hide()
		else
			donatePopup:Show()
			donateEditBox:SetText(donateURL)
			donateEditBox:SetCursorPosition(0)
		end
	end)

	-- ==================== Tabs ====================
	local tabsPanel = CreateFrame("Frame", nil, panel)
	tabsPanel:SetPoint("TOPLEFT", authorLine, "BOTTOMLEFT", 0, -verticalSpacing * 2)
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
