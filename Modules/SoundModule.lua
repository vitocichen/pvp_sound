---@type string, Addon
local addonName, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local voicePack = addon.Core.VoicePack

-- Cast/interrupt: zone CastBar gates Blizzard Accessibility target-cast (CAA).
-- Addon no longer double-announces cast-start (system handles that); keeps instant totems + interrupts.
-- Interrupt voice matches BBF Kick Popup: only after our kick spell succeeded.
local castSounds = addon.Data.CastSounds
local castSuccessSounds = addon.Data.CastSuccessSounds

-- Same interrupt spell set as BetterBlizzFrames Kick Popup.
local INTERRUPT_SPELLS = {
	[1766] = true, -- Kick
	[2139] = true, -- Counterspell
	[6552] = true, -- Pummel
	[19647] = true, -- Spell Lock
	[47528] = true, -- Mind Freeze
	[57994] = true, -- Wind Shear
	[96231] = true, -- Rebuke
	[106839] = true, -- Skull Bash
	[115781] = true, -- Optical Blast
	[116705] = true, -- Spear Hand Strike
	[132409] = true, -- Spell Lock
	[119910] = true, -- Spell Lock (pet)
	[89766] = true, -- Axe Toss
	[171138] = true, -- Shadow Lock
	[147362] = true, -- Counter Shot
	[183752] = true, -- Disrupt
	[187707] = true, -- Muzzle
	[212619] = true, -- Call Felhunter
	[351338] = true, -- Quell
	[97547] = true, -- Solar Beam
	[78675] = true, -- Solar Beam
	[15487] = true, -- Silence
}

local INSTANT_CAST_ALERTS = {
	[204336] = true, -- Grounding Totem
	[8143] = true, -- Tremor Totem
	[98008] = true, -- Spirit Link Totem
	[108280] = true, -- Healing Tide Totem
	[192058] = true, -- Capacitor Totem
	[192222] = true, -- Liquid Magma Totem
	[198838] = true, -- Earthen Wall Totem
	[204331] = true, -- Counterstrike Totem
	[204330] = true, -- Skyfury Totem
	[355580] = true, -- Static Field Totem
	[383013] = true, -- Poison Cleansing Totem
	[444995] = true, -- Surging Totem
}

local MEDIA_ROOT = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local FALLBACK_CAST_FILE = "Lockout.ogg"

---@type Db
local db

local inPrepRoom = false
local castFrame
local lastCastAnnounceTime = 0
local lastInterruptAnnounceTime = 0
local kickPlayerKicked = false
local lastInstantAnnounceTime = 0
local lastAnnouncedKey = nil
local cachedCastInterval = 0

---@class SoundModule
local M = {}
addon.Modules.SoundModule = M

local function Channel()
	return (db and db.Sound and db.Sound.Channel) or "Master"
end

local function PlayFile(file)
	if not file then return false end
	local path = voicePack:Path(file)
	if not path then return false end
	local ok = pcall(PlaySoundFile, path, Channel())
	return ok and true or false
end

local function PlayMapped(map, spellID)
	if spellID == nil then return false end
	if issecretvalue and issecretvalue(spellID) then return false end
	local file = map[spellID]
	if not file then return false end
	return PlayFile(file)
end

---System TTS (same path as legacy cast bar). Uses game TTS settings when available.
local function SpeakSpellName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if not (C_VoiceChat and C_VoiceChat.SpeakText) then
		return false
	end
	local voiceId = 0
	if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
		voiceId = C_TTSSettings.GetVoiceOptionID(0) or 0
	end
	local rate = 0
	if C_TTSSettings and C_TTSSettings.GetSpeechRate then
		rate = C_TTSSettings.GetSpeechRate() or 0
	elseif db and db.Sound and db.Sound.TtsSpeechRate ~= nil then
		rate = db.Sound.TtsSpeechRate
	else
		rate = 5
	end
	local vol = 100
	if C_TTSSettings and C_TTSSettings.GetSpeechVolume then
		vol = C_TTSSettings.GetSpeechVolume() or 100
	end
	local dest = true
	if Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback then
		dest = Enum.VoiceTtsDestination.LocalPlayback
	end
	local ok = pcall(C_VoiceChat.SpeakText, voiceId, name, rate, vol, dest)
	return ok and true or false
