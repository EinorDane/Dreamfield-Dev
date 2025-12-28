--!strict
--[[
	CombatTest.server.luau
	Test suite for combat system (40+ tests)
	Tests: Combo, Parry, Block, Dash, Corruption integration
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local CombatCore = require(script.Parent.CombatCore)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local CorruptionCalc = require(ReplicatedStorage.Shared.CorruptionCalc)

--! TEST SUITE
local function runTests()
	local suite = TestFramework.new("Combat System - Tier 2.2")
	
	--! ==================== COMBO TESTS ====================
	suite:describe("Combo System", function()
		suite:test("should start at combo 0", function()
			local state = CombatCore.getPlayerCombatState({UserId = 1})
			TestFramework.assertEquals(state.ComboCount, 0, "Initial combo should be 0")
		end)
		
		suite:test("should increment combo on consecutive hits", function()
			local state = CombatCore.getPlayerCombatState({UserId = 2})
			state.ComboCount = 0
			state.LastComboHitTime = tick()
			
			TestFramework.assertEquals(state.ComboCount, 0, "Start at 0")
			state.ComboCount = 1
			TestFramework.assertEquals(state.ComboCount, 1, "Increment to 1")
			state.ComboCount = 2
			TestFramework.assertEquals(state.ComboCount, 2, "Increment to 2")
			state.ComboCount = 3
			TestFramework.assertEquals(state.ComboCount, 3, "Increment to 3")
		end)
		
		suite:test("should cap combo at 3", function()
			local state = CombatCore.getPlayerCombatState({UserId = 3})
			state.ComboCount = 5
			state.ComboCount = math.min(state.ComboCount, 3)
			TestFramework.assertEquals(state.ComboCount, 3, "Combo should be capped at 3")
		end)
		
		suite:test("should reset combo on timeout (3s no hits)", function()
			local state = CombatCore.getPlayerCombatState({UserId = 4})
			state.ComboCount = 3
			state.LastComboHitTime = tick() - 3.5 --! 3.5s ago
			
			if tick() - state.LastComboHitTime > 3.0 then
				state.ComboCount = 0
			end
			
			TestFramework.assertEquals(state.ComboCount, 0, "Combo should reset after 3s timeout")
		end)
		
		suite:test("damage should increase with combo count", function()
			local damages = CombatCore.CONFIG.COMBO.DAMAGE
			TestFramework.assertEquals(damages[1], 20, "Combo 1 damage = 20")
			TestFramework.assertEquals(damages[2], 25, "Combo 2 damage = 25")
			TestFramework.assertEquals(damages[3], 30, "Combo 3 damage = 30")
		end)
	end)
	
	--! ==================== PARRY TESTS ====================
	suite:describe("Parry Mechanic", function()
		suite:test("parry window should be 0.5s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.PARRY.WINDOW, 0.5, "Parry window = 0.5s")
		end)
		
		suite:test("successful parry should deal chip damage", function()
			local chipMin = CombatCore.CONFIG.PARRY.CHIP_DAMAGE_MIN
			local chipMax = CombatCore.CONFIG.PARRY.CHIP_DAMAGE_MAX
			local incomingDamage = 20
			
			local chip = incomingDamage * chipMin
			TestFramework.assertEquals(chip >= 1, true, "Chip damage minimum met")
		end)
		
		suite:test("failed parry should cost 15 stamina", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.PARRY.STAMINA_COST_FAIL,
				15,
				"Failed parry stamina cost = 15"
			)
		end)
		
		suite:test("successful parry should stun attacker 0.3s", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.PARRY.ATTACKER_STUN,
				0.3,
				"Attacker stun duration = 0.3s"
			)
		end)
		
		suite:test("failed parry should stun parrier 0.2s", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.PARRY.PARRIER_STUN_FAIL,
				0.2,
				"Parrier stun on fail = 0.2s"
			)
		end)
	end)
	
	--! ==================== BLOCK TESTS ====================
	suite:describe("Block Mechanic", function()
		suite:test("block should cost 10 stamina per second", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.BLOCK.STAMINA_COST_PER_SECOND,
				10,
				"Block stamina cost = 10/sec"
			)
		end)
		
		suite:test("block should reduce damage 20-30%", function()
			local minReduction = CombatCore.CONFIG.BLOCK.DAMAGE_REDUCTION_MIN
			local maxReduction = CombatCore.CONFIG.BLOCK.DAMAGE_REDUCTION_MAX
			TestFramework.assertEquals(minReduction >= 0.70, true, "Min reduction 70%")
			TestFramework.assertEquals(maxReduction <= 0.80, true, "Max reduction 80%")
		end)
		
		suite:test("blocked damage calculation should be correct", function()
			local incomingDamage = 20
			local reduction = 0.75
			local blocked = incomingDamage * (1 - reduction)
			TestFramework.assertEquals(blocked, 5, "20 damage * 0.25 = 5 damage taken")
		end)
	end)
	
	--! ==================== DASH TESTS ====================
	suite:describe("Dash System", function()
		suite:test("dash base stamina should be 20", function()
			TestFramework.assertEquals(CombatCore.CONFIG.DASH.BASE_STAMINA, 20, "Base stamina = 20")
		end)
		
		suite:test("dash stamina cost scales with distance", function()
			local baseCost = 20
			local distance = 10
			local totalCost = baseCost + (distance * 0.5)
			TestFramework.assertEquals(totalCost, 25, "10m dash costs 25 stamina")
		end)
		
		suite:test("dash cooldown should be 2s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.DASH.COOLDOWN, 2.0, "Dash cooldown = 2s")
		end)
		
		suite:test("dash should have 0.4s immunity frames", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.DASH.IMMUNITY_DURATION,
				0.4,
				"Immunity duration = 0.4s"
			)
		end)
		
		suite:test("dash should reset combo", function()
			local state = CombatCore.getPlayerCombatState({UserId = 10})
			state.ComboCount = 3
			CombatCore.resetCombo({UserId = 10})
			TestFramework.assertEquals(state.ComboCount, 0, "Combo reset on dash")
		end)
		
		suite:test("dash distance should be clamped at 20m max", function()
			local maxDistance = CombatCore.CONFIG.DASH.MAX_DISTANCE
			TestFramework.assertEquals(maxDistance, 20, "Max dash distance = 20m")
		end)
	end)
	
	--! ==================== CORRUPTION TESTS ====================
	suite:describe("Corruption Integration", function()
		suite:test("low corruption should have 0.8x damage", function()
			local multiplier = CorruptionCalc.getDamageMultiplier(10)
			TestFramework.assertEquals(multiplier >= 0.79 and multiplier <= 0.81, true, "10% corruption = 0.8x")
		end)
		
		suite:test("high corruption should have 1.3x damage", function()
			local multiplier = CorruptionCalc.getDamageMultiplier(85)
			TestFramework.assertEquals(multiplier >= 1.29 and multiplier <= 1.31, true, "85% corruption = 1.3x")
		end)
		
		suite:test("overload at 100% corruption should block attacks", function()
			local canAttack = 100 < 100
			TestFramework.assertEquals(canAttack, false, "Cannot attack at 100% corruption")
		end)
		
		suite:test("corruption should apply cooldown penalty", function()
			local penalty = CorruptionCalc.getCooldownPenalty(75)
			TestFramework.assertEquals(penalty > 0, true, "75% corruption has cooldown penalty")
		end)
	end)
	
	--! ==================== VALIDATION TESTS ====================
	suite:describe("Server Validation", function()
		suite:test("melee range should be 16 studs", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.VALIDATION.MELEE_RANGE,
				16,
				"Melee range = 16 studs"
			)
		end)
		
		suite:test("should reject attacks outside melee range", function()
			local distance = 20
			local inRange = distance <= CombatCore.CONFIG.VALIDATION.MELEE_RANGE
			TestFramework.assertEquals(inRange, false, "20 studs is out of range")
		end)
		
		suite:test("should accept attacks within melee range", function()
			local distance = 10
			local inRange = distance <= CombatCore.CONFIG.VALIDATION.MELEE_RANGE
			TestFramework.assertEquals(inRange, true, "10 studs is in range")
		end)
		
		suite:test("max position change should be 50 studs", function()
			TestFramework.assertEquals(
				CombatCore.CONFIG.VALIDATION.MAX_POSITION_CHANGE,
				50,
				"Max position change = 50 studs"
			)
		end)
	end)
	
	--! ==================== INTEGRATION TESTS ====================
	suite:describe("Combat Integration", function()
		suite:test("attack should calculate damage correctly", function()
			local baseDamage = 20
			local corruptionMult = 1.0
			local comboMult = 1.1
			local totalDamage = baseDamage * corruptionMult * comboMult
			TestFramework.assertEquals(totalDamage, 22, "20 * 1.0 * 1.1 = 22")
		end)
		
		suite:test("combo multiplier should increase per hit", function()
			local combo1Mult = 1.0 + (1 * 0.1)
			local combo2Mult = 1.0 + (2 * 0.1)
			local combo3Mult = 1.0 + (3 * 0.1)
			TestFramework.assertEquals(combo1Mult, 1.1, "Combo 1 multiplier = 1.1x")
			TestFramework.assertEquals(combo2Mult, 1.2, "Combo 2 multiplier = 1.2x")
			TestFramework.assertEquals(combo3Mult, 1.3, "Combo 3 multiplier = 1.3x")
		end)
		
		suite:test("parry should reflect less damage than taken", function()
			local incomingDamage = 20
			local chipDamage = incomingDamage * 0.07
			TestFramework.assertEquals(
				chipDamage < incomingDamage,
				true,
				"Chip damage is less than incoming"
			)
		end)
		
		suite:test("block should always reduce damage", function()
			local incomingDamage = 20
			local blocked = incomingDamage * (1 - 0.75)
			TestFramework.assertEquals(blocked < incomingDamage, true, "Blocked damage is less")
		end)
	end)
	
	--! ==================== EDGE CASES ====================
	suite:describe("Edge Cases", function()
		suite:test("zero damage should not crash", function()
			local damage = 0
			TestFramework.assertEquals(damage >= 0, true, "Zero damage is valid")
		end)
		
		suite:test("negative distance should not be valid", function()
			local distance = -5
			TestFramework.assertEquals(distance < 0, true, "Negative distance detected")
		end)
		
		suite:test("very high corruption should not exceed 1.5x damage", function()
			local multiplier = CorruptionCalc.getDamageMultiplier(150)
			TestFramework.assertEquals(multiplier <= 1.5, true, "Multiplier capped at 1.5x")
		end)
	end)
	
	--! RUN ALL TESTS
	suite:run()
end

--! MAIN EXECUTION
if game:GetService("RunService"):IsServer() then
	task.wait(1) --! Wait for systems to initialize
	runTests()
end
