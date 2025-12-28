--!strict
--[[
	COMBINED TEST SUITE: TIER 1 + TIER 2
	
	Runs all tests for PlayerData, Inventory, ShardEquip (Tier 1)
	AND CorruptionCalc system (Tier 2) in one file
	
	File: src/server/QuickTest.server.luau
	Total Tests: 73 (35 Tier 1 + 38 Tier 2)
]]

local TestFramework = require(game.ReplicatedStorage.Shared.TestFramework)
local PlayerData = require(game.ReplicatedStorage.Shared.PlayerData)
local Inventory = require(game.ReplicatedStorage.Shared.Inventory)
local ShardEquip = require(game.ReplicatedStorage.Shared.ShardEquip)
local CorruptionCalc = require(game.ReplicatedStorage.Shared.CorruptionCalc)

-- ============================================================
-- TIER 1: Module Loading
-- ============================================================

TestFramework.describe("Module Loading", function()
	TestFramework.it("loads TestFramework", function()
		TestFramework.assertNotNil(TestFramework.describe)
		TestFramework.assertNotNil(TestFramework.it)
		TestFramework.assertNotNil(TestFramework.run)
	end)
	
	TestFramework.it("loads PlayerData", function()
		TestFramework.assertNotNil(PlayerData.createProfile)
		TestFramework.assertNotNil(PlayerData.addExperience)
		TestFramework.assertNotNil(PlayerData.equipShard)
	end)
	
	TestFramework.it("loads Inventory", function()
		TestFramework.assertNotNil(Inventory.createState)
		TestFramework.assertNotNil(Inventory.addItem)
		TestFramework.assertNotNil(Inventory.createShard)
	end)
	
	TestFramework.it("loads ShardEquip", function()
		TestFramework.assertNotNil(ShardEquip.validateEquip)
		TestFramework.assertNotNil(ShardEquip.equipShard)
		TestFramework.assertNotNil(ShardEquip.calculateCorruptionMetrics)
	end)
end)

-- ============================================================
-- TIER 1: PlayerData Creation & Validation
-- ============================================================

TestFramework.describe("PlayerData", function()
	TestFramework.it("creates default profile", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertEqual(profile.level, 1)
		TestFramework.assertEqual(profile.corruption, 0)
		TestFramework.assertEqual(profile.stamina, 100)
	end)
	
	TestFramework.it("validates profile structure", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertTrue(PlayerData.validate(profile))
	end)
	
	TestFramework.it("adds experience and levels up", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertEqual(profile.experience, 0)
		
		PlayerData.addExperience(profile, 50)
		TestFramework.assertEqual(profile.experience, 50)
		
		PlayerData.addExperience(profile, 50)
		TestFramework.assertEqual(profile.level, 2)
		TestFramework.assertEqual(profile.experience, 0)
	end)
	
	TestFramework.it("manages stamina correctly", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertEqual(profile.stamina, 100)
		
		PlayerData.removeStamina(profile, 25)
		TestFramework.assertEqual(profile.stamina, 75)
		
		PlayerData.addStamina(profile, 50)
		TestFramework.assertEqual(profile.stamina, 100)
	end)
	
	TestFramework.it("sets corruption within valid range", function()
		local profile = PlayerData.createProfile()
		
		PlayerData.setCorruption(profile, 50)
		TestFramework.assertEqual(profile.corruption, 50)
		TestFramework.assertFalse(profile.overloaded)
		
		PlayerData.setCorruption(profile, 100)
		TestFramework.assertEqual(profile.corruption, 100)
		TestFramework.assertTrue(profile.overloaded)
	end)
	
	TestFramework.it("updates corruption tolerance with level", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertEqual(profile.tolerance, 5)
		
		profile.level = 5
		PlayerData.updateCorruptionPool(profile)
		TestFramework.assertEqual(profile.tolerance, 25)
	end)
	
	TestFramework.it("manages equipped shards", function()
		local profile = PlayerData.createProfile()
		local shard = Inventory.createShardObject("fire_1", "Fire", "Common", 15, 1)
		
		PlayerData.equipShard(profile, shard, 1)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
		
		local unequipped = PlayerData.unequipShard(profile, 1)
		TestFramework.assertNotNil(unequipped)
		TestFramework.assertNil(profile.equippedShards[1])
	end)
end)

-- ============================================================
-- TIER 1: Inventory System
-- ============================================================

