--!strict
--[[
	TestDummySpawner.server.lua - FIXED VERSION (Visible Dummies)
	Spawns AI test dummies with visible humanoids for combat practice
	
	3 Types:
	1. AGGRESSIVE DUMMY - Red, attacks 70% of time
	2. DEFENSIVE DUMMY - Blue, blocks/parries 60% of time
	3. BALANCED DUMMY - Orange, even mix
	
	Path: src/server/TestDummySpawner.server.lua
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- CONFIG
-- ============================================================

local DUMMY_CONFIG = {
	BASE_SIZE = Vector3.new(2, 5, 2),
	BASE_SPEED = 16,
	
	AGGRESSIVE = {
		attackCooldown = 1.5,
		attackRange = 16,
		moveChance = 0.3,
		attackChance = 0.7,
		parryChance = 0.1,
		blockChance = 0.05,
	},
	
	DEFENSIVE = {
		attackCooldown = 2.5,
		attackRange = 16,
		moveChance = 0.2,
		attackChance = 0.3,
		parryChance = 0.6,
		blockChance = 0.4,
	},
	
	BALANCED = {
		attackCooldown = 2.0,
		attackRange = 16,
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
	dummyType: string,
	lastAttackTime: number,
	isBlocking: boolean,
	targetPlayer: Player?,
	health: number,
	maxHealth: number,
}

-- ============================================================
-- SPAWN VISIBLE DUMMY
-- ============================================================

local function spawnDummy(position: Vector3, dummyType: string): DummyState
	--!strict
	local model = Instance.new("Model")
	model.Name = "TestDummy_" .. dummyType
	
	-- Root Part (HumanoidRootPart)
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
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.CanCollide = true
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent = model
	
	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Shape = Enum.PartType.Block
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.CanCollide = true
	leftArm.Parent = model
	
	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Shape = Enum.PartType.Block
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.CanCollide = true
	rightArm.Parent = model
	
	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Shape = Enum.PartType.Block
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.CanCollide = true
	leftLeg.Parent = model
	
	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Shape = Enum.PartType.Block
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.CanCollide = true
	rightLeg.Parent = model
	
	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	
	-- Set Color by Type
	local color = Color3.fromRGB(100, 100, 100)
	if dummyType == "AGGRESSIVE" then
		color = Color3.fromRGB(255, 0, 0) -- Red
	elseif dummyType == "DEFENSIVE" then
		color = Color3.fromRGB(0, 0, 255) -- Blue
	elseif dummyType == "BALANCED" then
		color = Color3.fromRGB(255, 165, 0) -- Orange
	end
	
	-- Apply colors to all parts
	for _, part in pairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	
	-- Position body parts relative to root
	local function weld(part0: BasePart, part1: BasePart, offset: CFrame)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part0
		weld.Part1 = part1
		weld.Parent = part1
		part1.CFrame = part0.CFrame * offset
	end
	
	-- Weld parts together
	weld(rootPart, head, CFrame.new(0, 2.5, 0))
	weld(rootPart, leftArm, CFrame.new(-2, 1.5, 0))
	weld(rootPart, rightArm, CFrame.new(2, 1.5, 0))
	weld(rootPart, leftLeg, CFrame.new(-0.5, -2.5, 0))
	weld(rootPart, rightLeg, CFrame.new(0.5, -2.5, 0))
	
	model.Parent = workspace
	
	local state: DummyState = {
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		dummyType = dummyType,
		lastAttackTime = 0,
		isBlocking = false,
		targetPlayer = nil,
		health = 100,
		maxHealth = 100,
	}
	
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
	print("⚡ " .. dummy.dummyType .. " Dummy ATTACKS player!")
end

local function dummyBlock(dummy: DummyState)
	--!strict
	if dummy.isBlocking then return end
	
	dummy.isBlocking = true
	print("🛡️  " .. dummy.dummyType .. " Dummy BLOCKING")
	
	task.wait(1.5)
	dummy.isBlocking = false
end

local function dummyMove(dummy: DummyState)
	--!strict
	if not dummy.targetPlayer or not dummy.targetPlayer.Character then return end
	
	local targetPos = dummy.targetPlayer.Character.PrimaryPart.Position
	local direction = (targetPos - dummy.rootPart.Position).Unit
	
	-- Simple movement toward player
	dummy.rootPart.CFrame = dummy.rootPart.CFrame + (direction * 0.5)
end

local function dummyTakeDamage(dummy: DummyState, damage: number)
	--!strict
	dummy.health = math.max(0, dummy.health - damage)
	dummy.humanoid.Health = dummy.health
	
	print("💔 " .. dummy.dummyType .. " took " .. damage .. " damage! HP: " .. dummy.health .. "/100")
	
	if dummy.health <= 0 then
		print("💀 " .. dummy.dummyType .. " DEFEATED!")
		task.wait(3)
		dummy.model:Destroy()
	end
end

-- ============================================================
-- AI LOOP
-- ============================================================

local dummies: { DummyState } = {}

local function updateDummyAI(dummy: DummyState)
	--!strict
	dummy.targetPlayer = findNearestPlayer(dummy)
	
	if not dummy.targetPlayer then return end
	
	local config = getDummyConfig(dummy.dummyType)
	local rand = math.random()
	
	if rand < config.blockChance then
		dummyBlock(dummy)
	elseif rand < config.blockChance + config.attackChance then
		dummyAttack(dummy)
	elseif rand < config.blockChance + config.attackChance + config.moveChance then
		dummyMove(dummy)
	end
end

RunService.Heartbeat:Connect(function()
	for i = #dummies, 1, -1 do
		local dummy = dummies[i]
		if not dummy.model.Parent then
			table.remove(dummies, i)
		else
			updateDummyAI(dummy)
		end
	end
end)

-- ============================================================
-- SPAWN ON PLAYER JOIN
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	task.wait(1) -- Wait for character
	
	if not player.Character then return end
	
	local spawnPos = player.Character.PrimaryPart.Position + Vector3.new(15, 0, 0)
	
	local aggressive = spawnDummy(spawnPos, "AGGRESSIVE")
	local defensive = spawnDummy(spawnPos + Vector3.new(10, 0, 0), "DEFENSIVE")
	local balanced = spawnDummy(spawnPos + Vector3.new(20, 0, 0), "BALANCED")
	
	table.insert(dummies, aggressive)
	table.insert(dummies, defensive)
	table.insert(dummies, balanced)
	
	print("🎯 Spawned 3 visible dummies for " .. player.Name)
end)

-- ============================================================
-- CLEANUP
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	for i = #dummies, 1, -1 do
		if dummies[i].model and dummies[i].model.Parent then
			dummies[i].model:Destroy()
		end
		table.remove(dummies, i)
	end
end)

print("✅ TestDummySpawner loaded - 3 VISIBLE dummies will spawn per player")
