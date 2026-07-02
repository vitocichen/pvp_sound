---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units
local privateAuraSound = addon.Modules.PrivateAuraSound

-- Temporary diagnostic for important-buff detection.
-- Run /pvpsdiag while targeting an enemy with buffs up.
-- Private aura sound: /pvpspas [on|off|dump]

local function fmt(v)
	if v == nil then return "nil" end
	if issecretvalue(v) then return "|cffff5555SEC|r" end
	return tostring(v)
end

local function CountBuffList(unit)
	local np = C_NamePlate.GetNamePlateForUnit(unit)
	local af = np and np.UnitFrame and np.UnitFrame.AurasFrame
	if not af or not af.buffList or not af.buffList.Iterate then
		return 0, false
	end
	local n = 0
	pcall(function()
		af.buffList:Iterate(function()
			n = n + 1
		end)
	end)
	return n, true
end

SLASH_PVPSDIAG1 = "/pvpsdiag"
SlashCmdList["PVPSDIAG"] = function()
	print("|cff33ff99=== PVPS diag ===|r")

	local zone = moduleUtil:GetZoneConfig()
	print(string.format("  enabled=%s zoneKey=%s | Important=%s Defensive=%s TargetFocusOnly=%s",
		tostring(moduleUtil:IsEnabled()), tostring(moduleUtil:GetZoneKey()),
		zone and tostring(zone.Important) or "?",
		zone and tostring(zone.Defensive) or "?",
		zone and tostring(zone.TargetFocusOnly) or "?"))

	local unit = "target"
	if not UnitExists(unit) then print("  (no target)") print("|cff33ff99=== end ===|r") return end
	print(string.format("  target=%s isEnemy=%s combat=%s",
		UnitName(unit) or "?", tostring(units:IsEnemy(unit)), tostring(UnitAffectingCombat(unit))))

	local np = C_NamePlate.GetNamePlateForUnit(unit)
	local uf = np and np.UnitFrame
	local af = uf and uf.AurasFrame
	local buffListCount, hasBuffList = CountBuffList(unit)
	print(string.format("  nameplate=%s UnitFrame=%s AurasFrame=%s buffList=%s count=%d",
		tostring(np ~= nil), tostring(uf ~= nil), tostring(af ~= nil),
		tostring(hasBuffList), buffListCount))

	if hasBuffList then
		pcall(function()
			np.UnitFrame.AurasFrame.buffList:Iterate(function(auraInstanceID)
				local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
				print(string.format("    buffList id=%s name=%s",
					fmt(auraInstanceID), data and fmt(data.name) or "?"))
			end)
		end)
	end
	print("|cff33ff99=== end ===|r")
end

SLASH_PVPSPAS1 = "/pvpspas"
SlashCmdList["PVPSPAS"] = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "on" or msg == "1" or msg == "true" then
		privateAuraSound:SetDebug(true)
	elseif msg == "off" or msg == "0" or msg == "false" then
		privateAuraSound:SetDebug(false)
	elseif msg == "dump" or msg == "list" then
		privateAuraSound:DumpRegistrations()
	elseif msg:match("^test") then
		local id = tonumber(msg:match("test%s+(%d+)"))
		privateAuraSound:PlayTest(id)
	elseif msg == "scan" then
		privateAuraSound:ScanTarget()
	else
		print("|cff33ff99PVP_Sound 私有光环音效调试|r")
		print("  /pvpspas on        — 开启注册/删除日志")
		print("  /pvpspas off       — 关闭日志")
		print("  /pvpspas dump      — 查看当前已注册单位与条数")
		print("  /pvpspas test [id] — 直接试播某 spellID 的 ogg（默认 45438 冰箱）")
		print("  /pvpspas scan      — 扫描目标增益，看 spellId 能否运行时读取")
	end
end
