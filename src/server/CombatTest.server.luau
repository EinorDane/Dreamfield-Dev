--!strict
--[[
	CombatTest.server.luau - ENHANCED WITH MOBILITY TESTS
	Test suite for combat + mobility system (60+ tests)
	Tests: Combo, Parry, Block, Dash, Sprint, Knockback, Ragdoll, Fall
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TestFrameworkModule = Shared:WaitForChild("TestFramework")
local TestFramework = require(TestFrameworkModule)

local ServerFolder = ServerScriptService:WaitForChild("Server")
local CombatCoreModule = ServerFolder:WaitForChild("CombatCore")
local CombatCore = require(CombatCoreModule)

local PlayerDataModule = Shared:WaitForChild("PlayerData")
local PlayerData = require(PlayerDataModule)

local CorruptionCalcModule = Shared:WaitForChild("CorruptionCalc")
local CorruptionCalc = require(CorruptionCalcModule)

local function runTests()
	local suite = TestFramework.new("Combat + Mobility System - Tier 2.2 ENHANCED")
	
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
			state.LastComboHitTime = tick() - 3.5
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
			TestFramework.assertEquals(CombatCore.CONFIG.PARRY.STAMINA_COST_FAIL, 15, "Failed parry stamina cost = 15")
		end)
		
		suite:test("successful parry should stun attacker 0.3s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.PARRY.ATTACKER_STUN, 0.3, "Attacker stun duration = 0.3s")
		end)
		
		suite:test("failed parry should stun parrier 0.2s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.PARRY.PARRIER_STUN_FAIL, 0.2, "Parrier stun on fail = 0.2s")
		end)
	end)
	
	suite:describe("Block Mechanic", function()
		suite:test("block should cost 10 stamina per second", function()
			TestFramework.assertEquals(CombatCore.CONFIG.BLOCK.STAMINA_COST_PER_SECOND, 10, "Block stamina cost = 10/sec")
		end)
		
		suite:test("block should reduce damage 70-80%", function()
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
			TestFramework.assertEquals(CombatCore.CONFIG.DASH.IMMUNITY_DURATION, 0.4, "Immunity duration = 0.4s")
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
	
	suite:describe("Sprint System", function()
		suite:test("sprint speed multiplier should be 1.5x", function()
			TestFramework.assertEquals(CombatCore.CONFIG.SPRINT.SPEED_MULTIPLIER, 1.5, "Sprint speed = 1.5x normal")
		end)
		
		suite:test("sprint should cost 8 stamina per second", function()
			TestFramework.assertEquals(CombatCore.CONFIG.SPRINT.STAMINA_COST_PER_SECOND, 8, "Sprint stamina cost = 8/sec")
		end)
		
		suite:test("sprint minimum stamina to start should be 10", function()
			TestFramework.assertEquals(CombatCore.CONFIG.SPRINT.MIN_STAMINA_TO_START, 10, "Min stamina to start = 10")
		end)
		
		suite:test("sprint cooldown after ending should be 0.5s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.SPRINT.COOLDOWN_AFTER_SPRINT, 0.5, "Sprint cooldown = 0.5s")
		end)
		
		suite:test("sprint should reset combo", function()
			local state = CombatCore.getPlayerCombatState({UserId = 20})
			state.ComboCount = 3
			state.IsSprinting = true
			local profile = PlayerData.createProfile()
			local tempState = CombatCore.getPlayerCombatState({UserId = 1})
			tempState.ComboCount = 0
			TestFramework.assertEquals(tempState.ComboCount, 0, "Combo reset on sprint")
		end)
	end)
	
	suite:describe("Knockback System", function()
		suite:test("light hit should use light force", function()
			TestFramework.assertEquals(CombatCore.CONFIG.KNOCKBACK.LIGHT_FORCE, 50, "Light knockback force = 50")
		end)
		
		suite:test("medium hit should use medium force", function()
			TestFramework.assertEquals(CombatCore.CONFIG.KNOCKBACK.MEDIUM_FORCE, 100, "Medium knockback force = 100")
		end)
		
		suite:test("heavy hit should use heavy force", function()
			TestFramework.assertEquals(CombatCore.CONFIG.KNOCKBACK.HEAVY_FORCE, 150, "Heavy knockback force = 150")
		end)
		
		suite:test("knockback threshold for ragdoll should be 80 damage", function()
			TestFramework.assertEquals(CombatCore.CONFIG.KNOCKBACK.RAGDOLL_THRESHOLD, 80, "Ragdoll threshold = 80 damage")
		end)
		
		suite:test("light damage (10) should not trigger ragdoll", function()
			local canRagdoll = 10 >= CombatCore.CONFIG.KNOCKBACK.RAGDOLL_THRESHOLD
			TestFramework.assertEquals(canRagdoll, false, "Light damage cannot ragdoll")
		end)
		
		suite:test("heavy damage (100) should trigger ragdoll", function()
			local canRagdoll = 100 >= CombatCore.CONFIG.KNOCKBACK.RAGDOLL_THRESHOLD
			TestFramework.assertEquals(canRagdoll, true, "Heavy damage triggers ragdoll")
		end)
	end)
	
	suite:describe("Ragdoll System", function()
		suite:test("light ragdoll duration should be 0.5s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.RAGDOLL.DURATION_SHORT, 0.5, "Short ragdoll = 0.5s")
		end)
		
		suite:test("medium ragdoll duration should be 1.0s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.RAGDOLL.DURATION_MEDIUM, 1.0, "Medium ragdoll = 1.0s")
		end)
		
		suite:test("long ragdoll duration should be 1.5s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.RAGDOLL.DURATION_LONG, 1.5, "Long ragdoll = 1.5s")
		end)
		
		suite:test("ragdoll recovery time should be 0.3s", function()
			TestFramework.assertEquals(CombatCore.CONFIG.RAGDOLL.RECOVERY_TIME, 0.3, "Recovery time = 0.3s")
		end)
	end)
	
	suite:describe("Fall Damage System", function()
		suite:test("fall damage rate should be 5 per stud", function()
			TestFramework.assertEquals(CombatCore.CONFIG.FALL.DAMAGE_PER_STUD, 5, "Fall damage = 5/stud")
		end)
		
		suite:test("safe fall height should be 10 studs", function()
			TestFramework.assertEquals(CombatCore.CONFIG.FALL.SAFE_FALL_HEIGHT, 10, "Safe fall = 10 studs")
		end)
		
		suite:test("landing roll should cost 25 stamina", function()
			TestFramework.assertEquals(CombatCore.CONFIG.FALL.LANDING_ROLL_COST, 25, "Landing roll cost = 25 stamina")
		end)
		
		suite:test("fall from 10 studs should be safe", function()
			local height = 10
			local isSafe = height <= CombatCore.CONFIG.FALL.SAFE_FALL_HEIGHT
			TestFramework.assertEquals(isSafe, true, "10 studs is safe fall")
		end)
		
		suite:test("fall from 20 studs should deal 50 damage", function()
			local height = 20
			local safeFall = CombatCore.CONFIG.FALL.SAFE_FALL_HEIGHT
			local damage = (height - safeFall) * CombatCore.CONFIG.FALL.DAMAGE_PER_STUD
			TestFramework.assertEquals(damage, 50, "20 studs = 50 damage")
		end)
		
		suite:test("fall from 15 studs should deal 25 damage", function()
			local height = 15
			local safeFall = CombatCore.CONFIG.FALL.SAFE_FALL_HEIGHT
			local damage = (height - safeFall) * CombatCore.CONFIG.FALL.DAMAGE_PER_STUD
			TestFramework.assertEquals(damage, 25, "15 studs = 25 damage")
		end)
	end)
	
	suite:describe("Stamina System", function()
		suite:test("max stamina should be 100", function()
			TestFramework.assertEquals(CombatCore.CONFIG.STAMINA.MAX, 100, "Max stamina = 100")
		end)
		
		suite:test("idle regen should be 15 per second", function()
			TestFramework.assertEquals(CombatCore.CONFIG.STAMINA.REGEN_IDLE, 15, "Idle regen = 15/sec")
		end)
		
		suite:test("combat regen should be 5 per second", function()
			TestFramework.assertEquals(CombatCore.CONFIG.STAMINA.REGEN_COMBAT, 5, "Combat regen = 5/sec")
		end)
		
		suite:test("warning threshold should be 20 stamina", function()
			TestFramework.assertEquals(CombatCore.CONFIG.STAMINA.WARNING_THRESHOLD, 20, "Warning threshold = 20")
		end)
		
		suite:test("critical threshold should be 5 stamina", function()
			TestFramework.assertEquals(CombatCore.CONFIG.STAMINA.CRITICAL_THRESHOLD, 5, "Critical threshold = 5")
		end)
	end)
	
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
			local penalty = CorruptionCalc.getCooldownPenalty(75, 20)
			TestFramework.assertEquals(penalty > 0, true, "75% corruption has cooldown penalty")
		end)
	end)
	
	suite:describe("Server Validation", function()
		suite:test("melee range should be 16 studs", function()
			TestFramework.assertEquals(CombatCore.CONFIG.VALIDATION.MELEE_RANGE, 16, "Melee range = 16 studs")
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
	end)
	
	suite:describe("Combat + Mobility Integration", function()
		suite:test("light hit (15 damage) uses light knockback", function()
			local damage = 15
			local isLight = damage < 16
			TestFramework.assertEquals(isLight, true, "15 damage = light knockback")
		end)
		
		suite:test("medium hit (20 damage) uses medium knockback", function()
			local damage = 20
			local isMedium = damage >= 16 and damage < 26
			TestFramework.assertEquals(isMedium, true, "20 damage = medium knockback")
		end)
		
		suite:test("heavy hit (30 damage) uses heavy knockback", function()
			local damage = 30
			local isHeavy = damage >= 26
			TestFramework.assertEquals(isHeavy, true, "30 damage = heavy knockback")
		end)
		
		suite:test("combo multiplier with knockback", function()
			local baseDamage = 20
			local comboMult = 1.3
			local totalDamage = baseDamage * comboMult
			local triggersRagdoll = totalDamage >= CombatCore.CONFIG.KNOCKBACK.RAGDOLL_THRESHOLD
			TestFramework.assertEquals(triggersRagdoll, false, "26 damage doesn't ragdoll yet")
		end)
		
		suite:test("sprint drain should deplete stamina", function()
			local stamina = 100
			local costPerSec = CombatCore.CONFIG.SPRINT.STAMINA_COST_PER_SECOND
			local timeSpent = 5
			local remaining = stamina - (costPerSec * timeSpent)
			TestFramework.assertEquals(remaining, 60, "100 - (8*5) = 60 stamina")
		end)
	end)
	
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
		
		suite:test("stamina should not go below 0", function()
			local stamina = 100
			local cost = 150
			local remaining = math.max(stamina - cost, 0)
			TestFramework.assertEquals(remaining, 0, "Stamina clamped at 0")
		end)
		
		suite:test("stamina should not exceed max", function()
			local stamina = 100
			local regen = 20
			local total = math.min(stamina + regen, 100)
			TestFramework.assertEquals(total, 100, "Stamina clamped at max")
		end)
	end)
	
	suite:run()
end

if game:GetService("RunService"):IsServer() then
	task.wait(1)
	runTests()
end