end

local function IsHostileCaster(unit)
	if not unit then return false end
	-- Token check only (no UnitIsUnit): Midnight PvP makes UnitIsUnit(targettarget, "player") a secret boolean.
	if unit == "player" or unit == "pet" or unit == "vehicle" then return false end
	if not units:Exists(unit) then return false end
	if units:IsPetOrMinion(unit) then return false end
	if units:IsFriend(unit) then return false end
	return units:CanAttack(unit)
end

---CastBarTargetOnly ~= false → only target/focus.
local function IsCastUnitInRange(unit)
	local zone = moduleUtil:GetZoneConfig()
	local targetOnly = not zone or zone.CastBarTargetOnly ~= false
	if not targetOnly then
		return true
	end
	if units:Exists("target") and units:IsSameUnit(unit, "target") then
		return true
	end
	if units:Exists("focus") and units:IsSameUnit(unit, "focus") then
		return true
	end
	return false
end

---@return string? name
---@return number? spellId
local function ReadCastInfo(unit)
	if not unit or not units:Exists(unit) then
		return nil, nil
	end
	local name, _, _, _, _, _, _, _, spellId = UnitCastingInfo(unit)
	if name then
		return name, units:PublicNumber(spellId)
	end
	name, _, _, _, _, _, _, spellId = UnitChannelInfo(unit)
	return name, units:PublicNumber(spellId)
end

local function AnnounceCast(name, spellID)
	local now = GetTime()
	local minInterval = cachedCastInterval > 0 and cachedCastInterval or 0.05
	-- Dedupe same cast arriving via target + nameplate in one window.
	local key = tostring(name or "") .. ":" .. tostring(spellID or "")
	if key == lastAnnouncedKey and (now - lastCastAnnounceTime) < 0.4 then
		return
	end
	if now - lastCastAnnounceTime < minInterval then
		return
	end
	lastCastAnnounceTime = now
	lastAnnouncedKey = key

	if PlayMapped(castSounds, spellID) then
		return
	end
	if name and SpeakSpellName(name) then
		return
	end
	-- Last resort: short pack clip so outdoor tests still hear something.
	if not PlayFile(FALLBACK_CAST_FILE) then
		print(string.format("|cffffd100[PVP Sound]|r 读条检测到但无法播放：%s", tostring(name or spellID or "?")))
	end
end

local function AnnounceInstantCast(spellID)
	if spellID == nil or (issecretvalue and issecretvalue(spellID)) then return end
	if not INSTANT_CAST_ALERTS[spellID] then return end
	local now = GetTime()
	if now - lastInstantAnnounceTime < 0.15 then return end
	lastInstantAnnounceTime = now
	PlayMapped(castSuccessSounds, spellID)
end

local function TryAnnounceUnit(unit, eventSpellID)
	-- Cast-start/channel is handled by system C_CombatAudioAlert when zone CastBar is on.
	-- Keep this no-op to avoid double voice with Accessibility TTS.
	return
end

local function OnCastSuccess(unit, spellID)
	-- Instant utility totems still use pack clips (system target-cast does not cover these).
	if not moduleUtil:IsCastAlertsEnabled() or inPrepRoom then return end
	if not IsHostileCaster(unit) then return end
	if not IsCastUnitInRange(unit) then return end
	AnnounceInstantCast(spellID)
end

local function ResolveInterruptSoundPath()
	local file = (db and db.InterruptSoundFile) or "interrupted.ogg"
	if file == "interrupted.ogg" then
		return voicePack:Path("interrupted.ogg")
	end
	return MEDIA_ROOT .. file
end

local function MarkPlayerKicked()
	kickPlayerKicked = true
	if castFrame then
		castFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	end
	C_Timer.After(0.1, function()
		kickPlayerKicked = false
		if castFrame then
			castFrame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		end
	end)
end

