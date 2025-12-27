--!strict
--[[
	TIER 1: Complete Test Suite
	
	Comprehensive verification that all foundation systems load correctly
	and pass unit tests. Run in Roblox Studio to validate TIER 1 setup.
	
	File: src/server/QuickTest.server.luau
	Place in ServerScriptService
	Status: Ready to copy-paste
]]

local TestFramework = require(script.Parent.Parent.shared.TestFramework)
local PlayerData = require(script.Parent.Parent.shared.PlayerData)
local Inventory = require(script.Parent.Parent.shared.Inventory)
local ShardEquip = require(script.Parent.Parent.shared.ShardEquip)

-- ============================================================
-- TEST SUITE 1: Module Loading
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
-- TEST SUITE 2: PlayerData Creation & Validation
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
		TestFramework.assertEqual(profile.experience, 100)
		TestFramework.assertEqual(profile.level, 2)
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
		TestFramework.assertEqual(profile.tolerance, 5) -- Level 1 * 5
		
		profile.level = 5
		PlayerData.updateCorruptionPool(profile)
		TestFramework.assertEqual(profile.tolerance, 25) -- Level 5 * 5
	end)
	
	TestFramework.it("manages equipped shards", function()
		local profile = PlayerData.createProfile()
		local shard = Inventory.createShard("fire_1", "Fire Shard", "Common", 15, 1)
		
		PlayerData.equipShard(profile, shard, 1)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
		
		local unequipped = PlayerData.unequipShard(profile, 1)
		TestFramework.assertNotNil(unequipped)
		TestFramework.assertNil(profile.equippedShards[1])
	end)
end)

