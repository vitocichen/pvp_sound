---@type string, Addon
local _, addon = ...

---@class UnitUtil
local M = {}
addon.Utils.Units = M

local allPartyUnitsIds = { "player", "pet" }
local allRaidUnitsIds = {}

for i = 1, MAX_PARTY_MEMBERS do
	allPartyUnitsIds[#allPartyUnitsIds + 1] = "party" .. i
end

for i = 1, MAX_PARTY_MEMBERS do
	allPartyUnitsIds[#allPartyUnitsIds + 1] = "partypet" .. i
end

for i = 1, MAX_RAID_MEMBERS do
	allRaidUnitsIds[#allRaidUnitsIds + 1] = "raid" .. i
end

for i = 1, MAX_RAID_MEMBERS do
	allRaidUnitsIds[#allRaidUnitsIds + 1] = "raidpet" .. i
end

---Secret-safe boolean. Unknown/secret → false (safe for if/and/or).
function M:KnownTrue(value)
	if value == nil then
		return false
	end
	if issecretvalue(value) then
		return false
	end
	return value and true or false
end

---Public number or nil. Secret / tainted cooldown and CVar values must not be compared.
function M:PublicNumber(value)
	if value == nil then
		return nil
	end
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	local ok, n = pcall(tonumber, value)
	if not ok or n == nil then
		return nil
	end
	if issecretvalue and issecretvalue(n) then
		return nil
	end
	return n
end

function M:Exists(unitToken)
	if not unitToken then
		return false
	end
	return M:KnownTrue(UnitExists(unitToken))
end

function M:IsSameUnit(unitA, unitB)
	if not unitA or not unitB then
		return false
	end
	return M:KnownTrue(UnitIsUnit(unitA, unitB))
end

function M:FriendlyUnits()
	if not IsInGroup() then
		return {}
	end

	local isRaid = IsInRaid()
	local units = isRaid and allRaidUnitsIds or allPartyUnitsIds
	local results = {}

	for i = 1, #units do
		local unit = units[i]
		if not M:IsSameUnit(unit, "player") and M:Exists(unit) then
			results[#results + 1] = unit
		end
	end

	return results
end

---True only when confidently a friend. Secret → false (safe for conditions).
function M:IsFriend(unitToken)
	local result = UnitIsFriend("player", unitToken)
	if issecretvalue(result) then
		return false
	end
	return result and true or false
end

---True only when confidently an enemy. Secret → false.
---Note: duel opponents are often NOT IsEnemy (same faction) but ARE CanAttack.
function M:IsEnemy(unitToken)
	local result = UnitIsEnemy("player", unitToken)
	if issecretvalue(result) then
		return false
	end
	return result and true or false
end

---True when we can attack the unit. Secret → true so real enemies aren't dropped.
function M:CanAttack(unitToken)
	local result = UnitCanAttack("player", unitToken)
	if issecretvalue(result) then
		return true
	end
	return result and true or false
end

function M:IsCharmed(unitToken)
	local result = UnitIsCharmed(unitToken)
	if issecretvalue(result) then
		return false
	end
	return result and true or false
end

-- True for a player's pet OR guardian/minion.
function M:IsPetOrMinion(unitToken)
	if not unitToken then return false end
	if string.find(unitToken, "pet", 1, true) then return true end
	if M:KnownTrue(UnitIsOtherPlayersPet(unitToken)) then return true end
	if UnitIsMinion and M:KnownTrue(UnitIsMinion(unitToken)) then return true end
	return false
end

---Enemy (or duel) player worth watching for aura sounds.
---Uses CanAttack — not UnitIsEnemy — so same-faction duel opponents still match (MiniAuras pattern).
function M:IsEnemyPlayer(unitToken)
	if not unitToken then return false end

	local exists = UnitExists(unitToken)
	if issecretvalue(exists) or not exists then
		return false
	end

	if M:IsPetOrMinion(unitToken) then
		return false
	end

	-- Mind-controlled: skip (nameplate buff list flips; MiniAuras does the same).
	if M:IsCharmed(unitToken) then
		return false
	end

	if not M:CanAttack(unitToken) then
		return false
	end

	local isPlayer = UnitIsPlayer(unitToken)
	if issecretvalue(isPlayer) then
		-- Attackable non-pet with secret IsPlayer: keep (nameplate / arena).
		return true
	end
	return isPlayer and true or false
end

function M:IsHealer(unit)
	local role = UnitGroupRolesAssigned(unit)
	return role == "HEALER"
end

function M:FindHealers()
	local friendlyUnits = M:FriendlyUnits()
	local healers = {}

	for _, unit in ipairs(friendlyUnits) do
		if M:IsHealer(unit) then
			healers[#healers + 1] = unit
		end
	end

	return healers
end