-- Midnight: 4th UNIT_SPELLCAST_INTERRUPTED arg is secret or interrupted-by id
-- when a kick actually landed; nil when the caster cancelled. Matches BBF.
local function IsRealInterruptArg(interruptedByOrCastBarID)
	if issecretvalue then
		return issecretvalue(interruptedByOrCastBarID) or (interruptedByOrCastBarID ~= nil)
	end
	return interruptedByOrCastBarID ~= nil
end

local function PlayInterruptAlert()
	local now = GetTime()
	if now - lastInterruptAnnounceTime < 0.05 then return end
	lastInterruptAnnounceTime = now
	local path = ResolveInterruptSoundPath()
	if path then
		pcall(PlaySoundFile, path, Channel())
	end
end

local function OnCastInterrupted(event, unit, extraArg)
	if not moduleUtil:IsInterruptAlertsEnabled() or inPrepRoom then return end

	local isRealInterrupt = IsRealInterruptArg(extraArg)
	if not isRealInterrupt then
		-- Channelled casts often omit the interrupt arg; BBF uses CHANNEL_STOP
		-- in the 0.1s window after our kick.
		if event == "UNIT_SPELLCAST_CHANNEL_STOP"
			and kickPlayerKicked
			and unit
			and not units:IsFriend(unit)
		then
			PlayInterruptAlert()
		end
		if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			kickPlayerKicked = false
			if castFrame then
				castFrame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
			end
		end
		return
	end

	if not kickPlayerKicked then return end
	if not IsHostileCaster(unit) then return end
	PlayInterruptAlert()
end

local function OnMatchStateChanged()
	local matchState = C_PvP.GetActiveMatchState()
	inPrepRoom = matchState == Enum.PvPMatchState.StartUp
end

---Manual probe for outdoor testing: /ps casttest
function M:DebugCastTest()
	print("|cffffd100[PVP Sound]|r CastBar=" .. tostring(moduleUtil:IsCastAlertsEnabled())
		.. " zone=" .. tostring(moduleUtil:GetZoneKey()))
	local name, spellId = ReadCastInfo("target")
	print(string.format("|cffffd100[PVP Sound]|r target casting: name=%s id=%s",
		tostring(name), tostring(spellId)))
	if name then
		AnnounceCast(name, spellId)
	else
		AnnounceCast("变形术", 118)
		print("|cffffd100[PVP Sound]|r 目标未在读条，已试播「变形术」/118。")
	end
end

