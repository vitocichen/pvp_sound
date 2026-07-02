---@type string, Addon

local _, addon = ...

local moduleUtil = addon.Utils.ModuleUtil

local units = addon.Utils.Units

local enemyBuffSpellIds = addon.Data.EnemyBuffSpellIds.SPELL_IDS

local spellSoundMap = addon.Data.SpellSoundMap.SPELL_TO_SOUND



local MEDIA_PREFIX = "Interface\\AddOns\\PVP_Sound\\Media\\"

local DEFAULT_OUTPUT = "Master"



---@class PrivateAuraSoundModule

local M = {}

addon.Modules.PrivateAuraSound = M



-- registeredSoundIds[unitToken .. ":" .. spellID] = privateAuraSoundID

local registeredSoundIds = {}

local registerFrame

local debugEnabled = false



function M:SetDebug(enabled)

	debugEnabled = enabled and true or false

	if debugEnabled then

		print("|cff33ff99[PVP_Sound PAS]|r 调试已开启（/pvpspas off 关闭）")

	else

		print("|cff33ff99[PVP_Sound PAS]|r 调试已关闭")

	end

end



function M:IsDebug()

	return debugEnabled

end



local function Dbg(...)

	if debugEnabled then

		print("|cff33ff99[PVP_Sound PAS]|r", ...)

	end

end



local function UnitLabel(unitToken)

	if not unitToken or not UnitExists(unitToken) then

		return tostring(unitToken or "?") .. "(不存在)"

	end

	return string.format("%s(%s)", unitToken, UnitName(unitToken) or "?")

end



local function IsRegistrationAllowed()

	if not C_UnitAuras or not C_UnitAuras.AddPrivateAuraAppliedSound then

		return false

	end

	if InCombatLockdown and InCombatLockdown() then

		return false

	end

	return true

end



local function ShouldRegisterForZone()

	if not moduleUtil:IsEnabled() then

		return false

	end

	local zone = moduleUtil:GetZoneConfig()

	if not zone then return false end

	if zone.ImportantEnabled == false then

		return false

	end

	if not zone.Important and not zone.Defensive then

		return false

	end

	return true

end



local function GetSoundPathForSpell(spellID)

	local fileName = spellSoundMap[spellID]

	if not fileName or fileName == "" then

		return nil

	end

	return MEDIA_PREFIX .. fileName

end



local function IsUnitInWatchList(unitToken, watchTokens)

	if not unitToken then return false end

	for i = 1, #watchTokens do

		if watchTokens[i] == unitToken then

			return true

		end

	end

	return false

end



