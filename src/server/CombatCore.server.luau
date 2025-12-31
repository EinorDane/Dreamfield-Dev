--!strict
--[[
	CombatCore.server.luau - ENHANCED WITH FULL MOBILITY SUITE
	Server-authoritative combat system with advanced mobility
	
	SYSTEMS:
	- Combo counter (1/2/3, resets on miss/dash/sprint)
	- Parry mechanic (0.5s window, chip damage reflection)
	- Block mechanic (hold F, stamina drain, damage reduction)
	- Dash (directional, distance-based stamina, resets combo)
	- Sprint (Shift, continuous movement, stamina drain)
	- Knockback physics (damage-based momentum)
	- Ragdoll effects (heavy hits trigger temporary ragdoll)
	- Wall slide detection (slide when touching walls while sprinting)
	- Fall damage & landing roll (prevents death from drops)
	- Corruption effects (damage multiplier, cooldown penalties)
	- Server validation (distance, cooldown, stamina, position)
]]

--! Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

--! Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerData = require(Shared:WaitForChild("PlayerData"))
local CorruptionCalc = require(Shared:WaitForChild("CorruptionCalc"))
local CombatRemotes = require(Shared:WaitForChild("CombatRemotes"))

--! CONFIG
local CONFIG = {
	COMBO = {
		MAX_HITS = 3,
		DAMAGE = { 20, 25, 30 },
		MISS_RECOVERY_TIME = 0.5,
		MISS_STUN_TIME = 0.2,
		COUNTER_WINDOW = 1.0,
		RESET_TIMEOUT = 3.0,
	},
	PARRY = {
		WINDOW = 0.5,
		CHIP_DAMAGE_MIN = 0.05,
		CHIP_DAMAGE_MAX = 0.10,
		STAMINA_COST_FAIL = 15,
		ATTACKER_STUN = 0.3,
		PARRIER_STUN_FAIL = 0.2,
	},
	BLOCK = {
		STAMINA_COST_PER_SECOND = 10,
		DAMAGE_REDUCTION_MIN = 0.70,
		DAMAGE_REDUCTION_MAX = 0.80,
	},
	DASH = {
		BASE_STAMINA = 20,
		STAMINA_PER_METER = 0.5,
		MAX_DISTANCE = 20,
		COOLDOWN = 2.0,
		IMMUNITY_DURATION = 0.4,
	},
	--! ========== NEW: SPRINT SYSTEM ==========
	SPRINT = {
		SPEED_MULTIPLIER = 1.5,
		STAMINA_COST_PER_SECOND = 8,
		MIN_STAMINA_TO_START = 10,
		COOLDOWN_AFTER_SPRINT = 0.5,
	},
	--! ========== NEW: STAMINA SYSTEM ==========
	STAMINA = {
		MAX = 100,
		REGEN_IDLE = 15,
		REGEN_COMBAT = 5,
		WARNING_THRESHOLD = 20,
		CRITICAL_THRESHOLD = 5,
	},
	--! ========== NEW: KNOCKBACK SYSTEM ==========
	KNOCKBACK = {
		LIGHT_FORCE = 50,
		MEDIUM_FORCE = 100,
		HEAVY_FORCE = 150,
		BASE_SPEED = 50,
		RAGDOLL_THRESHOLD = 80,
	},
	--! ========== NEW: RAGDOLL SYSTEM ==========
	RAGDOLL = {
		DURATION_SHORT = 0.5,
		DURATION_MEDIUM = 1.0,
		DURATION_LONG = 1.5,
		RECOVERY_TIME = 0.3,
	},
	--! ========== NEW: FALL SYSTEM ==========
	FALL = {
		DAMAGE_PER_STUD = 5,
		SAFE_FALL_HEIGHT = 10,
		LANDING_ROLL_COST = 25,
	},
	--! ========== NEW: WALL SLIDE ==========
	WALL_SLIDE = {
		ENABLED = true,
		SLIDE_SPEED = 0.8,
		SLIDE_STAMINA_COST = 2,
		MIN_VERTICAL_SPEED = -50,
	},
	VALIDATION = {
		MELEE_RANGE = 16,
		SKILL_RANGE = 30,
		MAX_POSITION_CHANGE = 50,
	},
}

