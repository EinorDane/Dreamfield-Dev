--!strict
--[[
	CombatHandler.client.luau - ENHANCED WITH SPRINT & MOBILITY INPUT
	Client-side input handling for combat + mobility
	Communicates with CombatCore.server via remotes
	
	CONTROLS:
	- LMB: Attack (1/2/3 combo)
	- F: Parry (0.5s window)
	- Shift: Sprint (continuous, stamina drain)
	- Q: Dash (directional)
	- E: Block (hold)
	- 1-5: Shard skills (future)
]]

--!strict

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRemotes = require(Shared:WaitForChild("CombatRemotes"))

local CONFIG = {
	ATTACK = {
		COOLDOWN = 0.4,
		RANGE = 16,
	},
	PARRY = {
		WINDOW = 0.5,
		COOLDOWN = 1.0,
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

local InputState = {
	IsAttacking = false,
	LastAttackTime = 0,
	IsParrying = false,
	LastParryTime = 0,
	IsDashing = false,
	LastDashTime = 0,
	IsSprinting = false,
	IsBlocking = false,
	ComboCount = 0,
	LastYPosition = 0,
	IsFalling = false,
}

local function handleAttack()
	if InputState.IsAttacking then
		return
	end
	
	if tick() - InputState.LastAttackTime < CONFIG.ATTACK.COOLDOWN then
		return
	end
	
	local nearestPlayer = nil
	local nearestDistance = CONFIG.ATTACK.RANGE
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer == player or not otherPlayer.Character then
			continue
		end
		
		local distance = (humanoidRootPart.Position - otherPlayer.Character.PrimaryPart.Position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestPlayer = otherPlayer
		end
	end
	
	if not nearestPlayer then
		print("❌ No target in range")
		return
	end
	
	InputState.IsAttacking = true
	InputState.LastAttackTime = tick()
	
	local result = CombatRemotes.Attack:InvokeServer(nearestPlayer, "MeleeAttack")
	
	if result.success then
		print("✅ Attack hit! Damage: " .. result.damage .. " - " .. result.message)
		InputState.ComboCount = InputState.ComboCount + 1
	else
		print("❌ Attack missed: " .. result.message)
	end
	
	InputState.IsAttacking = false
end

local function handleParry()
	if InputState.IsParrying then
		return
	end
	
	if tick() - InputState.LastParryTime < CONFIG.PARRY.COOLDOWN then
		return
	end
	
	local nearestAttacker = nil
	local nearestDistance = CONFIG.ATTACK.RANGE
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer == player or not otherPlayer.Character then
			continue
		end
		
		local distance = (humanoidRootPart.Position - otherPlayer.Character.PrimaryPart.Position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestAttacker = otherPlayer
		end
	end
	
	if not nearestAttacker then
		print("❌ No one to parry")
		return
	end
	
	InputState.IsParrying = true
	InputState.LastParryTime = tick()
	
	local result = CombatRemotes.Parry:InvokeServer(nearestAttacker, 20)
	
	if result.success then
		print("✅ Parry successful! Chip damage: " .. result.chipDamage)
	else
		print("❌ Parry failed! " .. result.message)
	end
	
	InputState.IsParrying = false
end

local function handleBlockStart()
	if InputState.IsBlocking then
		return
	end
	
	InputState.IsBlocking = true
	CombatRemotes.BlockStarted:FireServer()
	print("🛡️  Block started")
end

local function handleBlockEnd()
	if not InputState.IsBlocking then
		return
	end
	
	InputState.IsBlocking = false
	CombatRemotes.BlockEnded:FireServer()
	print("⏹️  Block ended")
end

local function handleDash()
	if InputState.IsDashing then
		return
	end
	
	if tick() - InputState.LastDashTime < CONFIG.DASH.COOLDOWN then
		print("⏳ Dash on cooldown")
		return
	end
	
	local camera = workspace.CurrentCamera
	local direction = camera.CFrame.LookVector
	local distance = 15
	
	InputState.IsDashing = true
	InputState.LastDashTime = tick()
	
	local result = CombatRemotes.Dash:InvokeServer(distance)
	
	if result.success then
		print("✅ Dashed! Cost: " .. result.staminaCost .. " stamina")
		humanoidRootPart.Velocity = direction * 100
	else
		print("❌ Dash failed: " .. result.message)
	end
	
	InputState.IsDashing = false
end

local function handleSprintStart()
	if InputState.IsSprinting then
		return
	end
	
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
	if not InputState.IsSprinting then
		return
	end
	
	InputState.IsSprinting = false
	
	local result = CombatRemotes.SprintEnd:InvokeServer()
	
	if result.success then
		print("⏹️  Sprint ended")
		CombatRemotes.SprintEnded:FireServer()
	end
end

local function trackFallHeight()
	InputState.LastYPosition = humanoidRootPart.Position.Y
end

local function checkFallDamage()
	local currentY = humanoidRootPart.Position.Y
	local fallDistance = InputState.LastYPosition - currentY
	
	if fallDistance > CONFIG.FALL.TRACK_THRESHOLD and humanoid.Health > 0 then
		InputState.IsFalling = true
		print("🪂 Falling... Distance: " .. math.floor(fallDistance) .. "m")
		
		task.wait(0.5)
		
		if humanoid.Health > 0 then
			local result = CombatRemotes.HandleLanding:InvokeServer(fallDistance)
			if result then
				print("✅ Landing handled")
			end
		end
		
		InputState.IsFalling = false
	end
	
	trackFallHeight()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	
	if input.KeyCode == Enum.KeyCode.MouseButton1 then
		handleAttack()
	elseif input.KeyCode == Enum.KeyCode.F then
		handleParry()
	elseif input.KeyCode == Enum.KeyCode.E then
		handleBlockStart()
	elseif input.KeyCode == Enum.KeyCode.Q then
		handleDash()
	elseif input.KeyCode == Enum.KeyCode.Lshift then
		handleSprintStart()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		handleBlockEnd()
	elseif input.KeyCode == Enum.KeyCode.Lshift then
		handleSprintEnd()
	end
end)

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

RunService.Heartbeat:Connect(function(deltaTime)
	trackFallHeight()
	
	if InputState.IsSprinting then
		humanoid.WalkSpeed = 16 * CONFIG.SPRINT.SPEED_MULTIPLIER
	else
		humanoid.WalkSpeed = 16
	end
	
	if InputState.IsBlocking and not UserInputService:IsKeyDown(Enum.KeyCode.E) then
		handleBlockEnd()
	end
end)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")
	
	InputState = {
		IsAttacking = false,
		LastAttackTime = 0,
		IsParrying = false,
		LastParryTime = 0,
		IsDashing = false,
		LastDashTime = 0,
		IsSprinting = false,
		IsBlocking = false,
		ComboCount = 0,
		LastYPosition = 0,
		IsFalling = false,
	}
	
	print("🔄 Character respawned, combat handler reset")
end)

print("✅ CombatHandler loaded - Controls: LMB=Attack, F=Parry, E=Block, Q=Dash, Shift=Sprint")
