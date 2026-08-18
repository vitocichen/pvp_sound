---@type string, Addon
local _, addon = ...

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
	local L = addon.L
	local buffRange = (zone and zone.TargetFocusOnly == false) and L["debug_diag_range_all"] or L["debug_diag_range_tf"]
	local debuffRange = (zone and zone.CcScope == "party") and L["debug_diag_scope_party"] or L["debug_diag_scope_self"]
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
		print("  |cffff6666" .. L["debug_diag_no_reg"] .. "|r")
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