function M:GetWatchUnitTokens()

	local tokens = {}

	local inInstance, instanceType = IsInInstance()



	if instanceType == "arena" then

		tokens[#tokens + 1] = "arena1"

		tokens[#tokens + 1] = "arena2"

		tokens[#tokens + 1] = "arena3"

		tokens[#tokens + 1] = "target"

		tokens[#tokens + 1] = "focus"

		return tokens

	end



	local zone = moduleUtil:GetZoneConfig()

	local targetFocusOnly = zone and zone.TargetFocusOnly ~= false



	tokens[#tokens + 1] = "target"

	tokens[#tokens + 1] = "focus"



	if not targetFocusOnly then

		for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do

			local unitToken = nameplate.unitToken

			if units:IsEnemyPlayer(unitToken) then

				tokens[#tokens + 1] = unitToken

			end

		end

	end



	return tokens

end



local function SummarizeRegisteredByUnit()

	local byUnit = {}

	for key in pairs(registeredSoundIds) do

		local unitToken = key:match("^([^:]+):")

		if unitToken then

			byUnit[unitToken] = (byUnit[unitToken] or 0) + 1

		end

	end

	return byUnit

end



function M:DumpRegistrations()

	local byUnit = SummarizeRegisteredByUnit()

	local total = 0

	print("|cff33ff99=== PVP_Sound 私有光环音效注册表 ===|r")

	print(string.format("  区域=%s 脱战=%s API=%s",

		tostring(moduleUtil:GetZoneKey()),

		tostring(not (InCombatLockdown and InCombatLockdown())),

		tostring(C_UnitAuras and C_UnitAuras.AddPrivateAuraAppliedSound ~= nil)))

	local watch = self:GetWatchUnitTokens()

	local watchParts = {}

	for i = 1, #watch do

		watchParts[#watchParts + 1] = UnitLabel(watch[i])

	end

	print("  当前监控: " .. table.concat(watchParts, ", "))

	for unitToken, count in pairs(byUnit) do

		total = total + count

		print(string.format("  已注册 %s → %d 条 spell→ogg", UnitLabel(unitToken), count))

	end

	if total == 0 then

		print("  (空 — 尚未注册或战斗中无法注册)")

	else

		print(string.format("  合计 %d 条", total))

	end

	print("|cff33ff99=== end ===|r")

end



-- 直接播放某个 spellID 映射的 ogg，用来验证文件/路径本身可用（与 PAS 是否触发无关）。

function M:PlayTest(spellID)

	spellID = spellID or 45438

	local fileName = spellSoundMap[spellID]

	if not fileName or fileName == "" then

		print(string.format("|cff33ff99[PVP_Sound PAS]|r spellID=%d 没有 ogg 映射", spellID))

		return

	end

	local path = MEDIA_PREFIX .. fileName

	local ok, handle = PlaySoundFile(path, DEFAULT_OUTPUT)

	print(string.format("|cff33ff99[PVP_Sound PAS]|r 试播 spellID=%d 文件=%s 结果=%s",

		spellID, fileName, ok and "成功(应能听到声音)" or "失败(文件不存在或路径错误)"))

end



function M:ClearRegistrations(reason)

	reason = reason or "?"



	if not C_UnitAuras or not C_UnitAuras.RemovePrivateAuraAppliedSound then

		local n = 0

		for _ in pairs(registeredSoundIds) do n = n + 1 end

		if n > 0 then

			Dbg("清除", n, "条（无 Remove API，仅清本地表）原因:", reason)

		end

		wipe(registeredSoundIds)

		return

	end



	if InCombatLockdown and InCombatLockdown() then

		Dbg("跳过清除（战斗中）原因:", reason)

		return

	end



	local byUnit = SummarizeRegisteredByUnit()

	local removed = 0

	for _, soundId in pairs(registeredSoundIds) do

		pcall(C_UnitAuras.RemovePrivateAuraAppliedSound, soundId)

		removed = removed + 1

	end

	wipe(registeredSoundIds)



	if removed > 0 then

		local parts = {}

		for unitToken, count in pairs(byUnit) do

			parts[#parts + 1] = string.format("%s×%d", UnitLabel(unitToken), count)

		end

		Dbg("已删除", removed, "条注册 |", table.concat(parts, ", "), "| 原因:", reason)

	elseif debugEnabled then

		Dbg("删除 0 条 | 原因:", reason)

	end

end



local function RegisterSound(unitToken, spellID, soundPath)

	local key = unitToken .. ":" .. spellID

	if registeredSoundIds[key] then

		return false

	end



	local soundId = C_UnitAuras.AddPrivateAuraAppliedSound({

		unitToken = unitToken,

		spellID = spellID,

		soundFileName = soundPath,

		outputChannel = DEFAULT_OUTPUT,

	})



	if soundId then

		registeredSoundIds[key] = soundId

		return true

	end

	return false

end



---@return number newlyRegistered

function M:RegisterForUnit(unitToken, reason)

	if not units:IsEnemyPlayer(unitToken) then

		return 0

	end

	if not ShouldRegisterForZone() or not IsRegistrationAllowed() then

		return 0

	end



	local watchTokens = self:GetWatchUnitTokens()

	if not IsUnitInWatchList(unitToken, watchTokens) then

		Dbg("跳过未监控单位", UnitLabel(unitToken), "原因:", reason or "?")

		return 0

	end



	local added = 0

	for i = 1, #enemyBuffSpellIds do

		local spellID = enemyBuffSpellIds[i]

		local soundPath = GetSoundPathForSpell(spellID)

		if soundPath and RegisterSound(unitToken, spellID, soundPath) then

			added = added + 1

		end

	end



	if added > 0 then

		Dbg("注册", UnitLabel(unitToken), added, "条 spell→ogg | 原因:", reason or "?")

	end

	return added

end



function M:Refresh(reason)

	reason = reason or "Refresh"



	if not ShouldRegisterForZone() then

		self:ClearRegistrations(reason .. "/disabled")

		return

	end



	if not IsRegistrationAllowed() then

		Dbg("Refresh 跳过（战斗中或 API 不可用）| 原因:", reason)

		return

	end



	self:ClearRegistrations(reason .. "/before")



	local unitTokens = self:GetWatchUnitTokens()

	local totalAdded = 0

	for i = 1, #unitTokens do

		totalAdded = totalAdded + self:RegisterForUnit(unitTokens[i], reason)

	end



	if totalAdded > 0 then

		Dbg("Refresh 完成，新注册", totalAdded, "条 | 原因:", reason)

	elseif debugEnabled then

		Dbg("Refresh 完成，无新注册（可能 target/focus 非敌人）| 原因:", reason)

	end

end



function M:Init()

	registerFrame = CreateFrame("Frame")

	registerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	registerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

	registerFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

	registerFrame:RegisterEvent("DUEL_INBOUNDS")

	registerFrame:RegisterEvent("DUEL_FINISHED")

	registerFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

	registerFrame:RegisterUnitEvent("UNIT_FACTION", "target", "focus", "arena1", "arena2", "arena3")

	registerFrame:SetScript("OnEvent", function(_, event, arg1)

		if event == "PLAYER_REGEN_ENABLED" or event == "DUEL_FINISHED" then

			M:Refresh(event)

		elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "DUEL_INBOUNDS" then

			-- 切目标/焦点时整表刷新，只保留当前监控列表，避免 tab 过的人都残留注册

			M:Refresh(event)

		elseif event == "NAME_PLATE_UNIT_ADDED" then

			local zone = moduleUtil:GetZoneConfig()

			if zone and zone.TargetFocusOnly == false and units:IsEnemyPlayer(arg1) then

				M:RegisterForUnit(arg1, event)

			end

		elseif event == "UNIT_FACTION" then

			if arg1 and IsRegistrationAllowed() and ShouldRegisterForZone() then

				M:RegisterForUnit(arg1, event)

			end

		end

	end)

end

