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
		local exists = UnitExists(unit)
		if not issecretvalue(exists) and exists then
			results[#results + 1] = unit
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