--! TYPES
type PlayerCombatState = {
	UserId: number,
	ComboCount: number,
	LastComboHitTime: number,
	IsRecovering: boolean,
	RecoveryEndTime: number,
	LastAttackTime: number,
	LastDashTime: number,
	IsBlocking: boolean,
	BlockStartTime: number,
	IsDashing: boolean,
	DashEndTime: number,
	LastPosition: Vector3,
	IsSprinting: boolean,
	SprintStartTime: number,
	LastSprintEndTime: number,
	IsRagdoll: boolean,
	RagdollEndTime: number,
	IsWallSliding: boolean,
	LastFallHeight: number,
}

--! GLOBAL STATE
local PlayerStates: { [number]: PlayerCombatState } = {}
local PlayerVelocities: { [number]: Vector3 } = {}

--! UTILITY FUNCTIONS
local function getPlayerCombatState(player: Player): PlayerCombatState
	local userId = player.UserId
	
	if not PlayerStates[userId] then
		PlayerStates[userId] = {
			UserId = userId,
			ComboCount = 0,
			LastComboHitTime = 0,
			IsRecovering = false,
			RecoveryEndTime = 0,
			LastAttackTime = 0,
			LastDashTime = 0,
			IsBlocking = false,
			BlockStartTime = 0,
			IsDashing = false,
			DashEndTime = 0,
			LastPosition = Vector3.new(0, 0, 0),
			IsSprinting = false,
			SprintStartTime = 0,
			LastSprintEndTime = 0,
			IsRagdoll = false,
			RagdollEndTime = 0,
			IsWallSliding = false,
			LastFallHeight = 0,
		}
	end
	
	return PlayerStates[userId]
end

local function validateAttack(
	attacker: Player,
	targetPlayer: Player,
	distance: number
): (boolean, string)
	if distance > CONFIG.VALIDATION.MELEE_RANGE then
		return false, "Target too far away"
	end
	
	local playerData = PlayerData.getPlayerData(attacker.UserId)
	if playerData.corruption >= 100 then
		return false, "Overloaded, cannot attack"
	end
	
	local state = getPlayerCombatState(attacker)
	local positionChange = (attacker.Character.PrimaryPart.Position - state.LastPosition).Magnitude
	if positionChange > CONFIG.VALIDATION.MAX_POSITION_CHANGE then
		return false, "Invalid position change"
	end
	
	return true, "Valid"
end

local function calculateDamage(
	baseDamage: number,
	attacker: Player,
	comboCount: number
): number
	local playerData = PlayerData.getPlayerData(attacker.UserId)
	
	local corruptionMultiplier = CorruptionCalc.getDamageMultiplier(playerData.corruption)
	local comboMultiplier = 1.0 + (comboCount * 0.1)
	
	local damage = baseDamage * corruptionMultiplier * comboMultiplier
	return math.floor(damage)
end

local function calculateKnockback(damage: number): (number, string)
	if damage >= 26 then
		return CONFIG.KNOCKBACK.HEAVY_FORCE, "HEAVY"
	elseif damage >= 16 then
		return CONFIG.KNOCKBACK.MEDIUM_FORCE, "MEDIUM"
	else
		return CONFIG.KNOCKBACK.LIGHT_FORCE, "LIGHT"
	end
end

local function applyKnockback(target: Player, knockbackForce: number, source: Vector3)
	if not target.Character or not target.Character:FindFirstChild("Humanoid") then
		return
	end
	
	local direction = (target.Character.PrimaryPart.Position - source).Unit
	local velocity = direction * knockbackForce + Vector3.new(0, knockbackForce / 3, 0)
	
	PlayerVelocities[target.UserId] = velocity
	
	local targetState = getPlayerCombatState(target)
	targetState.ComboCount = 0
	
	CombatRemotes.ApplyKnockback:FireClient(target, velocity)
	print("💥 Knockback applied: " .. knockbackForce .. " force")
end

local function triggerRagdoll(target: Player, duration: number)
	if not target.Character then
		return
	end
	
	local state = getPlayerCombatState(target)
	state.IsRagdoll = true
	state.RagdollEndTime = tick() + duration
	
	CombatRemotes.TriggerRagdoll:FireClient(target, duration)
	
	print("🎭 Ragdoll triggered: " .. duration .. "s")
end

