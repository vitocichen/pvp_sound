---@type string, Addon
local _, addon = ...
local moduleUtil = addon.Utils.ModuleUtil
local units = addon.Utils.Units

-- Temporary diagnostic for the "intermittently stops announcing with BBP" issue.
-- Run /pvpsdiag while targeting an enemy who has buffs up but isn't being
-- announced, then again after a /reload when it works, and compare.
-- Safe to delete (and remove from the .toc) once done.

local function fmt(v)
	if v == nil then return "nil" end
	if issecretvalue(v) then return "|cffff5555SEC|r" end
	return tostring(v)
end

local function CountFilter(unit, filter)
	local n = 0
	for i = 1, 60 do
		local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
		if not a then break end
		n = n + 1
	end
	return n
end

SLASH_PVPSDIAG1 = "/pvpsdiag"
SlashCmdList["PVPSDIAG"] = function()
	print("|cff33ff99=== PVPS diag ===|r")

	-- Global / zone state
	local zone = moduleUtil:GetZoneConfig()
	print(string.format("  enabled=%s zoneKey=%s | Important=%s Defensive=%s TargetFocusOnly=%s",
		tostring(moduleUtil:IsEnabled()), tostring(moduleUtil:GetZoneKey()),
		zone and tostring(zone.Important) or "?",
		zone and tostring(zone.Defensive) or "?",
		zone and tostring(zone.TargetFocusOnly) or "?"))

	-- Enemy Buffs CVar bit (our auto-enable target)
	local bit = "?"
	if C_CVar and C_CVar.GetCVarBitfield and Enum and Enum.NamePlateEnemyPlayerAuraDisplay then
		bit = tostring(C_CVar.GetCVarBitfield("nameplateEnemyPlayerAuraDisplay", Enum.NamePlateEnemyPlayerAuraDisplay.Buffs))
	end
	print("  EnemyBuffs CVar bit = " .. bit)

	-- Target inspection
	local unit = "target"
	if not UnitExists(unit) then print("  (no target)") print("|cff33ff99=== end ===|r") return end
	print(string.format("  target=%s isEnemy=%s combat=%s | HELPFUL=%d BIG_DEF=%d",
		UnitName(unit) or "?", tostring(units:IsEnemy(unit)), tostring(UnitAffectingCombat(unit)),
		CountFilter(unit, "HELPFUL"), CountFilter(unit, "HELPFUL|BIG_DEFENSIVE")))

	local np = C_NamePlate.GetNamePlateForUnit(unit)
	local uf = np and np.UnitFrame
	local af = uf and uf.AurasFrame
	print(string.format("  nameplate=%s UnitFrame=%s AurasFrame=%s buffFilter=%s afShown=%s",
		tostring(np ~= nil), tostring(uf ~= nil), tostring(af ~= nil),
		af and tostring(af.buffFilterString) or "-",
		af and tostring(af.IsShown and af:IsShown()) or "-"))

	if af then
		local shown, withId = 0, 0
		local function walk(frame, depth)
			if depth > 4 or not frame.GetChildren then return end
			for _, child in ipairs({ frame:GetChildren() }) do
				if type(child) == "table" and type(child.Icon) == "table" then
					if child.IsShown and child:IsShown() then
						shown = shown + 1
						local id = child.auraInstanceID
						local hasId = (id ~= nil and not issecretvalue(id))
						if hasId then withId = withId + 1 end
						print(string.format("    icon shown isBuff=%s auraInstanceID=%s alpha=%s",
							fmt(child.isBuff), fmt(id), tostring(child.GetAlpha and child:GetAlpha())))
					end
				else
					walk(child, depth + 1)
				end
			end
		end
		pcall(walk, af, 0)
		print(string.format("  -> shown icons=%d, with readable auraInstanceID=%d", shown, withId))
	end
	print("|cff33ff99=== end ===|r")
end