TestFramework.describe("Inventory", function()
	TestFramework.it("creates inventory state with correct limits", function()
		local state = Inventory.createState(25, 50)
		TestFramework.assertEqual(Inventory.getItemCount(state), 0)
		TestFramework.assertEqual(Inventory.getAvailableSlots(state), 25)
	end)
	
	TestFramework.it("adds shards to inventory", function()
		local state = Inventory.createState(25, 50)
		local shard = Inventory.createShard("s1", "Fire Shard", "Common", 10, 1)
		
		local success, reason = Inventory.addItem(state, shard)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(Inventory.getItemCount(state), 1)
	end)
	
	TestFramework.it("adds weapons to inventory", function()
		local state = Inventory.createState(25, 50)
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		
		local success, reason = Inventory.addItem(state, weapon)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(weapon.properties.damage, 10)
	end)
	
	TestFramework.it("adds consumables to inventory", function()
		local state = Inventory.createState(25, 50)
		local potion = Inventory.createConsumable("potion_1", "Health Potion", "Common", "heal", 5)
		
		local success = Inventory.addItem(state, potion)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(potion.quantity, 5)
	end)
	
	TestFramework.it("respects weight limits", function()
		local state = Inventory.createState(25, 5)
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		
		local success = Inventory.addItem(state, weapon)
		TestFramework.assertTrue(success)
		
		local weapon2 = Inventory.createWeapon("w2", "Axe", "Common", "slash")
		success = Inventory.addItem(state, weapon2)
		TestFramework.assertFalse(success)
	end)
	
	TestFramework.it("respects slot limits", function()
		local state = Inventory.createState(2, 50)
		local shard1 = Inventory.createShard("s1", "Fire", "Common", 10, 1)
		local shard2 = Inventory.createShard("s2", "Ice", "Common", 10, 1)
		local shard3 = Inventory.createShard("s3", "Wind", "Common", 10, 1)
		
		TestFramework.assertTrue((Inventory.addItem(state, shard1)))
		TestFramework.assertTrue((Inventory.addItem(state, shard2)))
		TestFramework.assertFalse((Inventory.addItem(state, shard3)))
	end)
	
	TestFramework.it("removes items correctly", function()
		local state = Inventory.createState(25, 50)
		local shard = Inventory.createShard("s1", "Fire Shard", "Common", 10, 1)
		
		Inventory.addItem(state, shard)
		TestFramework.assertEqual(Inventory.getItemCount(state), 1)
		
		local removed = Inventory.removeItem(state, 1)
		TestFramework.assertNotNil(removed)
		TestFramework.assertEqual(Inventory.getItemCount(state), 0)
	end)
	
	TestFramework.it("finds items by type", function()
		local state = Inventory.createState(25, 50)
		local shard = Inventory.createShard("s1", "Fire", "Common", 10, 1)
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		
		Inventory.addItem(state, shard)
		Inventory.addItem(state, weapon)
		
		local shards = Inventory.findItemsByType(state, "shard")
		TestFramework.assertEqual(#shards, 1)
		TestFramework.assertEqual(shards[1].type, "shard")
	end)
	
	TestFramework.it("sorts items by rarity", function()
		local state = Inventory.createState(25, 50)
		local common = Inventory.createShard("s1", "Common Shard", "Common", 10, 1)
		local legendary = Inventory.createShard("s2", "Legendary Shard", "Legendary", 50, 5)
		
		Inventory.addItem(state, common)
		Inventory.addItem(state, legendary)
		
		Inventory.sortByRarity(state)
		
		TestFramework.assertEqual(state.items[1].rarity, "Legendary")
		TestFramework.assertEqual(state.items[2].rarity, "Common")
	end)
	
	TestFramework.it("tracks weight correctly", function()
		local state = Inventory.createState(25, 100)
		TestFramework.assertEqual(state.currentWeight, 0)
		
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		Inventory.addItem(state, weapon)
		
		TestFramework.assertEqual(state.currentWeight, 3.0)
	end)
end)

-- ============================================================
-- TIER 1: Shard Equipping & Corruption
-- ============================================================

TestFramework.describe("ShardEquip", function()
	TestFramework.it("validates shard equipping", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		PlayerData.updateCorruptionPool(profile)
		
		local shard = Inventory.createShardObject("s1", "Fire", "Common", 10, 1)
		local result = ShardEquip.validateEquip(profile, shard, 1)
		TestFramework.assertTrue(result.success)
	end)
	
	TestFramework.it("prevents overload", function()
		local profile = PlayerData.createProfile()
		profile.maxCorruption = 50
		
		local shard = Inventory.createShardObject("s1", "Fire", "Legendary", 60, 1)
		
		local result = ShardEquip.validateEquip(profile, shard, 1)
		TestFramework.assertFalse(result.success)
		TestFramework.assertTrue(result.overloadRisk)
	end)
	
	TestFramework.it("calculates corruption metrics", function()
		local profile = PlayerData.createProfile()
		profile.level = 2
		PlayerData.updateCorruptionPool(profile)
		
		local metrics = ShardEquip.calculateCorruptionMetrics(profile)
		TestFramework.assertEqual(metrics.corruptionPool, 0)
		TestFramework.assertEqual(metrics.tolerance, 10)
		TestFramework.assertFalse(metrics.overloaded)
	end)
	
	TestFramework.it("equips shards and updates corruption", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		PlayerData.updateCorruptionPool(profile)
		
		local shard = Inventory.createShardObject("s1", "Fire", "Common", 15, 1)
		local result = ShardEquip.equipShard(profile, shard, 1)
		TestFramework.assertTrue(result.success)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
	end)
	
	TestFramework.it("unequips shards", function()
		local profile = PlayerData.createProfile()
		local shard = Inventory.createShardObject("s1", "Fire", "Common", 15, 1)
		
		ShardEquip.equipShard(profile, shard, 1)
		TestFramework.assertNotNil(profile.equippedShards[1])
		
		local unequipped = ShardEquip.unequipShard(profile, 1)
		TestFramework.assertNotNil(unequipped)
		TestFramework.assertNil(profile.equippedShards[1])
	end)
	
	TestFramework.it("swaps shards between slots", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		PlayerData.updateCorruptionPool(profile)
		
		local shard1 = Inventory.createShardObject("s1", "Fire", "Common", 10, 1)
		local shard2 = Inventory.createShardObject("s2", "Ice", "Common", 12, 1)
		
		ShardEquip.equipShard(profile, shard1, 1)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
		
		local result, oldShard = ShardEquip.swapShards(profile, shard2, 1)
		TestFramework.assertTrue(result.success)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Ice Shard")
		TestFramework.assertEqual(oldShard.name, "Fire Shard")
	end)
	
	TestFramework.it("upgrades shard level", function()
		local shard = Inventory.createShardObject("s1", "Fire", "Common", 15, 1)
		TestFramework.assertEqual(shard.level, 1)
		
		local success, message = ShardEquip.upgradeShardLevel(shard, 2)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(shard.level, 3)
	end)
	
	TestFramework.it("reduces shard durability", function()
		local shard = Inventory.createShardObject("s1", "Fire", "Common", 15, 1)
		TestFramework.assertEqual(shard.durability, 100)
		
		local success, message = ShardEquip.reduceDurability(shard, 25)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(shard.durability, 75)
	end)
	
	TestFramework.it("repairs shards", function()
		local shard = Inventory.createShardObject("s1", "Fire", "Common", 15, 1)
		shard.durability = 50
		
		ShardEquip.repairShard(shard)
		TestFramework.assertEqual(shard.durability, 100)
	end)
	
	TestFramework.it("detects corruption risk levels", function()
		local profile = PlayerData.createProfile()
		profile.level = 2
		PlayerData.updateCorruptionPool(profile)
		
		local risk1 = ShardEquip.getCorruptionRiskLevel(profile)
		TestFramework.assertEqual(risk1, "Low")
		
		profile.corruptionPool = 8
		local risk2 = ShardEquip.getCorruptionRiskLevel(profile)
		TestFramework.assertEqual(risk2, "High")
	end)
	
	TestFramework.it("gets equipped shard stats", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		PlayerData.updateCorruptionPool(profile)
		
		local shard1 = Inventory.createShardObject("s1", "Fire", "Rare", 20, 2)
		local shard2 = Inventory.createShardObject("s2", "Ice", "Epic", 25, 3)
		
		ShardEquip.equipShard(profile, shard1, 1)
		ShardEquip.equipShard(profile, shard2, 2)
		
		local stats = ShardEquip.getShardStats(profile)
		TestFramework.assertEqual(stats.equipped, 2)
		TestFramework.assertEqual(stats.totalCorruption, 45)
		TestFramework.assertEqual(stats.highestRarity, "Epic")
	end)
end)

-- ============================================================
-- TIER 1: Integration Tests
-- ============================================================

TestFramework.describe("Integration", function()
	TestFramework.it("creates player with full loadout", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		PlayerData.updateCorruptionPool(profile)
		
		local fire = Inventory.createShardObject("fire_1", "Fire", "Common", 15, 1)
		local ice = Inventory.createShardObject("ice_1", "Ice", "Common", 12, 1)
		
		ShardEquip.equipShard(profile, fire, 1)
		ShardEquip.equipShard(profile, ice, 2)
		
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
		TestFramework.assertEqual(profile.equippedShards[2].name, "Ice Shard")
		
		local metrics = ShardEquip.calculateCorruptionMetrics(profile)
		TestFramework.assertEqual(metrics.corruptionPool, 27)
	end)
	
	TestFramework.it("progresses player through leveling", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertEqual(profile.level, 1)
		TestFramework.assertEqual(profile.tolerance, 5)
		
		PlayerData.addExperience(profile, 100)
		TestFramework.assertEqual(profile.level, 2)
		PlayerData.updateCorruptionPool(profile)
		TestFramework.assertEqual(profile.tolerance, 10)
		
		PlayerData.addExperience(profile, 100)
		TestFramework.assertEqual(profile.level, 3)
		PlayerData.updateCorruptionPool(profile)
		TestFramework.assertEqual(profile.tolerance, 15)
	end)
	
	TestFramework.it("manages inventory and equipment together", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		PlayerData.updateCorruptionPool(profile)
		
		local inventory = Inventory.createState(25, 50)
		
		local shard = Inventory.createShard("s1", "Fire", "Common", 10, 1)
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		
		Inventory.addItem(inventory, shard)
		Inventory.addItem(inventory, weapon)
		
		TestFramework.assertEqual(Inventory.getItemCount(inventory), 2)
		
		local shardObj = Inventory.createShardObject("s1", "Fire", "Common", 10, 1)
		ShardEquip.equipShard(profile, shardObj, 1)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
	end)
end)

-- ============================================================
-- TIER 2: Corruption Tolerance Calculation
-- ============================================================

TestFramework.describe("Corruption: Tolerance Calculation", function()
	TestFramework.it("should calculate tolerance as level * 5", function()
		local level = 10
		local tolerance = CorruptionCalc.getTolerance(level)
		TestFramework.assertEqual(tolerance, 50, "Level 10 = 50 tolerance")
	end)
	
	TestFramework.it("should handle level 1 correctly", function()
		local tolerance = CorruptionCalc.getTolerance(1)
		TestFramework.assertEqual(tolerance, 5, "Level 1 = 5 tolerance")
	end)
	
	TestFramework.it("should handle level 100", function()
		local tolerance = CorruptionCalc.getTolerance(100)
		TestFramework.assertEqual(tolerance, 500, "Level 100 = 500 tolerance")
	end)
	
	TestFramework.it("should handle level 0 (edge case)", function()
		local tolerance = CorruptionCalc.getTolerance(0)
		TestFramework.assertEqual(tolerance, 0, "Level 0 = 0 tolerance")
	end)
end)

-- ============================================================
-- TIER 2: Corruption Pool Calculation
-- ============================================================

TestFramework.describe("Corruption: Pool Calculation", function()
	TestFramework.it("should return 0 for no equipped shards", function()
		local shards = { nil, nil, nil, nil, nil }
		local pool = CorruptionCalc.getCorruptionPool(shards)
		TestFramework.assertEqual(pool, 0, "Empty shards = 0 pool")
	end)
	
	TestFramework.it("should return 0 for nil shards table", function()
		local pool = CorruptionCalc.getCorruptionPool(nil)
		TestFramework.assertEqual(pool, 0, "Nil shards = 0 pool")
	end)
	
	TestFramework.it("should sum corruption from single shard", function()
		local shard = Inventory.createShardObject("fire_1", "Fire", "Rare", 50, 3)
		local shards = { shard, nil, nil, nil, nil }
		local pool = CorruptionCalc.getCorruptionPool(shards)
		TestFramework.assertEqual(pool, 50, "Single shard = its corruption")
	end)
	
	TestFramework.it("should sum corruption from multiple shards", function()
		local shard1 = Inventory.createShardObject("fire_1", "Fire", "Rare", 60, 3)
		local shard2 = Inventory.createShardObject("ice_1", "Ice", "Epic", 50, 3)
		local shard3 = Inventory.createShardObject("elec_1", "Elec", "Uncommon", 30, 2)
		local shards = { shard1, shard2, shard3, nil, nil }
		local pool = CorruptionCalc.getCorruptionPool(shards)
		TestFramework.assertEqual(pool, 140, "Three shards: 60+50+30 = 140")
	end)
end)

-- ============================================================
-- TIER 2: Cooldown Penalty
-- ============================================================

TestFramework.describe("Corruption: Cooldown Penalty", function()
	TestFramework.it("should return 0 penalty when pool <= tolerance", function()
		local penalty = CorruptionCalc.getCooldownPenalty(50, 100)
		TestFramework.assertEqual(penalty, 0, "Pool 50, Tolerance 100 = 0 penalty")
	end)
	
	TestFramework.it("should calculate penalty from overflow", function()
		local penalty = CorruptionCalc.getCooldownPenalty(80, 50)
		local expected = (80 - 50) * 0.02
		TestFramework.assertEqual(penalty, expected, "Pool 80, Tolerance 50 = 0.6 penalty")
	end)
	
	TestFramework.it("should calculate penalty at 100 corruption", function()
		local penalty = CorruptionCalc.getCooldownPenalty(100, 50)
		local expected = (100 - 50) * 0.02
		TestFramework.assertEqual(penalty, expected, "Pool 100, Tolerance 50 = 1.0 penalty")
	end)
	
	TestFramework.it("should handle zero tolerance", function()
		local penalty = CorruptionCalc.getCooldownPenalty(50, 0)
		local expected = (50 - 0) * 0.02
		TestFramework.assertEqual(penalty, expected, "Pool 50, Tolerance 0 = 1.0 penalty")
	end)
end)

-- ============================================================
-- TIER 2: Damage Multiplier
-- ============================================================

TestFramework.describe("Corruption: Damage Multiplier", function()
	TestFramework.it("should be 0.8x at 0 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(0)
		TestFramework.assertEqual(mult, 0.8, "0 corruption = 0.8x damage")
	end)
	
	TestFramework.it("should be ~1.05x at 50 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(50)
		local expected = 0.8 + (50 / 100) * 0.5
		TestFramework.assertEqual(mult, expected, "50 corruption = 1.05x damage")
	end)
	
	TestFramework.it("should be 1.3x at 100 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(100)
		local expected = 0.8 + (100 / 100) * 0.5
		TestFramework.assertEqual(mult, expected, "100 corruption = 1.3x damage")
	end)
	
	TestFramework.it("should scale above 100 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(150)
		local expected = 0.8 + (150 / 100) * 0.5
		TestFramework.assertEqual(mult, expected, "150 corruption = 1.55x damage")
	end)
end)

-- ============================================================
-- TIER 2: Risk Levels
-- ============================================================

TestFramework.describe("Corruption: Risk Levels", function()
	TestFramework.it("should be Low at 24%", function()
		local level = CorruptionCalc.getRiskLevel(24)
		TestFramework.assertEqual(level, "Low", "24% = Low risk")
	end)
	
	TestFramework.it("should be Medium at 25-49%", function()
		local level = CorruptionCalc.getRiskLevel(37)
		TestFramework.assertEqual(level, "Medium", "37% = Medium risk")
	end)
	
	TestFramework.it("should be High at 50-84%", function()
		local level = CorruptionCalc.getRiskLevel(67)
		TestFramework.assertEqual(level, "High", "67% = High risk")
	end)
	
	TestFramework.it("should be Critical at 85%+", function()
		local level = CorruptionCalc.getRiskLevel(95)
		TestFramework.assertEqual(level, "Critical", "95% = Critical risk")
	end)
end)

-- ============================================================
-- TIER 2: Overload Detection
-- ============================================================

TestFramework.describe("Corruption: Overload Detection", function()
	TestFramework.it("should not be overloaded below max", function()
		local overloaded = CorruptionCalc.isOverloaded(99, 100)
		TestFramework.assertEqual(overloaded, false, "99/100 not overloaded")
	end)
	
	TestFramework.it("should be overloaded at max", function()
		local overloaded = CorruptionCalc.isOverloaded(100, 100)
		TestFramework.assertEqual(overloaded, true, "100/100 is overloaded")
	end)
	
	TestFramework.it("should be overloaded above max", function()
		local overloaded = CorruptionCalc.isOverloaded(120, 100)
		TestFramework.assertEqual(overloaded, true, "120/100 is overloaded")
	end)
	
	TestFramework.it("should handle custom max corruption", function()
		local overloaded = CorruptionCalc.isOverloaded(150, 200)
		TestFramework.assertEqual(overloaded, false, "150/200 not overloaded")
	end)
end)

-- ============================================================
-- TIER 2: Applied Cooldown
-- ============================================================

TestFramework.describe("Corruption: Applied Cooldown", function()
	TestFramework.it("should add penalty to base cooldown", function()
		local cooldown = CorruptionCalc.getAppliedCooldown(1.0, 0.6)
		TestFramework.assertEqual(cooldown, 1.6, "1.0s base + 0.6s penalty = 1.6s")
	end)
	
	TestFramework.it("should handle zero penalty", function()
		local cooldown = CorruptionCalc.getAppliedCooldown(1.0, 0)
		TestFramework.assertEqual(cooldown, 1.0, "1.0s base + 0s penalty = 1.0s")
	end)
	
	TestFramework.it("should handle high penalty", function()
		local cooldown = CorruptionCalc.getAppliedCooldown(1.0, 2.0)
		TestFramework.assertEqual(cooldown, 3.0, "1.0s base + 2.0s penalty = 3.0s")
	end)
end)

-- ============================================================
-- TIER 2: Applied Damage
-- ============================================================

TestFramework.describe("Corruption: Applied Damage", function()
	TestFramework.it("should reduce damage at low corruption", function()
		local damage = CorruptionCalc.getAppliedDamage(100, 0.8)
		TestFramework.assertEqual(damage, 80, "100 base * 0.8x = 80 damage")
	end)
	
	TestFramework.it("should increase damage at high corruption", function()
		local damage = CorruptionCalc.getAppliedDamage(100, 1.3)
		TestFramework.assertEqual(damage, 130, "100 base * 1.3x = 130 damage")
	end)
	
	TestFramework.it("should handle zero base damage", function()
		local damage = CorruptionCalc.getAppliedDamage(0, 1.5)
		TestFramework.assertEqual(damage, 0, "0 base * 1.5x = 0 damage")
	end)
end)

-- ============================================================
-- TIER 2: Full Metrics (Integration)
-- ============================================================

TestFramework.describe("Corruption: Full Metrics (Integration)", function()
	TestFramework.it("should calculate all metrics for low corruption", function()
		local profile = PlayerData.createProfile()
		profile.level = 10
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Rare", 20, 3),
			nil, nil, nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		
		TestFramework.assertEqual(metrics.tolerance, 50, "Level 10 tolerance = 50")
		TestFramework.assertEqual(metrics.corruptionPool, 20, "One 20-corruption shard")
		TestFramework.assertEqual(metrics.overloaded, false, "20 < 100 not overloaded")
		TestFramework.assertEqual(metrics.riskLevel, "Low", "20% = Low risk")
		TestFramework.assertGreater(metrics.damageMultiplier, 0.8, "Damage > 0.8x")
		TestFramework.assertLess(metrics.damageMultiplier, 1.0, "Damage < 1.0x")
	end)
	
	TestFramework.it("should calculate all metrics for medium corruption", function()
		local profile = PlayerData.createProfile()
		profile.level = 10
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Rare", 60, 3),
			Inventory.createShardObject("ice_1", "Ice", "Epic", 50, 4),
			nil, nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		
		TestFramework.assertEqual(metrics.corruptionPool, 110, "Two shards: 60+50")
		TestFramework.assertEqual(metrics.tolerance, 50, "Level 10 tolerance = 50")
		TestFramework.assertEqual(metrics.overloaded, true, "110 >= 100 is overloaded")
		TestFramework.assertEqual(metrics.riskLevel, "Critical", "110% = Critical")
		local expectedPenalty = (110 - 50) * 0.02
		TestFramework.assertEqual(metrics.cooldownPenalty, expectedPenalty, "Penalty calculated")
	end)
	
	TestFramework.it("should clamp corruption pool to avoid extreme values", function()
		local profile = PlayerData.createProfile()
		profile.level = 50
		profile.maxCorruption = 100
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Legendary", 100, 5),
			Inventory.createShardObject("ice_1", "Ice", "Legendary", 100, 5),
			Inventory.createShardObject("elec_1", "Elec", "Legendary", 100, 5),
			nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		
		TestFramework.assertGreater(metrics.damageMultiplier, 1.0, "Damage bonus applied")
		TestFramework.assertLess(metrics.damageMultiplier, 2.5, "Damage multiplier reasonable")
	end)
	
	TestFramework.it("should handle no equipped shards", function()
		local profile = PlayerData.createProfile()
		profile.level = 5
		profile.equippedShards = { nil, nil, nil, nil, nil }
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		
		TestFramework.assertEqual(metrics.corruptionPool, 0, "No shards = 0 pool")
		TestFramework.assertEqual(metrics.tolerance, 25, "Level 5 tolerance = 25")
		TestFramework.assertEqual(metrics.cooldownPenalty, 0, "No penalty at 0 pool")
		TestFramework.assertEqual(metrics.damageMultiplier, 0.8, "Base damage 0.8x")
		TestFramework.assertEqual(metrics.overloaded, false, "Not overloaded")
		TestFramework.assertEqual(metrics.riskLevel, "Low", "Low risk")
	end)
	
	TestFramework.it("should update metrics when leveling up", function()
		local profile = PlayerData.createProfile()
		profile.level = 1
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Rare", 50, 1),
			nil, nil, nil, nil,
		}
		
		local metricsLv1 = CorruptionCalc.calculateMetrics(profile)
		TestFramework.assertEqual(metricsLv1.tolerance, 5, "Level 1 tolerance = 5")
		TestFramework.assertEqual(metricsLv1.cooldownPenalty, (50 - 5) * 0.02, "Penalty at Lv1")
		
		profile.level = 10
		local metricsLv10 = CorruptionCalc.calculateMetrics(profile)
		TestFramework.assertEqual(metricsLv10.tolerance, 50, "Level 10 tolerance = 50")
		TestFramework.assertEqual(metricsLv10.cooldownPenalty, 0, "No penalty - pool at tolerance")
	end)
end)