---Quick test / control Blizzard Accessibility → Audio Assistance (目标施法).
---Master = 「启动战斗音频预警」CVar CAAEnabled（总开关，关了下面全灰）。
---Mode = CAATargetCastMode（关闭/开始时/结束时）；Format = 措辞（别和 Mode 搞混）。
---/ps syscast                 打印状态（不播、不改）
---/ps syscast master on|off   总开关
---/ps syscast off|on|end      改 Mode（on/end 会顺带打开总开关）
---/ps syscast mode N          同上
---/ps syscast format N        改措辞（0~6）
---/ps syscast speak           强制 SpeakText 试听
function M:DebugSysCast(arg)
	local CAA = C_CombatAudioAlert
	if not CAA then
		print("|cffff3333[PVP Sound]|r 无 C_CombatAudioAlert（客户端太旧？）")
		return
	end

	local unit = (Enum and Enum.CombatAudioAlertUnit and Enum.CombatAudioAlertUnit.Target) or 1
	local alert = (Enum and Enum.CombatAudioAlertType and Enum.CombatAudioAlertType.Cast) or 1
	local cat = (Enum and Enum.CombatAudioAlertCategory and Enum.CombatAudioAlertCategory.TargetCast) or 4

	local MODE_LABEL = { [0] = "关闭", [1] = "施法开始时", [2] = "施法结束时" }
	local FORMAT_LABEL = {
		[0] = "目标正在施放火球术",
		[1] = "目标施放火球术",
		[2] = "正在施放火球术",
		[3] = "施放火球术",
		[4] = "正在施放",
		[5] = "施放",
		[6] = "火球术",
	}

	local function getMaster()
		if GetCVarBool then
			local ok, v = pcall(GetCVarBool, "CAAEnabled")
			if ok and v ~= nil and not (issecretvalue and issecretvalue(v)) then
				return v and true or false
			end
		end
		return (units:PublicNumber(GetCVar and GetCVar("CAAEnabled")) or 0) ~= 0
	end

	local function setMaster(enabled)
		enabled = not not enabled
		local okCvar = pcall(SetCVar, "CAAEnabled", enabled and "1" or "0")
		print(string.format(
			"|cffffd100[PVP Sound]|r 总开关 SetCVar(CAAEnabled)=%s → %s",
			tostring(okCvar), enabled and "开" or "关"
		))
		return okCvar
	end

	local function getMode()
		local v = GetCVar and GetCVar("CAATargetCastMode")
		return units:PublicNumber(v)
	end

	local function getFormat()
		if CAA.GetFormatSetting then
			local ok, v = pcall(CAA.GetFormatSetting, unit, alert)
			if ok and v ~= nil then
				return units:PublicNumber(v)
			end
		end
		return units:PublicNumber(GetCVar and GetCVar("CAATargetCastFormat"))
	end

	local function setMode(v, ensureMaster)
		v = tonumber(v)
		if not v or v < 0 or v > 2 then
			print("|cffff3333[PVP Sound]|r Mode 只能是 0/1/2（关闭/开始时/结束时）")
			return false
		end
		-- Mode>0 时若总开关关着，子项开了也不响 → 顺带打开总开关。
		if ensureMaster ~= false and v > 0 and not getMaster() then
			setMaster(true)
		end
		local ok, ret = pcall(SetCVar, "CAATargetCastMode", tostring(v))
		print(string.format(
			"|cffffd100[PVP Sound]|r SetCVar(CAATargetCastMode,%s) ok=%s ret=%s → %s",
			tostring(v), tostring(ok), tostring(ret), MODE_LABEL[v] or "?"
		))
		return ok
	end

	local function setFormat(v)
		v = tonumber(v)
		if not v or v < 0 or v > 6 then
			print("|cffff3333[PVP Sound]|r Format 只能是 0~6（措辞）")
			return false
		end
		local okApi, ret = true, nil
		if CAA.SetFormatSetting then
			okApi, ret = pcall(CAA.SetFormatSetting, unit, alert, v)
		end
		local okCvar = pcall(SetCVar, "CAATargetCastFormat", tostring(v))
		print(string.format(
			"|cffffd100[PVP Sound]|r SetFormatSetting=%s/%s SetCVar=%s → %s",
			tostring(okApi), tostring(ret), tostring(okCvar), FORMAT_LABEL[v] or "?"
		))
		return okApi
	end

	local function dump()
		local enabled = getMaster()
		local mode = getMode()
		local fmt = getFormat()
		local voice = CAA.GetCategoryVoice and CAA.GetCategoryVoice(cat)
		local vol = CAA.GetCategoryVolume and CAA.GetCategoryVolume(cat)
		local throttle = CAA.GetThrottle and CAA.GetThrottle(
			(Enum and Enum.CombatAudioAlertThrottle and Enum.CombatAudioAlertThrottle.TargetCast) or 4
		)
		local minTime = GetCVar and GetCVar("CAATargetCastMinTime")
		print(string.format(
			"|cffffd100[PVP Sound]|r syscast 总开关=%s Mode=%s(%s) Format=%s(%s)",
			enabled and "开" or "关",
			tostring(mode), MODE_LABEL[mode] or "?",
			tostring(fmt), FORMAT_LABEL[fmt] or "?"
		))
		print(string.format(
			"|cffffd100[PVP Sound]|r Voice=%s Vol=%s Throttle=%s MinTime=%s",
			tostring(voice), tostring(vol), tostring(throttle), tostring(minTime)
		))
		print("|cffffd100[PVP Sound]|r master=总开关；Mode=关闭/开始/结束；Format=措辞。")
	end

	arg = arg and tostring(arg):lower():match("^%s*(.-)%s*$") or ""
	local cmd, rest = arg:match("^(%S+)%s*(.*)$")
	cmd = cmd or ""
	rest = rest or ""

	if cmd == "master" or cmd == "enable" or cmd == "caa" then
		if rest == "on" or rest == "1" or rest == "true" then
			setMaster(true)
		elseif rest == "off" or rest == "0" or rest == "false" then
			setMaster(false)
		else
			print("|cffff3333[PVP Sound]|r 用法: /ps syscast master on|off")
		end
		dump()
		return
	elseif cmd == "off" then
		setMode(0, false)
		dump()
		return
	elseif cmd == "on" or cmd == "start" then
		setMode(1, true)
		dump()
		return
	elseif cmd == "end" then
		setMode(2, true)
		dump()
		return
	elseif cmd == "mode" then
		setMode(rest ~= "" and rest or nil, true)
		dump()
		return
	elseif cmd == "format" or cmd == "fmt" then
		if rest == "" or rest == "list" then
			print("|cffffd100[PVP Sound]|r Format 措辞列表：")
			for i = 0, 6 do
				print(string.format("  %d = %s", i, FORMAT_LABEL[i]))
			end
			dump()
			return
		end
		setFormat(rest)
		dump()
		return
	elseif cmd == "speak" or cmd == "test" then
		dump()
		if CAA.SpeakText then
			local ok, id = pcall(CAA.SpeakText, "火球术", cat, true)
			print("|cffffd100[PVP Sound]|r SpeakText(火球术, TargetCast) ok=" .. tostring(ok) .. " id=" .. tostring(id))
		end
		return
	elseif cmd ~= "" and tonumber(cmd) and rest == "" then
		setMode(cmd, true)
		dump()
		return
	end

	dump()
