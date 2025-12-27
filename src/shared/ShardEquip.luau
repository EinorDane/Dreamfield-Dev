--!strict
--[[
	THREAD-004: ShardEquip Module
	
	Advanced shard equipping system with corruption mechanics,
	tolerance calculation, overload detection, and validation.
	Prevents players from exceeding corruption thresholds.
	
	File: src/shared/ShardEquip.luau
	Priority: HIGH (core progression system)
	Complexity: High
	Time Estimate: 4-5 hours
]]

local PlayerData = require(script.Parent.PlayerData)
local Inventory = require(script.Parent.Inventory)

local ShardEquip = {}

-- CONFIG
local CORRUPTION_PER_LEVEL = 5
local MIN_CORRUPTION_TOLERANCE = 10
local MAX_SHARD_LEVEL = 10
local EQUIPPED_SHARD_SLOTS = 5

-- ============================================================
-- TYPES
-- ============================================================

export type EquipValidationResult = {
	success: boolean,
	message: string,
	overloadRisk: boolean,
	corruptionChange: number,
	projectedCorruption: number,
}

export type CorruptionMetrics = {
	corruptionPool: number,
	tolerance: number,
	overloaded: boolean,
	safeCapacity: number,
	percentUsed: number,
}

export type ShardStats = {
	equipped: number,
	totalCorruption: number,
	highestRarity: string,
	totalWeight: number,
	averageLevel: number,
}

-- ============================================================
-- PRIVATE: Validation Helpers
-- ============================================================

local function calculateTolerance(level: number): number
	--!strict
	return math.max(MIN_CORRUPTION_TOLERANCE, level * CORRUPTION_PER_LEVEL)
end

local function isShardValid(shard: PlayerData.Shard): boolean
	--!strict
	if not shard.id or not shard.name then
		return false
	end
	
	if shard.level < 1 or shard.level > MAX_SHARD_LEVEL then
		return false
	end
	
	if shard.corruption < 0 or shard.corruption > 100 then
		return false
	end
	
	if shard.durability < 0 or shard.durability > shard.maxDurability then
		return false
	end
	
	return true
end

local function getShardCorruption(shard: PlayerData.Shard): number
	--!strict
	if not isShardValid(shard) then
		return 0
	end
	
	return shard.corruption
end

-- ============================================================
-- PUBLIC: Validation
-- ============================================================

function ShardEquip.validateEquip(
	profile: PlayerData.PlayerProfile,
	shard: PlayerData.Shard,
	slotIndex: number
): EquipValidationResult
	--!strict
	-- Validate inputs
	if slotIndex < 1 or slotIndex > EQUIPPED_SHARD_SLOTS then
		return {
			success = false,
			message = "Invalid shard slot",
			overloadRisk = false,
			corruptionChange = 0,
			projectedCorruption = profile.corruption,
		}
	end
	
	if not isShardValid(shard) then
		return {
			success = false,
			message = "Invalid shard",
			overloadRisk = false,
			corruptionChange = 0,
			projectedCorruption = profile.corruption,
		}
	end
	
	-- Calculate corruption change
	local currentShard = profile.equippedShards[slotIndex]
	local currentCorruption = currentShard and getShardCorruption(currentShard) or 0
	local newCorruption = getShardCorruption(shard)
	local corruptionChange = newCorruption - currentCorruption
	
	-- Calculate projected corruption
	local projectedCorruption = profile.corruptionPool + corruptionChange
	local tolerance = profile.tolerance
	local overloadRisk = projectedCorruption > tolerance
	
	-- Check for overload
	if overloadRisk then
		return {
			success = false,
			message = string.format(
				"Would cause overload: %d > %d",
				projectedCorruption,
				tolerance
			),
			overloadRisk = true,
			corruptionChange = corruptionChange,
			projectedCorruption = projectedCorruption,
		}
	end
	
	-- Check durability
	if shard.durability <= 0 then
		return {
			success = false,
			message = "Shard durability is too low",
			overloadRisk = false,
			corruptionChange = corruptionChange,
			projectedCorruption = projectedCorruption,
		}
	end
	
	return {
		success = true,
		message = "Shard equipped successfully",
		overloadRisk = false,
		corruptionChange = corruptionChange,
		projectedCorruption = projectedCorruption,
	}
