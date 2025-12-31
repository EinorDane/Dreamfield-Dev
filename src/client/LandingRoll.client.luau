--!strict
--[[
	LandingRoll.client.lua - VOLUNTARY LANDING ROLL
	Player presses SPACE near ground to do landing roll and mitigate fall damage
	NOT automatic - must be player choice!
	
	CONTROLS:
	- Jump: Space
	- Space (while falling/near ground): Perform landing roll (mitigates damage)
	
	Path: src/client/LandingRoll.client.lua
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--! Player & Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

--! Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRemotes = require(Shared:WaitForChild("CombatRemotes"))

--! CONFIG
local ROLL_CONFIG = {
	MIN_FALL_HEIGHT = 3, -- Minimum fall distance to trigger roll
	GROUND_TOLERANCE = 5, -- Must be within 5 studs of ground to roll
	ROLL_COOLDOWN = 1.5, -- Can't spam rolls
	DAMAGE_MITIGATION = 0.5, -- Reduces fall damage by 50%
}

--! STATE
local RollState = {
	lastRollTime = 0,
	lastYPosition = humanoidRootPart.Position.Y,
	isFalling = false,
	fallStartHeight = 0,
	canRoll = true,
}

--! ==================== DETECT FALLING ====================

local function updateFallHeight()
	RollState.lastYPosition = humanoidRootPart.Position.Y
end

local function checkIfFalling()
	local humanoidState = humanoid:GetState()
	
	-- Falling states in Roblox
	if humanoidState == Enum.HumanoidStateType.Falling or 
	   humanoidState == Enum.HumanoidStateType.Freefall or
	   humanoidState == Enum.HumanoidStateType.Flying then
		if not RollState.isFalling then
			RollState.isFalling = true
			RollState.fallStartHeight = humanoidRootPart.Position.Y
			print("📉 Falling... (prepare to roll with Space)")
		end
	else
		RollState.isFalling = false
	end
end

local function getDistanceToGround(): number
	--!strict
	local rayOrigin = humanoidRootPart.Position
	local rayDirection = Vector3.new(0, -100, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}
	
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if rayResult then
		return (rayResult.Position - humanoidRootPart.Position).Magnitude
	end
	
	return math.huge
end

--! ==================== LANDING ROLL ====================

local function performLandingRoll()
	if tick() - RollState.lastRollTime < ROLL_CONFIG.ROLL_COOLDOWN then
		print("⏳ Roll on cooldown")
		return false
	end
	
	-- Check if actually falling
	if not RollState.isFalling then
		print("❌ Not falling - can't roll")
		return false
	end
	
	-- Check if close to ground
	local distToGround = getDistanceToGround()
	if distToGround > ROLL_CONFIG.GROUND_TOLERANCE then
		print("❌ Too high to roll! Need to be within " .. ROLL_CONFIG.GROUND_TOLERANCE .. "m of ground")
		return false
	end
	
	-- Calculate fall distance
	local fallDistance = RollState.fallStartHeight - humanoidRootPart.Position.Y
	if fallDistance < ROLL_CONFIG.MIN_FALL_HEIGHT then
		print("ℹ️  Fall too short to need a roll")
		return false
	end
	
	-- PERFORM ROLL
	RollState.lastRollTime = tick()
	RollState.isFalling = false
	
	-- Tell server about roll
	local result = CombatRemotes.HandleLanding:InvokeServer(fallDistance, true) -- true = voluntary roll
	
	if result then
		print("🏃 Landing roll! Damage mitigated by " .. (ROLL_CONFIG.DAMAGE_MITIGATION * 100) .. "%")
		return true
	else
		print("❌ Roll failed")
		return false
	end
end

--! ==================== INPUT HANDLING ====================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- SPACE for rolling (or normal jump if not falling)
	if input.KeyCode == Enum.KeyCode.Space then
		if RollState.isFalling and RollState.canRoll then
			-- Try to roll instead of just jumping
			local rollSuccess = performLandingRoll()
			if rollSuccess then
				-- Prevent normal jump if roll was successful
			end
		end
	end
end)

--! ==================== MAIN LOOP ====================

RunService.Heartbeat:Connect(function()
	checkIfFalling()
	updateFallHeight()
end)

--! ==================== CHARACTER RESPAWN ====================

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")
	
	RollState = {
		lastRollTime = 0,
		lastYPosition = humanoidRootPart.Position.Y,
		isFalling = false,
		fallStartHeight = 0,
		canRoll = true,
	}
	
	print("🔄 Roll system reset")
end)

print("✅ Landing roll system loaded - Press SPACE while falling to roll (voluntary)")
