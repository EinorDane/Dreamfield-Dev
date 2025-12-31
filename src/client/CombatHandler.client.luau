--!strict
--[[
	CombatHandler.client.luau - ENHANCED VERSION
	Client-side input handling for combat + mobility
	
	CONTROLS:
	- LMB: Attack (combo 1/2/3) - works WITHOUT target (practice mode)
	- F: HOLD = Block, TAP = Parry (0.5s window)
	- Shift: Sprint (continuous, stamina drain)
	- Q: Dash (directional)
	
	Path: src/client/CombatHandler.client.lua
]]

--! Services
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
local CONFIG = {
	ATTACK = {
		COOLDOWN = 0.4,
		RANGE = 16,
	},
	PARRY = {
		WINDOW = 0.5,
		COOLDOWN = 1.0,
		TAP_THRESHOLD = 0.2, -- If F held < 200ms = parry attempt
	},
	DASH = {
		COOLDOWN = 2.0,
	},
	SPRINT = {
		SPEED_MULTIPLIER = 1.5,
	},
	FALL = {
		TRACK_THRESHOLD = 1.0,
	},
}

--! STATE
local InputState = {
	IsAttacking = false,
	LastAttackTime = 0,
	IsParrying = false,
	LastParryTime = 0,
	IsDashing = false,
	LastDashTime = 0,
	IsSprinting = false,
	IsBlocking = false,
	IsWallSliding = false,
	ComboCount = 0,
	LastYPosition = 0,
	IsFalling = false,
	
	-- F-KEY STATE
	FKeyHeldTime = 0,
	FKeyPressed = false,
}

--! ==================== COMBAT FUNCTIONS ====================