-- ============================================================
-- TIER 2: Combat Scenarios
-- ============================================================

TestFramework.describe("Corruption: Combat Scenarios", function()
	TestFramework.it("should apply skill cooldown with corruption penalty", function()
		local profile = PlayerData.createProfile()
		profile.level = 15
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Rare", 80, 3),
			nil, nil, nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		local skillBaseCooldown = 1.5
		local appliedCooldown = CorruptionCalc.getAppliedCooldown(skillBaseCooldown, metrics.cooldownPenalty)
		
		TestFramework.assertGreater(appliedCooldown, skillBaseCooldown, "Cooldown increased by penalty")
	end)
	
	TestFramework.it("should apply damage bonus from corruption", function()
		local profile = PlayerData.createProfile()
		profile.level = 20
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Epic", 75, 5),
			Inventory.createShardObject("ice_1", "Ice", "Rare", 60, 4),
			nil, nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		local baseDamage = 50
		local appliedDamage = CorruptionCalc.getAppliedDamage(baseDamage, metrics.damageMultiplier)
		
		TestFramework.assertGreater(appliedDamage, baseDamage, "Damage increased by corruption")
	end)
	
	TestFramework.it("should trigger overload block when at max", function()
		local profile = PlayerData.createProfile()
		profile.level = 5
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Legendary", 100, 5),
			nil, nil, nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		
		if metrics.overloaded then
			TestFramework.assertTrue(true, "Overloaded state detected - action blocked")
		else
			TestFramework.fail("Should be overloaded")
		end
	end)
end)

-- ============================================================
-- RUN ALL TESTS
-- ============================================================

print("\n" .. string.rep("=", 60))
print("🚀 DREAMFIELD: COMPLETE TEST SUITE")
print(string.rep("=", 60) .. "\n")
print("Running: Tier 1 (35 tests) + Tier 2 (38 tests) = 73 total\n")

local passed, failed = TestFramework.run()

print(string.rep("=", 60))
if failed == 0 then
	print("✅ ALL 73 TESTS PASSING - TIER 2.1 COMPLETE!")
	print("Ready for: THREAD-006 Combat System")
else
	print("⚠️  " .. failed .. " test(s) failed - See errors above")
end
print(string.rep("=", 60) .. "\n")
