--!strict
--[[
	CombatHandler.client.luau
	Client-side input handling for combat
	Handles: LMB (attack), F (parry/block), Q (dash), 1-5 (arsenal select)
]]

--! Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--! Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRemotes = require(Shared:WaitForChild("CombatRemotes"))

--! LOCAL PLAYER
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

--! CONFIG
local CONFIG = {
	ATTACK_COOLDOWN = 0.5,
	DASH_DISTANCE = 15,
	PARRY_TIMEOUT = 0.5,
}

--! STATE
local CombatState = {
	IsAttacking = false,
	LastAttackTime = 0,
	IsBlocking = false,
	SelectedArsenal = 1,
	ParryActive = false,
	ParryStartTime = 0,
}

--! FUNCTIONS
local function attack()
	if tick() - CombatState.LastAttackTime < CONFIG.ATTACK_COOLDOWN then
		return
	end
	
	CombatState.IsAttacking = true
	CombatState.LastAttackTime = tick()
	
	--! Find nearby target (for now, just attack closest player)
	local targetPlayer = nil
	local closestDistance = 16
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			local distance = (humanoidRootPart.Position - player.Character.PrimaryPart.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				targetPlayer = player
			end
		end
	end
	
	if targetPlayer then
		local result = CombatRemotes.Attack:InvokeServer(targetPlayer, "LMB")
		if result.success then
			print("✅ Attack hit! Damage: " .. result.damage)
		else
			print("❌ Attack missed: " .. result.message)
		end
	else
		print("⚠️  No target in range")
	end
	
	CombatState.IsAttacking = false
end

local function startDash()
	local direction = humanoidRootPart.CFrame.LookVector
	local result = CombatRemotes.Dash:InvokeServer(CONFIG.DASH_DISTANCE)
	
	if result.success then
		print("✅ Dashed! Stamina cost: " .. result.staminaCost)
		
		--! Move player
		humanoidRootPart.CFrame = humanoidRootPart.CFrame + direction * CONFIG.DASH_DISTANCE
	else
		print("❌ Dash failed: " .. result.message)
	end
end

local function startParry()
	CombatState.ParryActive = true
	CombatState.ParryStartTime = tick()
	print("🛡️  Parry window active (0.5s)")
	
	--! Find attacking player and simulate parry
	local attackingPlayer = nil
	local closestDistance = 20
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			local distance = (humanoidRootPart.Position - player.Character.PrimaryPart.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				attackingPlayer = player
			end
		end
	end
	
	if attackingPlayer then
		local result = CombatRemotes.Parry:InvokeServer(attackingPlayer, 20)
		if result.success then
			print("✅ Parry successful! Chip damage: " .. result.chipDamage)
		else
			print("❌ Parry failed: " .. result.message)
		end
	end
end

local function startBlock()
	CombatState.IsBlocking = true
	print("🛡️  Blocking (hold F)...")
end

local function stopBlock()
	CombatState.IsBlocking = false
	print("❌ Block released")
end

local function selectArsenal(slot: number)
	CombatState.SelectedArsenal = slot
	print("⚔️  Selected arsenal slot: " .. slot)
end

--! INPUT EVENTS
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	--! LMB - Attack
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	end
	
	--! Q - Dash
	if input.KeyCode == Enum.KeyCode.Q then
		startDash()
	end
	
	--! F - Parry (tap) or Block (hold)
	if input.KeyCode == Enum.KeyCode.F then
		startParry()
	end
	
	--! 1-5 - Arsenal select
	if input.KeyCode == Enum.KeyCode.One then selectArsenal(1) end
	if input.KeyCode == Enum.KeyCode.Two then selectArsenal(2) end
	if input.KeyCode == Enum.KeyCode.Three then selectArsenal(3) end
	if input.KeyCode == Enum.KeyCode.Four then selectArsenal(4) end
	if input.KeyCode == Enum.KeyCode.Five then selectArsenal(5) end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	--! F released - Stop block/parry
	if input.KeyCode == Enum.KeyCode.F then
		stopBlock()
	end
end)

--! RENDER HEARTBEAT FOR CONTINUOUS BLOCK
RunService.Heartbeat:Connect(function(deltaTime)
	if CombatState.IsBlocking then
		local closestTarget = nil
		local closestDistance = 20
		
		for _, player in pairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Character then
				local distance = (humanoidRootPart.Position - player.Character.PrimaryPart.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestTarget = player
				end
			end
		end
		
		if closestTarget then
			local result = CombatRemotes.Block:InvokeServer(20, deltaTime)
			--! Block damage applied
		end
	end
end)

--! LISTEN FOR COMBO UPDATES
CombatRemotes.UpdateComboCounter.OnClientEvent:Connect(function(comboCount: number)
	if comboCount > 0 then
		print("🔥 COMBO x" .. comboCount .. "!")
	else
		print("💫 Combo reset")
	end
end)

print("✅ CombatHandler loaded")