local function handleAttack()
	if InputState.IsAttacking then return end
	if tick() - InputState.LastAttackTime < CONFIG.ATTACK.COOLDOWN then return end
	
	-- Try to find nearest player (for actual combat)
	local nearestPlayer = nil
	local nearestDistance = CONFIG.ATTACK.RANGE
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer == player or not otherPlayer.Character then continue end
		
		local distance = (humanoidRootPart.Position - otherPlayer.Character.PrimaryPart.Position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestPlayer = otherPlayer
		end
	end
	
	-- ALLOW TARGETLESS ATTACKS (practice mode)
	InputState.IsAttacking = true
	InputState.LastAttackTime = tick()
	
	if nearestPlayer then
		-- Attack with target
		local result = CombatRemotes.Attack:InvokeServer(nearestPlayer, "MeleeAttack")
		if result.success then
			print("✅ Attack hit! Damage: " .. result.damage .. " - " .. result.message)
			InputState.ComboCount = InputState.ComboCount + 1
		else
			print("❌ Attack missed: " .. result.message)
		end
	else
		-- Targetless attack (practice/dummy)
		print("✨ Practice swing! (No target)")
		InputState.ComboCount = InputState.ComboCount + 1
	end
	
	InputState.IsAttacking = false
end

local function handleParryAttempt()
	if InputState.IsParrying then return end
	if tick() - InputState.LastParryTime < CONFIG.PARRY.COOLDOWN then return end
	
	-- Try to find nearest player to parry against
	local nearestAttacker = nil
	local nearestDistance = CONFIG.ATTACK.RANGE
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer == player or not otherPlayer.Character then continue end
		
		local distance = (humanoidRootPart.Position - otherPlayer.Character.PrimaryPart.Position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestAttacker = otherPlayer
		end
	end
	
	-- Note: Parrying usually requires an incoming attack, but we allow the input for visual feedback
	InputState.IsParrying = true
	InputState.LastParryTime = tick()
	
	if nearestAttacker then
		local result = CombatRemotes.Parry:InvokeServer(nearestAttacker, 20)
		if result.success then
			print("✅ Parry successful! Chip damage: " .. result.chipDamage)
		else
			print("❌ Parry failed! " .. result.message)
		end
	else
		print("⚔️  Parry stance ready (No enemy)")
	end
	
	InputState.IsParrying = false
end

local function handleBlockStart()
	if InputState.IsBlocking then return end
	
	InputState.IsBlocking = true
	InputState.FKeyHeldTime = tick()
	CombatRemotes.BlockStarted:FireServer()
	print("🛡️  Block started (holding F)")
end

local function handleBlockEnd()
	if not InputState.IsBlocking then return end
	
	InputState.IsBlocking = false
	CombatRemotes.BlockEnded:FireServer()
	print("⏹️  Block ended")
end

local function handleDash()
	if InputState.IsDashing then return end
	if tick() - InputState.LastDashTime < CONFIG.DASH.COOLDOWN then
		print("⏳ Dash on cooldown")
		return
	end
	
	local camera = workspace.CurrentCamera
	local direction = camera.CFrame.LookVector
	local distance = 15 -- Default dash distance
	
	InputState.IsDashing = true
	InputState.LastDashTime = tick()
	
	local result = CombatRemotes.Dash:InvokeServer(distance)
	
	if result.success then
		print("✅ Dashed! Cost: " .. result.staminaCost .. " stamina")
		-- Client-side prediction for dash velocity
		humanoidRootPart.Velocity = direction * 100
	else
		print("❌ Dash failed: " .. result.message)
	end
	
	InputState.IsDashing = false
end

local function handleSprintStart()
	if InputState.IsSprinting then return end
	
	InputState.IsSprinting = true
	
	local result = CombatRemotes.SprintStart:InvokeServer()
	
	if result.success then
		print("🏃 Sprint started")
		CombatRemotes.SprintStarted:FireServer()
	else
		print("❌ Sprint failed: " .. result.message)
		InputState.IsSprinting = false
	end
end

local function handleSprintEnd()
	if not InputState.IsSprinting then return end
	
	InputState.IsSprinting = false
	
	local result = CombatRemotes.SprintEnd:InvokeServer()
	
	if result.success then
		print("⏹️  Sprint ended")
		CombatRemotes.SprintEnded:FireServer()
	end
end

--! ==================== F-KEY SPECIAL HANDLING ====================

local function handleFKeyPressed()
	if InputState.FKeyPressed then return end
	
	InputState.FKeyPressed = true
	InputState.FKeyHeldTime = tick()
	
	-- Start block immediately on press
	handleBlockStart()
end

local function handleFKeyReleased()
	if not InputState.FKeyPressed then return end
	
	InputState.FKeyPressed = false
	local holdDuration = tick() - InputState.FKeyHeldTime
	
	-- End block
	handleBlockEnd()
	
	-- If held for less than TAP_THRESHOLD, treat as parry attempt
	if holdDuration < CONFIG.PARRY.TAP_THRESHOLD then
		print("⚡ Quick tap detected - attempting parry")
		handleParryAttempt()
	end
end

--! PHYSICS & MOBILITY TRACKING

local function trackFallHeight()
	InputState.LastYPosition = humanoidRootPart.Position.Y
end

local function checkFallDamage()
	local currentY = humanoidRootPart.Position.Y
	local fallDistance = InputState.LastYPosition - currentY
	
	if fallDistance > CONFIG.FALL.TRACK_THRESHOLD and humanoid.Health > 0 then
		InputState.IsFalling = true
		
		-- Wait briefly to confirm landing or continued fall
		task.wait(0.5)
		
		if humanoid.Health > 0 then
			local result = CombatRemotes.HandleLanding:InvokeServer(fallDistance)
			if result then
				-- Landing logic handled on server (damage/roll)
			end
		end
		
		InputState.IsFalling = false
	end
	
	trackFallHeight()
end

--! MAIN LOOP
RunService.Heartbeat:Connect(function(deltaTime)
	checkFallDamage()
	
	-- Sprint Speed Modifier
	if InputState.IsSprinting then
		humanoid.WalkSpeed = 16 * CONFIG.SPRINT.SPEED_MULTIPLIER
	else
		humanoid.WalkSpeed = 16
	end
end)

--! ==================== INPUT BINDINGS ====================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleAttack()
	elseif input.KeyCode == Enum.KeyCode.F then
		handleFKeyPressed()
	elseif input.KeyCode == Enum.KeyCode.Q then
		handleDash()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		handleSprintStart()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.F then
		handleFKeyReleased()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		handleSprintEnd()
	end
end)

--! ==================== REMOTE EVENT LISTENERS ====================

CombatRemotes.UpdateComboCounter.OnClientEvent:Connect(function(comboCount: number)
	InputState.ComboCount = comboCount
	print("📊 Combo: " .. comboCount .. "/3")
end)

CombatRemotes.ApplyKnockback.OnClientEvent:Connect(function(velocity: Vector3)
	humanoidRootPart.Velocity = velocity
	print("💥 Knockback applied!")
end)

CombatRemotes.TriggerRagdoll.OnClientEvent:Connect(function(duration: number)
	print("🎭 Ragdoll triggered for " .. duration .. "s")
end)

CombatRemotes.LandingRoll.OnClientEvent:Connect(function()
	print("🏃 Landing roll executed!")
end)

CombatRemotes.TakeFallDamage.OnClientEvent:Connect(function(damage: number, fallType: string)
	print("💔 Fall damage: " .. damage .. " (" .. fallType .. ")")
end)

CombatRemotes.StaminaLow.OnClientEvent:Connect(function()
	print("⚠️  Stamina low!")
end)

CombatRemotes.StaminaCritical.OnClientEvent:Connect(function()
	print("🔴 Stamina critical!")
end)

CombatRemotes.SprintStarted.OnClientEvent:Connect(function()
	print("🏃 Sprint active")
end)

CombatRemotes.SprintEnded.OnClientEvent:Connect(function()
	print("⏹️  Sprint stopped")
end)

CombatRemotes.BlockStarted.OnClientEvent:Connect(function()
	print("🛡️  Blocking...")
end)

CombatRemotes.BlockEnded.OnClientEvent:Connect(function()
	print("⏹️  Block released")
end)

--! CHARACTER RESPAWN
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")
	
	-- Reset Input State
	InputState = {
		IsAttacking = false,
		LastAttackTime = 0,
		IsParrying = false,
		LastParryTime = 0,
		IsDashing = false,
		LastDashTime = 0,
		IsSprinting = false,
		IsBlocking = false,
		IsWallSliding = false,
		ComboCount = 0,
		LastYPosition = 0,
		IsFalling = false,
		FKeyHeldTime = 0,
		FKeyPressed = false,
	}
	
	print("🔄 Character respawned, combat handler reset")
end)

print("✅ CombatHandler loaded - Controls: LMB=Attack, F-HOLD=Block/TAP=Parry, Q=Dash, Shift=Sprint")