end

function M:SyncSysCastZoneGate()
	if not C_CombatAudioAlert or not GetCVar or not SetCVar then
		return
	end
	db = db or addon.Core.Framework:GetSavedVars()
	db.SysCast = db.SysCast or {}

	local preferred = units:PublicNumber(db.SysCast.PreferredMode)
	if preferred == nil then
		preferred = units:PublicNumber(GetCVar("CAATargetCastMode")) or 1
		if preferred < 1 then
			preferred = 1
		end
		db.SysCast.PreferredMode = preferred
	end

	local want = 0
	if moduleUtil:IsCastAlertsEnabled() then
		want = preferred
		if want < 0 then want = 0 end
		if want > 2 then want = 2 end
		-- Do not force CAAEnabled here; master stays under the 读条 page / system UI.
	end

	local cur = units:PublicNumber(GetCVar("CAATargetCastMode")) or 0
	if cur ~= want then
		pcall(SetCVar, "CAATargetCastMode", tostring(want))
	end
end

function M:Refresh()
	db = addon.Core.Framework:GetSavedVars()
	OnMatchStateChanged()
	cachedCastInterval = (db and db.Sound and db.Sound.CastInterval) or 0
	self:SyncSysCastZoneGate()
end

function M:Init()
	local mini = addon.Core.Framework
	db = mini:GetSavedVars()
	cachedCastInterval = (db.Sound and db.Sound.CastInterval) or 0

	-- Only create the event frame once (AfterSettingsMutated used to re-Init and stack handlers).
	if not castFrame then
		castFrame = CreateFrame("Frame")
		castFrame:RegisterEvent("UNIT_SPELLCAST_START")
		castFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		castFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		castFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		castFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
		castFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		castFrame:SetScript("OnEvent", function(_, event, unit, _, spellID, extraArg)
			if event == "PLAYER_ENTERING_WORLD" then
				M:SyncSysCastZoneGate()
			elseif event == "PVP_MATCH_STATE_CHANGED" then
				OnMatchStateChanged()
				M:SyncSysCastZoneGate()
			elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
				OnCastInterrupted(event, unit, extraArg)
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				-- BBF Kick Popup: only our own kick spell arms the interrupt window.
				if (unit == "player" or unit == "pet") and spellID and INTERRUPT_SPELLS[spellID] then
					MarkPlayerKicked()
				end
				if unit == "player" or unit == "pet" or unit == "targettarget" or unit == "focustarget" or unit == "mouseover" then
					return
				end
				OnCastSuccess(unit, spellID)
			else
				TryAnnounceUnit(unit, spellID)
			end
		end)
	end

	self:SyncSysCastZoneGate()
end