end

function ShardEquip.canEquip(
	profile: PlayerData.PlayerProfile,
	shard: PlayerData.Shard,
	slotIndex: number
): boolean
	--!strict
	local result = ShardEquip.validateEquip(profile, shard, slotIndex)
	return result.success
end

-- ============================================================
-- PUBLIC: Equipment Management
-- ============================================================

function ShardEquip.equipShard(
	profile: PlayerData.PlayerProfile,
	shard: PlayerData.Shard,
	slotIndex: number
): EquipValidationResult
	--!strict
	local result = ShardEquip.validateEquip(profile, shard, slotIndex)
	
	if not result.success then
		return result
	end
	
	-- Equip the shard
	profile.equippedShards[slotIndex] = shard
	
	-- Update corruption pool
	PlayerData.updateCorruptionPool(profile)
	
	return result
end

function ShardEquip.unequipShard(
	profile: PlayerData.PlayerProfile,
	slotIndex: number
): (PlayerData.Shard?, string)
	--!strict
	if slotIndex < 1 or slotIndex > EQUIPPED_SHARD_SLOTS then
		return nil, "Invalid shard slot"
	end
	
	local shard = profile.equippedShards[slotIndex]
	
	if not shard then
		return nil, "No shard equipped in this slot"
	end
	
	profile.equippedShards[slotIndex] = nil
	PlayerData.updateCorruptionPool(profile)
	
	return shard, "Shard unequipped"
end

function ShardEquip.swapShards(
	profile: PlayerData.PlayerProfile,
	shard: PlayerData.Shard,
	slotIndex: number
): (EquipValidationResult, PlayerData.Shard?)
	--!strict
	if slotIndex < 1 or slotIndex > EQUIPPED_SHARD_SLOTS then
		return {
			success = false,
			message = "Invalid shard slot",
			overloadRisk = false,
			corruptionChange = 0,
			projectedCorruption = profile.corruption,
		}, nil
	end
	
	-- Get current shard
	local oldShard = profile.equippedShards[slotIndex]
	
	-- Validate new shard
	local result = ShardEquip.validateEquip(profile, shard, slotIndex)
	
	if not result.success then
		return result, nil
	end
	
	-- Perform swap
	profile.equippedShards[slotIndex] = shard
	PlayerData.updateCorruptionPool(profile)
	
	return result, oldShard
end

function ShardEquip.getEquippedShards(profile: PlayerData.PlayerProfile): { PlayerData.Shard? }
	--!strict
	return profile.equippedShards
end

-- ============================================================
-- PUBLIC: Metrics & Analysis
-- ============================================================

function ShardEquip.calculateCorruptionMetrics(
	profile: PlayerData.PlayerProfile
): CorruptionMetrics
	--!strict
	local corruptionPool = 0
	local tolerance = profile.tolerance
	
	for _, shard in ipairs(profile.equippedShards) do
		if shard then
			corruptionPool += getShardCorruption(shard)
		end
	end
	
	local percentUsed = tolerance > 0 and (corruptionPool / tolerance * 100) or 0
	
	return {
		corruptionPool = corruptionPool,
		tolerance = tolerance,
		overloaded = corruptionPool > tolerance,
		safeCapacity = math.max(0, tolerance - corruptionPool),
		percentUsed = percentUsed,
	}
end

