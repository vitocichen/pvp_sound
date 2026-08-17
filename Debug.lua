---@type string, Addon
local _, addon = ...

-- debug/combat-trace: chat prints for reload → hit mob → combat errors.
-- Turn off: /run PVP_Sound_DebugTrace = false  (after load, addon.DebugCombatTrace)
addon.DebugCombatTrace = true
addon.DebugBuild = "combat-trace-4-worldframe"

local PREFIX = "|cff66ccff[PS dbg]|r "
local ERR_PREFIX = "|cffff3333[PS dbg ERR]|r "
local logCount = 0
local LOG_CAP = 80

function addon.DbgVal(v)
	if v == nil then
		return "nil"
	end
	if issecretvalue and issecretvalue(v) then
		return "SECRET(" .. type(v) .. ")"
	end
	local t = type(v)
	if t == "boolean" or t == "number" or t == "string" then
		return tostring(v)
	end
	return t
end

function addon.Dbg(fmt, ...)
	if not addon.DebugCombatTrace then
		return
	end
	logCount = logCount + 1
	if logCount > LOG_CAP then
		if logCount == LOG_CAP + 1 then
			print(PREFIX .. "log cap " .. LOG_CAP .. " reached; errors still print")
		end
		return
	end
	print(PREFIX .. string.format(fmt, ...))
end

function addon.DbgCall(tag, fn)
	local ok, err = xpcall(fn, function(e)
		local stack = ""
		if debugstack then
			local s, st = pcall(debugstack, 3, 8, 0)
			if s and type(st) == "string" then
				stack = "\n" .. st
			end
		end
		return tostring(e) .. stack
	end)
	if not ok then
		print(ERR_PREFIX .. tostring(tag) .. " " .. tostring(err))
	end
	return ok
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:RegisterEvent("PLAYER_TARGET_CHANGED")
	f:SetScript("OnEvent", function(_, event)
		if not addon.DebugCombatTrace then
			return
		end
		addon.DbgCall("dump:" .. tostring(event), function()
			if event == "PLAYER_ENTERING_WORLD" then
				addon.Dbg("build=%s", tostring(addon.DebugBuild))
			end
			addon.Dbg("%s lockdown=%s", event, tostring(InCombatLockdown and InCombatLockdown()))
			-- Combat start/lockdown: do not call Unit* or nameplate APIs (taints target UI).
			if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
				return
			end
			local units = addon.Utils and addon.Utils.Units
			if event == "PLAYER_TARGET_CHANGED" then
				if units and units.Exists and units:Exists("target") then
					local isPlayer = UnitIsPlayer("target")
					addon.Dbg("  target=%s isPlayer=%s canAttack=%s isEnemyPlayer=%s name=%s",
						"target",
						addon.DbgVal(isPlayer),
						addon.DbgVal(UnitCanAttack("player", "target")),
						tostring(units:IsEnemyPlayer("target")),
						addon.DbgVal(UnitName("target")))
				else
					addon.Dbg("  target=(none or secret exists)")
				end
			end
		end)
	end)
end

-- Internal diagnostics only (not registered as a public slash command).
function addon.DebugDiag()
	local moduleUtil = addon.Utils.ModuleUtil
	local auraSounds = addon.Core.AuraSounds
	local units = addon.Utils.Units
	local db = addon.Core.Framework:GetSavedVars()
	local modern = addon.Core.Compat:UseAddAuraSound()

	print("|cff33ff99=== PVP Sound diag ===|r")
	print(string.format("  engine=%s AddAuraSound=%s",
		modern and "modern(12.1+)" or "legacy(PrivateAura+TTS)",
		tostring(auraSounds and auraSounds:IsAvailable())))

	local zoneKey = moduleUtil:GetZoneKey()
	local zone = moduleUtil:GetZoneConfig()
	print(string.format("  zone=%s", tostring(zoneKey)))

	if not modern then
		print(string.format("  master Enabled=%s ImportantEnabled=%s CCEnabled=%s CastBar=%s",
			tostring(zone and zone.Enabled),
			tostring(zone and zone.ImportantEnabled),
			tostring(zone and zone.CCEnabled),
			tostring(zone and zone.CastBar)))
		print("  legacy engine = TTS + nameplate buffList (v2.0.3 path)")
		print("|cff33ff99=== end (legacy) ===|r")
		return
	end

	local voicePack = addon.Core.VoicePack
	local auraMod = addon.Modules.AuraSoundModule

	local enabled, disabled = 0, 0
	if db.Spells then
		for spellId in pairs(addon.Data.EnemyBuffSounds) do
			if db.Spells[spellId] == false then
				disabled = disabled + 1
			else
				enabled = enabled + 1
			end
		end
	else
		for _ in pairs(addon.Data.EnemyBuffSounds) do
			enabled = enabled + 1
		end
	end

	local buffOn = zone and zone.Enabled == true
	local debuffOn = not zone or zone.CcEnabled ~= false
	local buffRange = (zone and zone.TargetFocusOnly == false) and "所有人" or "仅目标+焦点"
	local debuffRange = (zone and zone.CcScope == "party") and "自己+队友" or "自己"
	print(string.format("  buff: enabled=%s range=%s (TargetFocusOnly=%s)",
		tostring(buffOn), buffRange, tostring(zone and zone.TargetFocusOnly)))
	print(string.format("  debuff: enabled=%s range=%s (CcScope=%s)",
		tostring(debuffOn), debuffRange, tostring(zone and zone.CcScope)))
	print(string.format("  healerCC: enabled=%s healers=%d sound=%s",
		tostring(not zone or zone.HealerCcEnabled ~= false),
		#(units:FindHealers()),
		tostring(db.HealerCcSoundFile or "HealerCcAlert.ogg")))
	print(string.format("  interrupt: enabled=%s sound=%s",
		tostring(moduleUtil:IsInterruptAlertsEnabled()),
		tostring(db.InterruptSoundFile or "interrupted.ogg")))
	print(string.format("  consumableSay: enabled=%s",
		tostring(moduleUtil:IsConsumableSayEnabled())))
	print(string.format("  cast: enabled=%s",
		tostring(moduleUtil:IsCastAlertsEnabled())))
	print(string.format("  voicePack=%s path=%s",
		tostring(voicePack:GetSelectedPack()),
		tostring(voicePack:GetBasePath())))
	print(string.format("  spells on=%d off=%d", enabled, disabled))
	local byToken, total = auraMod:GetRegistrationStats()
	print(string.format("  registered handles=%d", total))
	for token, n in pairs(byToken) do
		if token:find("%(selfCC%)$") or token:find("%(healerCC%)$") then
			print(string.format("    %s handles=%d", token, n))
		else
			local exists = units:Exists(token)
			local canAtk = units:CanAttack(token)
			local isEnemy = units:IsEnemy(token)
			local isPlayer = UnitIsPlayer(token)
			print(string.format("    %s handles=%d exists=%s canAttack=%s isEnemy=%s isPlayer=%s",
				token, n, tostring(exists), tostring(canAtk), tostring(isEnemy), tostring(isPlayer)))
		end
	end

	if total == 0 then
		print("  |cffff6666无注册：选中敌对玩家，或关掉「仅目标/焦点」并打开姓名板；debuff 应有 player(selfCC)|r")
	end

	if units:Exists("target") then
		print(string.format("  target: enemyPlayer=%s canAttack=%s isEnemy=%s",
			tostring(units:IsEnemyPlayer("target")),
			tostring(units:CanAttack("target")),
			tostring(units:IsEnemy("target"))))
	else
		print("  target: (none)")
	end

	print("|cff33ff99=== end ===|r")
end