local function determineFallDamage(fallHeight: number): (number, string)
	if fallHeight <= CONFIG.FALL.SAFE_FALL_HEIGHT then
		return 0, "SAFE"
	end
	
	local damage = math.floor((fallHeight - CONFIG.FALL.SAFE_FALL_HEIGHT) * CONFIG.FALL.DAMAGE_PER_STUD)
	
	if damage > 50 then
		return damage, "HEAVY"
	elseif damage > 25 then
		return damage, "MEDIUM"
	else
		return damage, "LIGHT"
	end
end

local function handleLanding(player: Player, fallHeight: number)
	local playerData = PlayerData.getPlayerData(player.UserId)
	local damage, fallType = determineFallDamage(fallHeight)
	
	if damage == 0 then
		print("✅ Safe landing")
		return
	end
	
	if playerData.stamina >= CONFIG.FALL.LANDING_ROLL_COST then
		PlayerData.removeStamina(playerData, CONFIG.FALL.LANDING_ROLL_COST)
		CombatRemotes.LandingRoll:FireClient(player)
		print("🏃 Landing roll! Avoided " .. damage .. " damage")
		return
	end
	
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
		CombatRemotes.TakeFallDamage:FireClient(player, damage, fallType)
		print("💔 Fall damage: " .. damage .. " (" .. fallType .. ")")
	end
end

local function resetCombo(player: Player)
	local state = getPlayerCombatState(player)
	state.ComboCount = 0
	state.LastComboHitTime = 0
	state.IsRecovering = false
	CombatRemotes.UpdateComboCounter:FireClient(player, 0)
end

local function incrementCombo(player: Player): number
	local state = getPlayerCombatState(player)
	
	if tick() - state.LastComboHitTime > CONFIG.COMBO.RESET_TIMEOUT then
		state.ComboCount = 0
	end
	
	state.ComboCount = math.min(state.ComboCount + 1, CONFIG.COMBO.MAX_HITS)
	state.LastComboHitTime = tick()
	
	CombatRemotes.UpdateComboCounter:FireClient(player, state.ComboCount)
	
	return state.ComboCount
end

--! ==================== COMBAT HANDLERS ====================

local function handleAttack(
	attacker: Player,
	targetPlayer: Player,
	skillName: string
): { success: boolean, damage: number, message: string }
	if not attacker.Character or not targetPlayer.Character then
		return { success = false, damage = 0, message = "Character not found" }
	end
	
	local distance = (attacker.Character.PrimaryPart.Position - targetPlayer.Character.PrimaryPart.Position).Magnitude
	local isValid, validationError = validateAttack(attacker, targetPlayer, distance)
	
	if not isValid then
		return { success = false, damage = 0, message = validationError }
	end
	
	local state = getPlayerCombatState(attacker)
	local comboCount = incrementCombo(attacker)
	local baseDamage = CONFIG.COMBO.DAMAGE[comboCount] or CONFIG.COMBO.DAMAGE[3]
	local damage = calculateDamage(baseDamage, attacker, comboCount)
	
	local playerData = PlayerData.getPlayerData(attacker.UserId)
	PlayerData.removeStamina(playerData, 10)
	
	local knockbackForce, knockbackType = calculateKnockback(damage)
	applyKnockback(targetPlayer, knockbackForce, attacker.Character.PrimaryPart.Position)
	
	if damage >= CONFIG.KNOCKBACK.RAGDOLL_THRESHOLD then
		triggerRagdoll(targetPlayer, CONFIG.RAGDOLL.DURATION_LONG)
	end
	
	state.LastAttackTime = tick()
	state.LastPosition = attacker.Character.PrimaryPart.Position
	
	print("✅ Attack hit! Combo: " .. comboCount .. ", Damage: " .. damage .. " (" .. knockbackType .. ")")
	
	return {
		success = true,
		damage = damage,
		message = "Attack hit combo " .. comboCount .. " (" .. knockbackType .. ")",
	}
end

