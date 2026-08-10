---@type string, Addon
local _, addon = ...

SLASH_PVPSDIAG1 = "/pvpsdiag"
SlashCmdList["PVPSDIAG"] = function()
	local moduleUtil = addon.Utils.ModuleUtil
	local voicePack = addon.Core.VoicePack
	local auraSounds = addon.Core.AuraSounds
	local units = addon.Utils.Units
	local auraMod = addon.Modules.AuraSoundModule
	local db = addon.Core.Framework:GetSavedVars()

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

	print("|cff33ff99=== PVP Sound diag ===|r")
	local zoneKey = moduleUtil:GetZoneKey()
	local zone = moduleUtil:GetZoneConfig()
	local buffOn = zone and zone.Enabled == true
	local debuffOn = not zone or zone.CcEnabled ~= false
	local buffRange = (zone and zone.TargetFocusOnly == false) and "所有人" or "仅目标+焦点"
	local debuffRange = (zone and zone.CcScope == "party") and "自己+队友" or "自己"
	print(string.format("  zone=%s AddAuraSound=%s", tostring(zoneKey), tostring(auraSounds:IsAvailable())))
	print(string.format("  buff: enabled=%s range=%s (TargetFocusOnly=%s)",
		tostring(buffOn), buffRange, tostring(zone and zone.TargetFocusOnly)))
	print(string.format("  debuff: enabled=%s range=%s (CcScope=%s)",
		tostring(debuffOn), debuffRange, tostring(zone and zone.CcScope)))
	print(string.format("  healerCC: enabled=%s healers=%d sound=Sonar.ogg",
		tostring(not zone or zone.HealerCcEnabled ~= false),
		#(units:FindHealers())))
	print(string.format("  cast/interrupt: enabled=%s",
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
			local exists = UnitExists(token)
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

	if UnitExists("target") then
		print(string.format("  target: enemyPlayer=%s canAttack=%s isEnemy=%s",
			tostring(units:IsEnemyPlayer("target")),
			tostring(units:CanAttack("target")),
			tostring(units:IsEnemy("target"))))
	else
		print("  target: (none)")
	end

	print("|cff33ff99/pvpsoundtest [spellID]|r 试播（默认 45438；风暴之锤可用 132169）")
	print("|cff33ff99=== end ===|r")
end
