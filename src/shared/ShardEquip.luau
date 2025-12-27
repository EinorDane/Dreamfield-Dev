--!strict

local PlayerData = require(script.Parent.PlayerData)
local Inventory = require(script.Parent.Inventory)

local ShardEquip = {}

-- ============================================================
-- TYPES
-- ============================================================

export type ShardEquipResult = {
	success: boolean,
	message: string,
	overloadRisk: boolean,
}

export type CorruptionMetrics = {
	corruptionPool: number,
	tolerance: number,
	overloaded: boolean,
	equippedCount: number,
	percentageUsed: number,
}

export type ShardStats = {
	equipped: number,
	totalCorruption: number,
	highestRarity: string,
	averageLevel: number,
}

-- ============================================================
-- PUBLIC: Validation
-- ============================================================

function ShardEquip.validateEquip(profile: PlayerData.PlayerProfile, shard: PlayerData.Shard, slot: number): ShardEquipResult
	--!strict
	if slot < 1 or slot > 5 then
		return {
			success = false,
			message = "Invalid slot: must be 1-5",
			overloadRisk = false,
		}
	end
	
	if not shard then
		return {
			success = false,
			message = "Shard is nil",
			overloadRisk = false,
		}
	end
	
	-- Check if equipping would cause overload
	local currentCorruption = profile.corruptionPool or 0
	local newCorruption = currentCorruption + (shard.corruption or 0)
	local maxAllowed = profile.maxCorruption or 100
	
	if newCorruption > maxAllowed then
		return {
			success = false,
			message = "Shard would cause overload",
			overloadRisk = true,
		}
	end
	
	return {
		success = true,
		message = "Shard can be equipped",
		overloadRisk = false,
	}
end

-- ============================================================
-- PUBLIC: Metrics & Analysis
-- ============================================================

function ShardEquip.calculateCorruptionMetrics(profile: PlayerData.PlayerProfile): CorruptionMetrics
	--!strict
	local totalCorruption = profile.corruptionPool or 0
	local equippedCount = 0
	
	for i = 1, 5 do
		if profile.equippedShards[i] then
			equippedCount += 1
		end
	end
	
	local tolerance = profile.tolerance or (profile.level * 5)
	local overloaded = totalCorruption > tolerance
	
	return {
		corruptionPool = totalCorruption,
		tolerance = tolerance,
		overloaded = overloaded,
		equippedCount = equippedCount,
		percentageUsed = tolerance > 0 and (totalCorruption / tolerance) * 100 or 0,
	}
end

-- ============================================================
-- PUBLIC: Equipping & Unequipping
-- ============================================================

function ShardEquip.equipShard(profile: PlayerData.PlayerProfile, shard: PlayerData.Shard, slot: number): ShardEquipResult
	--!strict
	local validation = ShardEquip.validateEquip(profile, shard, slot)
	
	if not validation.success then
		return validation
	end
	
	-- Update profile
	profile.equippedShards[slot] = shard
	PlayerData.updateCorruptionPool(profile)
	
	return {
		success = true,
		message = "Shard equipped successfully",
		overloadRisk = false,
	}
end

function ShardEquip.unequipShard(profile: PlayerData.PlayerProfile, slot: number): PlayerData.Shard?
	--!strict
	if slot < 1 or slot > 5 then
		return nil
	end
	
	local shard = profile.equippedShards[slot]
	
	if shard then
		profile.equippedShards[slot] = nil
		PlayerData.updateCorruptionPool(profile)
	end
	
	return shard
end

function ShardEquip.swapShards(
	profile: PlayerData.PlayerProfile,
	newShard: PlayerData.Shard,
	slot: number
): (ShardEquipResult, PlayerData.Shard?)
	--!strict
	local oldShard = profile.equippedShards[slot]
	
	local validation = ShardEquip.validateEquip(profile, newShard, slot)
	
	if not validation.success then
		return validation, oldShard
	end
	
	profile.equippedShards[slot] = newShard
	PlayerData.updateCorruptionPool(profile)
	
	return {
		success = true,
		message = "Shards swapped successfully",
		overloadRisk = false,
	}, oldShard
end

-- ============================================================
-- PUBLIC: Shard Maintenance
-- ============================================================

function ShardEquip.upgradeShardLevel(shard: PlayerData.Shard, levels: number): (boolean, string)
	--!strict
	if not shard then
		return false, "Shard is nil"
	end
	
	if levels < 1 or levels > 10 then
		return false, "Levels must be between 1 and 10"
	end
	
	shard.level = shard.level + levels
	
	return true, "Shard upgraded to level " .. tostring(shard.level)
end

function ShardEquip.reduceDurability(shard: PlayerData.Shard, amount: number): (boolean, string)
	--!strict
	if not shard then
		return false, "Shard is nil"
	end
	
	if amount < 0 then
		return false, "Amount must be positive"
	end
	
	shard.durability = math.max(0, shard.durability - amount)
	
	if shard.durability == 0 then
		return true, "Shard durability depleted"
	end
	
	return true, "Durability reduced by " .. tostring(amount)
end