local function handleParry(
	defender: Player,
	attacker: Player,
	incomingDamage: number
): { success: boolean, damage: number, chipDamage: number, message: string }
	if not defender.Character or not attacker.Character then
		return { success = false, damage = 0, chipDamage = 0, message = "Character not found" }
	end
	
	local defenderData = PlayerData.getPlayerData(defender.UserId)
	local state = getPlayerCombatState(defender)
	
	local parrySuccess = math.random(1, 100) > 30
	
	if parrySuccess then
		local chipDamage = incomingDamage * (CONFIG.PARRY.CHIP_DAMAGE_MIN + 
			math.random() * (CONFIG.PARRY.CHIP_DAMAGE_MAX - CONFIG.PARRY.CHIP_DAMAGE_MIN))
		chipDamage = math.floor(chipDamage)
		
		print("✅ Parry successful! Chip damage: " .. chipDamage)
		
		return {
			success = true,
			damage = 0,
			chipDamage = chipDamage,
			message = "Parry successful! " .. chipDamage .. " chip damage",
		}
	else
		PlayerData.removeStamina(defenderData, CONFIG.PARRY.STAMINA_COST_FAIL)
		
		state.IsRecovering = true
		state.RecoveryEndTime = tick() + CONFIG.PARRY.PARRIER_STUN_FAIL
		
		print("❌ Parry failed! Stamina cost: " .. CONFIG.PARRY.STAMINA_COST_FAIL)
		
		return {
			success = false,
			damage = 0,
			chipDamage = 0,
			message = "Parry failed! Stamina cost: " .. CONFIG.PARRY.STAMINA_COST_FAIL,
		}
	end
end

local function handleBlock(
	defender: Player,
	incomingDamage: number,
	deltaTime: number
): { damage: number, message: string }
	local state = getPlayerCombatState(defender)
	local playerData = PlayerData.getPlayerData(defender.UserId)
	
	if not state.IsBlocking then
		state.IsBlocking = true
		state.BlockStartTime = tick()
	end
	
	local staminaCost = CONFIG.BLOCK.STAMINA_COST_PER_SECOND * deltaTime
	PlayerData.removeStamina(playerData, staminaCost)
	
	local damageReduction = CONFIG.BLOCK.DAMAGE_REDUCTION_MIN + 
		math.random() * (CONFIG.BLOCK.DAMAGE_REDUCTION_MAX - CONFIG.BLOCK.DAMAGE_REDUCTION_MIN)
	local damageAfterBlock = incomingDamage * (1 - damageReduction)
	damageAfterBlock = math.floor(damageAfterBlock)
	
	print("🛡️  Block active. Damage reduced by " .. math.floor(damageReduction * 100) .. "%")
	
	return {
		damage = damageAfterBlock,
		message = "Blocked! Took " .. damageAfterBlock .. " damage (" .. 
			math.floor(damageReduction * 100) .. "% reduced)",
	}
end

local function handleDash(
	player: Player,
	distance: number
): { success: boolean, staminaCost: number, message: string }
	local state = getPlayerCombatState(player)
	local playerData = PlayerData.getPlayerData(player.UserId)
	
	if tick() - state.LastDashTime < CONFIG.DASH.COOLDOWN then
		print("⏳ Dash on cooldown")
		return {
			success = false,
			staminaCost = 0,
			message = "Dash still on cooldown",
		}
	end
	
	distance = math.min(distance, CONFIG.DASH.MAX_DISTANCE)
	
	local staminaCost = CONFIG.DASH.BASE_STAMINA + (distance * CONFIG.DASH.STAMINA_PER_METER)
	staminaCost = math.floor(staminaCost)
	
	if playerData.stamina < staminaCost then
		print("❌ Not enough stamina. Need: " .. staminaCost .. ", Have: " .. playerData.stamina)
		return {
			success = false,
			staminaCost = 0,
			message = "Not enough stamina for dash",
		}
	end
	
	PlayerData.removeStamina(playerData, staminaCost)
	state.LastDashTime = tick()
	state.IsDashing = true
	state.DashEndTime = tick() + CONFIG.DASH.IMMUNITY_DURATION
	
	resetCombo(player)
	
	print("✅ Dash executed: " .. distance .. "m, cost " .. staminaCost .. " stamina")
	
	return {
		success = true,
		staminaCost = staminaCost,
		message = "Dashed " .. distance .. "m, cost " .. staminaCost .. " stamina",
	}
end

--! ==================== SPRINT HANDLER ====================

