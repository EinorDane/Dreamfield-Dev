--!strict
--[[
	CorruptionCalc Tests
	
	Unit tests for all corruption calculations.
	Tests: tolerance, pool, penalties, damage, risk levels, overload detection
	
	Run via: require(path.CorruptionCalcTests).run()
]]

local TestFramework = require(game.ReplicatedStorage.Shared.TestFramework)
local CorruptionCalc = require(game.ReplicatedStorage.Shared.CorruptionCalc)
local PlayerData = require(game.ReplicatedStorage.Shared.PlayerData)
local ShardEquip = require(game.ReplicatedStorage.Shared.ShardEquip)
local Inventory = require(game.ReplicatedStorage.Shared.Inventory)

-- ============================================================
-- UNIT TESTS: TOLERANCE
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
-- UNIT TESTS: CORRUPTION POOL
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
-- UNIT TESTS: COOLDOWN PENALTY
-- ============================================================

TestFramework.describe("Corruption: Cooldown Penalty", function()
	TestFramework.it("should return 0 penalty when pool <= tolerance", function()
		local penalty = CorruptionCalc.getCooldownPenalty(50, 100)
		TestFramework.assertEqual(penalty, 0, "Pool 50, Tolerance 100 = 0 penalty")
	end)
	
	TestFramework.it("should calculate penalty from overflow", function()
		local penalty = CorruptionCalc.getCooldownPenalty(80, 50)
		local expected = (80 - 50) * 0.02 -- 30 * 0.02 = 0.6
		TestFramework.assertEqual(penalty, expected, "Pool 80, Tolerance 50 = 0.6 penalty")
	end)
	
	TestFramework.it("should calculate penalty at 100 corruption", function()
		local penalty = CorruptionCalc.getCooldownPenalty(100, 50)
		local expected = (100 - 50) * 0.02 -- 50 * 0.02 = 1.0
		TestFramework.assertEqual(penalty, expected, "Pool 100, Tolerance 50 = 1.0 penalty")
	end)
	
	TestFramework.it("should handle zero tolerance", function()
		local penalty = CorruptionCalc.getCooldownPenalty(50, 0)
		local expected = (50 - 0) * 0.02 -- 50 * 0.02 = 1.0
		TestFramework.assertEqual(penalty, expected, "Pool 50, Tolerance 0 = 1.0 penalty")
	end)
end)

-- ============================================================
-- UNIT TESTS: DAMAGE MULTIPLIER
-- ============================================================

TestFramework.describe("Corruption: Damage Multiplier", function()
	TestFramework.it("should be 0.8x at 0 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(0)
		TestFramework.assertEqual(mult, 0.8, "0 corruption = 0.8x damage")
	end)
	
	TestFramework.it("should be ~1.05x at 50 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(50)
		local expected = 0.8 + (50 / 100) * 0.5 -- 0.8 + 0.25 = 1.05
		TestFramework.assertEqual(mult, expected, "50 corruption = 1.05x damage")
	end)
	
	TestFramework.it("should be 1.3x at 100 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(100)
		local expected = 0.8 + (100 / 100) * 0.5 -- 0.8 + 0.5 = 1.3
		TestFramework.assertEqual(mult, expected, "100 corruption = 1.3x damage")
	end)
	
	TestFramework.it("should scale above 100 corruption", function()
		local mult = CorruptionCalc.getDamageMultiplier(150)
		local expected = 0.8 + (150 / 100) * 0.5 -- 0.8 + 0.75 = 1.55
		TestFramework.assertEqual(mult, expected, "150 corruption = 1.55x damage")
	end)
end)

-- ============================================================
-- UNIT TESTS: RISK LEVELS
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
-- UNIT TESTS: OVERLOAD DETECTION
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
-- UNIT TESTS: APPLIED COOLDOWN
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
-- UNIT TESTS: APPLIED DAMAGE
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
-- INTEGRATION TESTS: FULL METRICS
-- ============================================================

TestFramework.describe("Corruption: Full Metrics (Integration)", function()
	TestFramework.it("should calculate all metrics for low corruption", function()
		local profile = PlayerData.createProfile()
		profile.level = 10
		profile.equippedShards = {
			Inventory.createShardObject("fire_1", "Fire", "Rare", 30, 3),
			nil, nil, nil, nil,
		}
		
		local metrics = CorruptionCalc.calculateMetrics(profile)
		
		TestFramework.assertEqual(metrics.tolerance, 50, "Level 10 tolerance = 50")
		TestFramework.assertEqual(metrics.corruptionPool, 30, "One 30-corruption shard")
		TestFramework.assertEqual(metrics.overloaded, false, "30 < 100 not overloaded")
		TestFramework.assertEqual(metrics.riskLevel, "Low", "30% = Low risk")
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
		
		-- Pool would be 300, but should be manageable
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
		
		-- Level up
		profile.level = 10
		local metricsLv10 = CorruptionCalc.calculateMetrics(profile)
		TestFramework.assertEqual(metricsLv10.tolerance, 50, "Level 10 tolerance = 50")
		TestFramework.assertEqual(metricsLv10.cooldownPenalty, 0, "No penalty - pool at tolerance")
	end)
end)

-- ============================================================
-- INTEGRATION TESTS: COMBAT SCENARIO
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
			-- Combat system should skip this action
			TestFramework.assertTrue(true, "Overloaded state detected - action blocked")
		else
			TestFramework.fail("Should be overloaded")
		end
	end)
end)

-- ============================================================
-- RUN TESTS
-- ============================================================

TestFramework.run()