-- ============================================================
-- TEST SUITE 3: Inventory System
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
		local state = Inventory.createState(25, 5) -- Only 5 lbs capacity
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		-- Sword weighs 3.0 lbs
		
		local success = Inventory.addItem(state, weapon)
		TestFramework.assertTrue(success)
		
		-- Try adding another weapon (would exceed 5 lbs)
		local weapon2 = Inventory.createWeapon("w2", "Axe", "Common", "slash")
		success = Inventory.addItem(state, weapon2)
		TestFramework.assertFalse(success)
	end)
	
	TestFramework.it("respects slot limits", function()
		local state = Inventory.createState(2, 50) -- Only 2 slots
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
-- TEST SUITE 4: Shard Equipping & Corruption
-- ============================================================

TestFramework.describe("ShardEquip", function()
	TestFramework.it("validates shard equipping", function()
		local profile = PlayerData.createProfile()
		local shard = Inventory.createShard("s1", "Fire", "Common", 10, 1)
		
		local result = ShardEquip.validateEquip(profile, shard, 1)
		TestFramework.assertTrue(result.success)
	end)
	
	TestFramework.it("prevents overload", function()
		local profile = PlayerData.createProfile()
		profile.maxCorruption = 50
		
		local shard = Inventory.createShard("s1", "Fire", "Legendary", 60, 1)
		shard.corruption = 60
		
		local result = ShardEquip.validateEquip(profile, shard, 1)
		TestFramework.assertFalse(result.success)
		TestFramework.assertTrue(result.overloadRisk)
	end)
	
	TestFramework.it("calculates corruption metrics", function()
		local profile = PlayerData.createProfile()
		profile.corruptionPool = 0
		profile.level = 2
		
		local metrics = ShardEquip.calculateCorruptionMetrics(profile)
		TestFramework.assertEqual(metrics.corruptionPool, 0)
		TestFramework.assertEqual(metrics.tolerance, 10) -- Level 2 * 5
		TestFramework.assertFalse(metrics.overloaded)
	end)
	
	TestFramework.it("equips shards and updates corruption", function()
		local profile = PlayerData.createProfile()
		local shard = Inventory.createShard("s1", "Fire", "Common", 15, 1)
		
		local result = ShardEquip.equipShard(profile, shard, 1)
		TestFramework.assertTrue(result.success)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
	end)
	
	TestFramework.it("unequips shards", function()
		local profile = PlayerData.createProfile()
		local shard = Inventory.createShard("s1", "Fire", "Common", 15, 1)
		
		ShardEquip.equipShard(profile, shard, 1)
		TestFramework.assertNotNil(profile.equippedShards[1])
		
		local unequipped = ShardEquip.unequipShard(profile, 1)
		TestFramework.assertNotNil(unequipped)
		TestFramework.assertNil(profile.equippedShards[1])
	end)
	
	TestFramework.it("swaps shards between slots", function()
		local profile = PlayerData.createProfile()
		local shard1 = Inventory.createShard("s1", "Fire", "Common", 10, 1)
		local shard2 = Inventory.createShard("s2", "Ice", "Common", 12, 1)
		
		ShardEquip.equipShard(profile, shard1, 1)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
		
		local result, oldShard = ShardEquip.swapShards(profile, shard2, 1)
		TestFramework.assertTrue(result.success)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Ice Shard")
		TestFramework.assertEqual(oldShard.name, "Fire Shard")
	end)
	
	TestFramework.it("upgrades shard level", function()
		local shard = Inventory.createShard("s1", "Fire", "Common", 15, 1)
		TestFramework.assertEqual(shard.level, 1)
		
		local success, message = ShardEquip.upgradeShardLevel(shard, 2)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(shard.level, 3)
	end)
	
	TestFramework.it("reduces shard durability", function()
		local shard = Inventory.createShard("s1", "Fire", "Common", 15, 1)
		TestFramework.assertEqual(shard.durability, 100)
		
		local success, message = ShardEquip.reduceDurability(shard, 25)
		TestFramework.assertTrue(success)
		TestFramework.assertEqual(shard.durability, 75)
	end)
	
	TestFramework.it("repairs shards", function()
		local shard = Inventory.createShard("s1", "Fire", "Common", 15, 1)
		shard.durability = 50
		
		ShardEquip.repairShard(shard)
		TestFramework.assertEqual(shard.durability, 100)
	end)
	
	TestFramework.it("detects corruption risk levels", function()
		local profile = PlayerData.createProfile()
		profile.level = 4
		profile.tolerance = 20
		
		local risk1 = ShardEquip.getCorruptionRiskLevel(profile)
		TestFramework.assertEqual(risk1, "Low")
		
		profile.corruptionPool = 15
		local risk2 = ShardEquip.getCorruptionRiskLevel(profile)
		TestFramework.assertEqual(risk2, "High")
	end)
	
	TestFramework.it("gets equipped shard stats", function()
		local profile = PlayerData.createProfile()
		local shard1 = Inventory.createShard("s1", "Fire", "Rare", 20, 2)
		local shard2 = Inventory.createShard("s2", "Ice", "Epic", 25, 3)
		
		ShardEquip.equipShard(profile, shard1, 1)
		ShardEquip.equipShard(profile, shard2, 2)
		
		local stats = ShardEquip.getShardStats(profile)
		TestFramework.assertEqual(stats.equipped, 2)
		TestFramework.assertEqual(stats.totalCorruption, 45)
		TestFramework.assertEqual(stats.highestRarity, "Epic")
	end)
end)

-- ============================================================
-- TEST SUITE 5: Integration Tests
-- ============================================================

TestFramework.describe("Integration", function()
	TestFramework.it("creates player with full loadout", function()
		local profile = PlayerData.createProfile()
		
		-- Create shards
		local fire = Inventory.createShard("fire_1", "Fire Shard", "Common", 15, 1)
		local ice = Inventory.createShard("ice_1", "Ice Shard", "Common", 12, 1)
		
		-- Equip shards
		ShardEquip.equipShard(profile, fire, 1)
		ShardEquip.equipShard(profile, ice, 2)
		
		-- Verify state
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
		TestFramework.assertEqual(profile.equippedShards[2].name, "Ice Shard")
		
		local metrics = ShardEquip.calculateCorruptionMetrics(profile)
		TestFramework.assertEqual(metrics.corruptionPool, 27)
	end)
	
	TestFramework.it("progresses player through leveling", function()
		local profile = PlayerData.createProfile()
		TestFramework.assertEqual(profile.level, 1)
		
		PlayerData.addExperience(profile, 100)
		TestFramework.assertEqual(profile.level, 2)
		TestFramework.assertEqual(profile.tolerance, 10)
		
		PlayerData.addExperience(profile, 200)
		TestFramework.assertEqual(profile.level, 4)
		TestFramework.assertEqual(profile.tolerance, 20)
	end)
	
	TestFramework.it("manages inventory and equipment together", function()
		local profile = PlayerData.createProfile()
		local inventory = Inventory.createState(25, 50)
		
		-- Create items
		local shard = Inventory.createShard("s1", "Fire", "Common", 10, 1)
		local weapon = Inventory.createWeapon("w1", "Sword", "Common", "slash")
		
		-- Add to inventory
		Inventory.addItem(inventory, shard)
		Inventory.addItem(inventory, weapon)
		
		TestFramework.assertEqual(Inventory.getItemCount(inventory), 2)
		
		-- Equip shard from inventory
		ShardEquip.equipShard(profile, shard, 1)
		TestFramework.assertEqual(profile.equippedShards[1].name, "Fire Shard")
	end)
end)

-- ============================================================
-- RUN ALL TESTS
-- ============================================================

print("\n🚀 Running Tier 1 Verification Tests...\n")
local passed, failed = TestFramework.run()

if failed == 0 then
	print("✅ ALL SYSTEMS OPERATIONAL - Ready for implementation!")
else
	print("⚠️  Some tests failed - Check errors above")
end
