--!strict
--[[
	TestDummySpawner.server.lua - Spawns AI test dummies for combat practice
	
	3 Types:
	1. AGGRESSIVE DUMMY - Attacks player periodically
	2. DEFENSIVE DUMMY - Blocks and parries player attacks  
	3. BALANCED DUMMY - Mixes attack/defense/dash
	
	File: src/server/TestDummySpawner.server.lua
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- CONFIG
-- ============================================================

local DUMMY_CONFIG = {
	BASE_SIZE = Vector3.new(2, 6, 2),
	BASE_SPEED = 16,
	
	AGGRESSIVE = {
		attackCooldown = 1.5,
		attackRange = 16,
		attackDamage = 15,
		moveChance = 0.3,
		attackChance = 0.7,
		parryChance = 0.1,
		blockChance = 0.05,
	},
	
	DEFENSIVE = {
		attackCooldown = 2.5,
		attackRange = 16,
		attackDamage = 10,
		moveChance = 0.2,
		attackChance = 0.3,
		parryChance = 0.6,
		blockChance = 0.4,
	},
	
	BALANCED = {
		attackCooldown = 2.0,
		attackRange = 16,
		attackDamage = 12,
		moveChance = 0.4,
		attackChance = 0.5,
		parryChance = 0.4,
		blockChance = 0.2,
	},
}

-- ============================================================
-- DUMMY STATE TYPE
-- ============================================================

type DummyState = {
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	dummyType: string, -- "AGGRESSIVE" | "DEFENSIVE" | "BALANCED"
	lastAttackTime: number,
	isBlocking: boolean,
	targetPlayer: Player?,
	comboCount: number,
	health: number,
	maxHealth: number,
}

-- ============================================================
-- SPAWN DUMMY
-- ============================================================

local function spawnDummy(position: Vector3, dummyType: string): DummyState
	--!strict
	local model = Instance.new("Model")
	model.Name = "TestDummy_" .. dummyType
	
	-- Root Part
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Shape = Enum.PartType.Cylinder
	rootPart.Size = DUMMY_CONFIG.BASE_SIZE
	rootPart.CanCollide = false
	rootPart.CFrame = CFrame.new(position)
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.Parent = model
	
	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.CanCollide = true
	head.CFrame = rootPart.CFrame + Vector3.new(0, 4, 0)
	head.Parent = model
	
	-- Connect head to root
	local neck = Instance.new("WeldConstraint")
	neck.Part0 = rootPart
	neck.Part1 = head
	neck.Parent = head
	
	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	
	model.Parent = workspace
	
	local state: DummyState = {
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		dummyType = dummyType,
		lastAttackTime = 0,
		isBlocking = false,
		targetPlayer = nil,
		comboCount = 0,
		health = 100,
		maxHealth = 100,
	}
	
	-- Color by type
	local color = Color3.fromRGB(100, 100, 100) -- Gray default
	if dummyType == "AGGRESSIVE" then
		color = Color3.fromRGB(255, 0, 0) -- Red
	elseif dummyType == "DEFENSIVE" then
		color = Color3.fromRGB(0, 0, 255) -- Blue
	elseif dummyType == "BALANCED" then
		color = Color3.fromRGB(255, 165, 0) -- Orange
	end
	
	rootPart.Color = color
	head.Color = color
	
	-- Tag for identification
	local tag = Instance.new("StringValue")
	tag.Name = "DummyType"
	tag.Value = dummyType
	tag.Parent = model
	
	print("✅ Spawned " .. dummyType .. " dummy at " .. tostring(position))
	
	return state
end

-- ============================================================
-- AI BEHAVIOR
-- ============================================================

local function getDummyConfig(dummyType: string)
	if dummyType == "AGGRESSIVE" then
		return DUMMY_CONFIG.AGGRESSIVE
	elseif dummyType == "DEFENSIVE" then
		return DUMMY_CONFIG.DEFENSIVE
	elseif dummyType == "BALANCED" then
		return DUMMY_CONFIG.BALANCED
	end
	return DUMMY_CONFIG.BALANCED
end

local function findNearestPlayer(dummy: DummyState): Player?
	--!strict
	local nearestPlayer = nil
	local nearestDistance = math.huge
	
	for _, player in pairs(Players:GetPlayers()) do
		if not player.Character then continue end
		
		local distance = (dummy.rootPart.Position - player.Character.PrimaryPart.Position).Magnitude
		if distance < nearestDistance and distance < 50 then
			nearestDistance = distance
			nearestPlayer = player
		end
	end
	
	return nearestPlayer
end

local function dummyAttack(dummy: DummyState)
	--!strict
	if not dummy.targetPlayer or not dummy.targetPlayer.Character then return end
	
	local config = getDummyConfig(dummy.dummyType)
	if tick() - dummy.lastAttackTime < config.attackCooldown then return end
	
	local distance = (dummy.rootPart.Position - dummy.targetPlayer.Character.PrimaryPart.Position).Magnitude
	if distance > config.attackRange then return end
	
	dummy.lastAttackTime = tick()
	
	-- Simulate attack animation
	print("⚡ " .. dummy.dummyType .. " Dummy ATTACKS!")
end

local function dummyBlock(dummy: DummyState)
	--!strict
	if dummy.isBlocking then return end
	
	dummy.isBlocking = true
	print("🛡️  " .. dummy.dummyType .. " Dummy is BLOCKING")
	
	task.wait(2)
	dummy.isBlocking = false
	print("⏹️  " .. dummy.dummyType .. " Dummy stopped blocking")
end

local function dummyMove(dummy: DummyState)
	--!strict
	if not dummy.targetPlayer or not dummy.targetPlayer.Character then return end
	
	local targetPos = dummy.targetPlayer.Character.PrimaryPart.Position
	local direction = (targetPos - dummy.rootPart.Position).Unit
	
	-- Move toward player
	local bodyVelocity = dummy.rootPart:FindFirstChild("BodyVelocity")
	if not bodyVelocity then
		bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Parent = dummy.rootPart
	end
	
	bodyVelocity.Velocity = direction * DUMMY_CONFIG.BASE_SPEED
end

local function dummyTakeDamage(dummy: DummyState, damage: number)
	--!strict
	dummy.health = math.max(0, dummy.health - damage)
	dummy.humanoid.Health = dummy.health
	
	print("💔 " .. dummy.dummyType .. " Dummy took " .. damage .. " damage! (Health: " .. dummy.health .. "/" .. dummy.maxHealth .. ")")
	
	if dummy.health <= 0 then
		print("💀 " .. dummy.dummyType .. " Dummy defeated!")
		task.wait(2)
		dummy.model:Destroy()
	end
end

-- ============================================================
-- AI LOOP
-- ============================================================

local dummies: { DummyState } = {}

local function updateDummyAI(dummy: DummyState)
	--!strict
	-- Find nearest player
	dummy.targetPlayer = findNearestPlayer(dummy)
	
	if not dummy.targetPlayer then
		-- Idle
		return
	end
	
	local config = getDummyConfig(dummy.dummyType)
	local rand = math.random()
	
	-- Decide action
	if rand < config.blockChance then
		dummyBlock(dummy)
	elseif rand < config.blockChance + config.attackChance then
		dummyAttack(dummy)
	elseif rand < config.blockChance + config.attackChance + config.moveChance then
		dummyMove(dummy)
	end
end

RunService.Heartbeat:Connect(function()
	for i, dummy in ipairs(dummies) do
		if not dummy.model.Parent then
			table.remove(dummies, i)
			continue
		end
		
		updateDummyAI(dummy)
	end
end)

-- ============================================================
-- SPAWN DUMMIES ON PLAYER JOIN
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	task.wait(0.5) -- Wait for character to load
	
	if not player.Character then return end
	
	local spawnPos = player.Character.PrimaryPart.Position + Vector3.new(15, 0, 0)
	
	-- Spawn 3 test dummies
	local aggressiveDummy = spawnDummy(spawnPos, "AGGRESSIVE")
	local defensiveDummy = spawnDummy(spawnPos + Vector3.new(10, 0, 0), "DEFENSIVE")
	local balancedDummy = spawnDummy(spawnPos + Vector3.new(20, 0, 0), "BALANCED")
	
	table.insert(dummies, aggressiveDummy)
	table.insert(dummies, defensiveDummy)
	table.insert(dummies, balancedDummy)
	
	print("🎯 Spawned 3 test dummies for player " .. player.Name)
end)

-- ============================================================
-- CLEANUP
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	-- Dummies auto-cleanup when player leaves
	for i, dummy in ipairs(dummies) do
		if dummy.model and dummy.model.Parent then
			dummy.model:Destroy()
		end
	end
	dummies = {}
end)

print("✅ TestDummySpawner loaded - 3 dummies will spawn per player")