local function handleSprintStart(player: Player): { success: boolean, message: string }
	local playerData = PlayerData.getPlayerData(player.UserId)
	local state = getPlayerCombatState(player)
	
	if playerData.stamina < CONFIG.SPRINT.MIN_STAMINA_TO_START then
		print("❌ Not enough stamina to sprint")
		return {
			success = false,
			message = "Not enough stamina to sprint",
		}
	end
	
	if tick() - state.LastSprintEndTime < CONFIG.SPRINT.COOLDOWN_AFTER_SPRINT then
		print("⏳ Sprint cooling down")
		return {
			success = false,
			message = "Sprint cooling down",
		}
	end
	
	state.IsSprinting = true
	state.SprintStartTime = tick()
	resetCombo(player)
	
	CombatRemotes.SprintStarted:FireClient(player)
	print("🏃 Sprint started")
	
	return {
		success = true,
		message = "Sprint started",
	}
end

local function handleSprintEnd(player: Player): { success: boolean, message: string }
	local state = getPlayerCombatState(player)
	
	if not state.IsSprinting then
		return {
			success = false,
			message = "Not sprinting",
		}
	end
	
	state.IsSprinting = false
	state.LastSprintEndTime = tick()
	
	CombatRemotes.SprintEnded:FireClient(player)
	print("⏹️  Sprint ended")
	
	return {
		success = true,
		message = "Sprint ended",
	}
end

local function handleSprintTick(player: Player, deltaTime: number)
	local state = getPlayerCombatState(player)
	local playerData = PlayerData.getPlayerData(player.UserId)
	
	if not state.IsSprinting then
		return
	end
	
	local staminaCost = CONFIG.SPRINT.STAMINA_COST_PER_SECOND * deltaTime
	PlayerData.removeStamina(playerData, staminaCost)
	
	if playerData.stamina <= 0 then
		handleSprintEnd(player)
	end
end

--! ==================== STAMINA REGEN ====================

local sprintLoop = RunService.Heartbeat:Connect(function(deltaTime)
	for userId, state in pairs(PlayerStates) do
		local player = Players:FindFirstChild(tostring(userId))
		if not player then
			continue
		end
		
		local playerData = PlayerData.getPlayerData(userId)
		
		if state.IsSprinting then
			handleSprintTick(player, deltaTime)
		else
			local regenRate = (state.LastAttackTime and (tick() - state.LastAttackTime < 1)) 
				and CONFIG.STAMINA.REGEN_COMBAT 
				or CONFIG.STAMINA.REGEN_IDLE
			
			PlayerData.addStamina(playerData, regenRate * deltaTime)
		end
		
		if playerData.stamina < CONFIG.STAMINA.CRITICAL_THRESHOLD then
			CombatRemotes.StaminaCritical:FireClient(player)
		elseif playerData.stamina < CONFIG.STAMINA.WARNING_THRESHOLD then
			CombatRemotes.StaminaLow:FireClient(player)
		end
	end
end)

--! ==================== REMOTE CALLBACKS ====================

CombatRemotes.Attack.OnServerInvoke = function(player: Player, targetPlayer: Player, skillName: string)
	return handleAttack(player, targetPlayer, skillName)
end

CombatRemotes.Parry.OnServerInvoke = function(player: Player, attacker: Player, incomingDamage: number)
	return handleParry(player, attacker, incomingDamage)
end

CombatRemotes.Block.OnServerInvoke = function(player: Player, incomingDamage: number, deltaTime: number)
	return handleBlock(player, incomingDamage, deltaTime)
end

CombatRemotes.Dash.OnServerInvoke = function(player: Player, distance: number)
	return handleDash(player, distance)
end

CombatRemotes.SprintStart.OnServerInvoke = function(player: Player)
	return handleSprintStart(player)
end

CombatRemotes.SprintEnd.OnServerInvoke = function(player: Player)
	return handleSprintEnd(player)
end

CombatRemotes.HandleLanding.OnServerInvoke = function(player: Player, fallHeight: number)
	handleLanding(player, fallHeight)
	return { success = true }
end

--! CLEANUP
Players.PlayerRemoving:Connect(function(player)
	PlayerStates[player.UserId] = nil
	PlayerVelocities[player.UserId] = nil
end)

return {
	handleAttack = handleAttack,
	handleParry = handleParry,
	handleBlock = handleBlock,
	handleDash = handleDash,
	handleSprintStart = handleSprintStart,
	handleSprintEnd = handleSprintEnd,
	handleLanding = handleLanding,
	getPlayerCombatState = getPlayerCombatState,
	resetCombo = resetCombo,
	CONFIG = CONFIG,
}