function ShardEquip.getShardStats(profile: PlayerData.PlayerProfile): ShardStats
	--!strict
	local equipped = 0
	local totalCorruption = 0
	local totalWeight = 0
	local totalLevel = 0
	local highestRarity = "Common"
	
	local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	local highestRarityOrder = 0
	
	for _, shard in ipairs(profile.equippedShards) do
		if shard then
			equipped += 1
			totalCorruption += shard.corruption
			totalWeight += shard.durability * 0.1
			totalLevel += shard.level
			
			local rarityVal = rarityOrder[shard.rarity] or 0
			if rarityVal > highestRarityOrder then
				highestRarityOrder = rarityVal
				highestRarity = shard.rarity
			end
		end
	end
	
	return {
		equipped = equipped,
		totalCorruption = totalCorruption,
		highestRarity = highestRarity,
		totalWeight = totalWeight,
		averageLevel = equipped > 0 and (totalLevel / equipped) or 0,
	}
end

function ShardEquip.getCorruptionRiskLevel(profile: PlayerData.PlayerProfile): string
	--!strict
	local metrics = ShardEquip.calculateCorruptionMetrics(profile)
	local percent = metrics.percentUsed
	
	if percent < 25 then
		return "Low"
	elseif percent < 50 then
		return "Moderate"
	elseif percent < 75 then
		return "High"
	elseif percent < 100 then
		return "Critical"
	else
		return "Overloaded"
	end
end

-- ============================================================
-- PUBLIC: Shard Management
-- ============================================================

function ShardEquip.upgradeShardLevel(
	shard: PlayerData.Shard,
	amount: number
): (boolean, string)
	--!strict
	if amount < 1 then
		error("Upgrade amount must be positive", 2)
	end
	
	if shard.level + amount > MAX_SHARD_LEVEL then
		return false, "Would exceed max level"
	end
	
	shard.level += amount
	
	return true, string.format("Shard upgraded to level %d", shard.level)
end

function ShardEquip.reduceDurability(
	shard: PlayerData.Shard,
	amount: number
): (boolean, string)
	--!strict
	if amount < 0 then
		error("Durability amount must be positive", 2)
	end
	
	local oldDurability = shard.durability
	shard.durability = math.max(0, shard.durability - amount)
	
	local message = string.format(
		"Durability reduced from %.1f to %.1f",
		oldDurability,
		shard.durability
	)
	
	if shard.durability == 0 then
		message = message .. " (Shard broken!)"
	end
	
	return true, message
end

function ShardEquip.repairShard(shard: PlayerData.Shard): ()
	--!strict
	shard.durability = shard.maxDurability
end

-- ============================================================
-- PUBLIC: Debugging & Utilities
-- ============================================================

function ShardEquip.printEquippedShards(profile: PlayerData.PlayerProfile): ()
	--!strict
	print("\n=== EQUIPPED SHARDS ===")
	
	for i, shard in ipairs(profile.equippedShards) do
		if shard then
			print(
				string.format(
					"[%d] %s (Lvl %d, %s) - Corruption: %d, Durability: %.1f",
					i,
					shard.name,
					shard.level,
					shard.rarity,
					shard.corruption,
					shard.durability
				)
			)
		else
			print(string.format("[%d] (Empty)", i))
		end
	end
	
	local metrics = ShardEquip.calculateCorruptionMetrics(profile)
	print(
		string.format(
			"\nTotal Corruption: %d/%d (%.1f%%)",
			metrics.corruptionPool,
			metrics.tolerance,
			metrics.percentUsed
		)
	)
	print(string.format("Status: %s", ShardEquip.getCorruptionRiskLevel(profile)))
	print("=======================\n")
end

function ShardEquip.printCorruptionMetrics(profile: PlayerData.PlayerProfile): ()
	--!strict
	local metrics = ShardEquip.calculateCorruptionMetrics(profile)
	
	print("\n=== CORRUPTION METRICS ===")
	print(string.format("Pool: %d", metrics.corruptionPool))
	print(string.format("Tolerance: %d", metrics.tolerance))
	print(string.format("Safe Capacity: %d", metrics.safeCapacity))
	print(string.format("Usage: %.1f%%", metrics.percentUsed))
	print(string.format("Overloaded: %s", metrics.overloaded and "YES" or "NO"))
	print("==========================\n")
end

return ShardEquip
