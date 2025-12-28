--!strict
--[[
	CombatCore.server.luau
	Server-authoritative combat system
	Handles: Combo tracking, parry/block, damage, corruption integration
	
	SYSTEMS:
	- Combo counter (1/2/3, resets on miss or dash)
	- Parry mechanic (0.5s window, chip damage reflection)
	- Block mechanic (hold F, stamina drain, damage reduction)
	- Dash (directional, distance-based stamina, resets combo)
	- Corruption effects (damage multiplier, cooldown penalties)
	- Server validation (distance, cooldown, stamina, position)
]]

--! Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--! Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerData = require(Shared:WaitForChild("PlayerData"))
local Stamina = require(Shared:WaitForChild("Stamina"))
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
}

--! GLOBAL STATE
local PlayerStates: { [number]: PlayerCombatState } = {}

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
		}
	end
	
	return PlayerStates[userId]
end

local function validateAttack(
	attacker: Player,
	targetPlayer: Player,
	distance: number
): (boolean, string)
	--! Check distance
	if distance > CONFIG.VALIDATION.MELEE_RANGE then
		return false, "Target too far away"
	end
	
	--! Check if overloaded
	local playerData = PlayerData:GetPlayerData(attacker.UserId)
	if playerData.corruption >= 100 then
		return false, "Overloaded, cannot attack"
	end
	
	--! Check position validity (prevent teleport hacks)
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
	local playerData = PlayerData:GetPlayerData(attacker.UserId)
	
	--! Apply corruption multiplier
	local corruptionMultiplier = CorruptionCalc.getDamageMultiplier(playerData.corruption)
	
	--! Apply combo multiplier (each hit worth more)
	local comboMultiplier = 1.0 + (comboCount * 0.1)
	
	local damage = baseDamage * corruptionMultiplier * comboMultiplier
	return math.floor(damage)
end

local function applyCorruptionPenalty(
	cooldown: number,
	attacker: Player
): number
	local playerData = PlayerData:GetPlayerData(attacker.UserId)
	local penalty = CorruptionCalc.getCooldownPenalty(playerData.corruption)
	return cooldown + penalty
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
	
	--! Check if combo expired
	if tick() - state.LastComboHitTime > CONFIG.COMBO.RESET_TIMEOUT then
		state.ComboCount = 0
	end
	
	--! Increment combo (max 3)
	state.ComboCount = math.min(state.ComboCount + 1, CONFIG.COMBO.MAX_HITS)
	state.LastComboHitTime = tick()
	
	--! Update client
	CombatRemotes.UpdateComboCounter:FireClient(player, state.ComboCount)
	
	return state.ComboCount
end

--! MAIN COMBAT HANDLERS
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
	
	--! Deduct stamina
	Stamina:DeductStamina(attacker.UserId, 10)
	
	--! Set last attack time
	state.LastAttackTime = tick()
	
	--! Update position
	state.LastPosition = attacker.Character.PrimaryPart.Position
	
	return {
		success = true,
		damage = damage,
		message = "Attack hit combo " .. comboCount,
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
	
	local defenderData = PlayerData:GetPlayerData(defender.UserId)
	local state = getPlayerCombatState(defender)
	
	--! Simulate parry window success (in real game, would be based on timing)
	local parrySuccess = math.random(1, 100) > 30 --! 70% success for testing
	
	if parrySuccess then
		--! PARRY SUCCESS
		--! Calculate chip damage to attacker
		local chipDamage = incomingDamage * (CONFIG.PARRY.CHIP_DAMAGE_MIN + 
			math.random() * (CONFIG.PARRY.CHIP_DAMAGE_MAX - CONFIG.PARRY.CHIP_DAMAGE_MIN))
		chipDamage = math.floor(chipDamage)
		
		--! No stamina cost on success
		--! Stun attacker
		--! Counter window for defender
		
		return {
			success = true,
			damage = 0,
			chipDamage = chipDamage,
			message = "Parry successful! " .. chipDamage .. " chip damage",
		}
	else
		--! PARRY FAIL
		--! Deduct stamina
		Stamina:DeductStamina(defender.UserId, CONFIG.PARRY.STAMINA_COST_FAIL)
		
		--! Brief stun
		state.IsRecovering = true
		state.RecoveryEndTime = tick() + CONFIG.PARRY.PARRIER_STUN_FAIL
		
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
	
	if not state.IsBlocking then
		state.IsBlocking = true
		state.BlockStartTime = tick()
	end
	
	--! Stamina cost (per second)
	local staminaCost = CONFIG.BLOCK.STAMINA_COST_PER_SECOND * deltaTime
	Stamina:DeductStamina(defender.UserId, staminaCost)
	
	--! Damage reduction
	local damageReduction = CONFIG.BLOCK.DAMAGE_REDUCTION_MIN + 
		math.random() * (CONFIG.BLOCK.DAMAGE_REDUCTION_MAX - CONFIG.BLOCK.DAMAGE_REDUCTION_MIN)
	local damageAfterBlock = incomingDamage * (1 - damageReduction)
	damageAfterBlock = math.floor(damageAfterBlock)
	
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
	local playerData = PlayerData:GetPlayerData(player.UserId)
	
	--! Check cooldown
	if tick() - state.LastDashTime < CONFIG.DASH.COOLDOWN then
		return {
			success = false,
			staminaCost = 0,
			message = "Dash still on cooldown",
		}
	end
	
	--! Clamp distance
	distance = math.min(distance, CONFIG.DASH.MAX_DISTANCE)
	
	--! Calculate stamina cost
	local staminaCost = CONFIG.DASH.BASE_STAMINA + (distance * CONFIG.DASH.STAMINA_PER_METER)
	staminaCost = math.floor(staminaCost)
	
	--! Check stamina
	if playerData.stamina < staminaCost then
		return {
			success = false,
			staminaCost = 0,
			message = "Not enough stamina for dash",
		}
	end
	
	--! Apply dash
	Stamina:DeductStamina(player.UserId, staminaCost)
	state.LastDashTime = tick()
	state.IsDashing = true
	state.DashEndTime = tick() + CONFIG.DASH.IMMUNITY_DURATION
	
	--! Reset combo on dash
	resetCombo(player)
	
	return {
		success = true,
		staminaCost = staminaCost,
		message = "Dashed " .. distance .. "m, cost " .. staminaCost .. " stamina",
	}
end

--! SETUP REMOTES
CombatRemotes.Attack:OnInvoke(function(player: Player, targetPlayer: Player, skillName: string)
	return handleAttack(player, targetPlayer, skillName)
end)

CombatRemotes.Parry:OnInvoke(function(player: Player, attacker: Player, incomingDamage: number)
	return handleParry(player, attacker, incomingDamage)
end)

CombatRemotes.Block:OnInvoke(function(player: Player, incomingDamage: number, deltaTime: number)
	return handleBlock(player, incomingDamage, deltaTime)
end)

CombatRemotes.Dash:OnInvoke(function(player: Player, distance: number)
	return handleDash(player, distance)
end)

--! CLEANUP ON PLAYER LEAVE
Players.PlayerRemoving:Connect(function(player)
	PlayerStates[player.UserId] = nil
end)

return {
	handleAttack = handleAttack,
	handleParry = handleParry,
	handleBlock = handleBlock,
	handleDash = handleDash,
	getPlayerCombatState = getPlayerCombatState,
	resetCombo = resetCombo,
	CONFIG = CONFIG,
}
