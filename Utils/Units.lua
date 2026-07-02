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

function M:FriendlyUnits()
	if not IsInGroup() then
		return {}
	end

	local isRaid = IsInRaid()
	local units = isRaid and allRaidUnitsIds or allPartyUnitsIds
	local results = {}

	for i = 1, #units do
		local unit = units[i]
		if not UnitIsUnit(unit, "player") then
			local exists = UnitExists(unit)
			if not issecretvalue(exists) and exists then
				results[#results + 1] = unit
			end
		end
	end

	return results
end

function M:IsFriend(unitToken)
	return UnitIsFriend("player", unitToken)
end

function M:IsEnemy(unitToken)
	return UnitIsEnemy("player", unitToken)
end

-- Enemy player character only (no NPCs, no player pets/minions).
function M:IsEnemyPlayer(unitToken)
	if not unitToken then return false end
	local exists = UnitExists(unitToken)
	if not exists or issecretvalue(exists) then return false end
	if not M:IsEnemy(unitToken) then return false end
	if M:IsPetOrMinion(unitToken) then return false end
	local isPlayer = UnitIsPlayer(unitToken)
	if issecretvalue(isPlayer) then return false end
	return isPlayer
end

-- True for a player's pet OR guardian/minion. UnitIsOtherPlayersPet only
-- catches controllable pets (e.g. Hunter pet, Water Elemental); guardians like
-- Mage Mirror Images, Warlock Wild Imps/Dreadstalkers and most temporary
-- summons are caught by UnitIsMinion instead.
function M:IsPetOrMinion(unitToken)
	if not unitToken then return false end
	if string.find(unitToken, "pet", 1, true) then return true end
	if UnitIsOtherPlayersPet(unitToken) then return true end
	if UnitIsMinion and UnitIsMinion(unitToken) then return true end
	return false
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