function ShardEquip.repairShard(shard: PlayerData.Shard): (boolean, string)
	--!strict
	if not shard then
		return false, "Shard is nil"
	end
	
	shard.durability = shard.maxDurability or 100
	
	return true, "Shard fully repaired"
end

function ShardEquip.repairShardPartial(shard: PlayerData.Shard, amount: number): (boolean, string)
	--!strict
	if not shard then
		return false, "Shard is nil"
	end
	
	if amount < 0 then
		return false, "Amount must be positive"
	end
	
	local maxDurability = shard.maxDurability or 100
	shard.durability = math.min(maxDurability, shard.durability + amount)
	
	return true, "Shard repaired by " .. tostring(amount)
end

-- ============================================================
-- PUBLIC: Corruption Risk Assessment
-- ============================================================

function ShardEquip.getCorruptionRiskLevel(profile: PlayerData.PlayerProfile): string
	--!strict
	local metrics = ShardEquip.calculateCorruptionMetrics(profile)
	
	if metrics.overloaded then
		return "Critical"
	elseif metrics.percentageUsed >= 75 then
		return "High"
	elseif metrics.percentageUsed >= 50 then
		return "Medium"
	else
		return "Low"
	end
end

function ShardEquip.isOverloadRisk(profile: PlayerData.PlayerProfile): boolean
	--!strict
	local metrics = ShardEquip.calculateCorruptionMetrics(profile)
	return metrics.overloaded
end

function ShardEquip.getOverloadThreshold(profile: PlayerData.PlayerProfile): number
	--!strict
	return profile.tolerance or (profile.level * 5)
end

-- ============================================================
-- PUBLIC: Stats & Information
-- ============================================================

function ShardEquip.getShardStats(profile: PlayerData.PlayerProfile): ShardStats
	--!strict
	local totalCorruption = profile.corruptionPool or 0
	local equippedCount = 0
	local highestRarity = "Common"
	local rarityRank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	
	for i = 1, 5 do
		local shard = profile.equippedShards[i]
		if shard then
			equippedCount += 1
			
			local shardRank = rarityRank[shard.rarity] or 1
			local currentRank = rarityRank[highestRarity] or 1
			
			if shardRank > currentRank then
				highestRarity = shard.rarity
			end
		end
	end
	
	return {
		equipped = equippedCount,
		totalCorruption = totalCorruption,
		highestRarity = highestRarity,
		averageLevel = equippedCount > 0 and math.floor(totalCorruption / equippedCount) or 0,
	}
end

function ShardEquip.getEquippedShards(profile: PlayerData.PlayerProfile): { PlayerData.Shard }
	--!strict
	local equipped = {}
	
	for i = 1, 5 do
		local shard = profile.equippedShards[i]
		if shard then
			table.insert(equipped, shard)
		end
	end
	
	return equipped
end

function ShardEquip.getEmptySlots(profile: PlayerData.PlayerProfile): { number }
	--!strict
	local emptySlots = {}
	
	for i = 1, 5 do
		if not profile.equippedShards[i] then
			table.insert(emptySlots, i)
		end
	end
	
	return emptySlots
end

function ShardEquip.countEquippedShards(profile: PlayerData.PlayerProfile): number
	--!strict
	local count = 0
	
	for i = 1, 5 do
		if profile.equippedShards[i] then
			count += 1
		end
	end
	
	return count
end

-- ============================================================
-- PUBLIC: Shard Information
-- ============================================================

function ShardEquip.getShardInfo(shard: PlayerData.Shard): { [string]: any }
	--!strict
	if not shard then
		return {}
	end
	
	return {
		id = shard.id,
		name = shard.name,
		rarity = shard.rarity,
		corruption = shard.corruption,
		level = shard.level,
		durability = shard.durability,
		maxDurability = shard.maxDurability,
		durabilityPercentage = (shard.durability / (shard.maxDurability or 100)) * 100,
	}
end

function ShardEquip.printShardInfo(shard: PlayerData.Shard): ()
	--!strict
	if not shard then
		print("Shard is nil")
		return
	end
	
	print("\n=== SHARD INFO ===")
	print("Name: " .. shard.name)
	print("Rarity: " .. shard.rarity)
	print("Corruption: " .. tostring(shard.corruption))
	print("Level: " .. tostring(shard.level))
	print("Durability: " .. tostring(shard.durability) .. "/" .. tostring(shard.maxDurability or 100))
	print("==================\n")
end

function ShardEquip.printEquipmentStatus(profile: PlayerData.PlayerProfile): ()
	--!strict
	local metrics = ShardEquip.calculateCorruptionMetrics(profile)
	local stats = ShardEquip.getShardStats(profile)
	local riskLevel = ShardEquip.getCorruptionRiskLevel(profile)
	
	print("\n=== EQUIPMENT STATUS ===")
	print("Equipped Shards: " .. tostring(stats.equipped) .. "/5")
	print("Total Corruption: " .. tostring(stats.totalCorruption) .. "/" .. tostring(metrics.tolerance))
	print("Risk Level: " .. riskLevel)
	print("Highest Rarity: " .. stats.highestRarity)
	print("========================\n")
end

return ShardEquip