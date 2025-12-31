--!strict
--[[
	StaminaRegen.server.lua - ACTIVE STAMINA REGENERATION
	Runs on SERVER to regenerate player stamina over time
	
	Path: src/server/StaminaRegen.server.lua
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerData = require(Shared:WaitForChild("PlayerData"))

--! CONFIG
local STAMINA_REGEN_RATE = 15 -- stamina per second
local MIN_REGEN_DELAY = 2 -- 2 seconds after using stamina before regen starts

--! PLAYER STATE TRACKING
local playerStaminaStates = {}

local function getPlayerState(userId: number)
	if not playerStaminaStates[userId] then
		playerStaminaStates[userId] = {
			lastStaminaUseTime = 0,
			isRegenerating = false,
		}
	end
	return playerStaminaStates[userId]
end

--! MAIN REGEN LOOP
RunService.Heartbeat:Connect(function(deltaTime)
	for _, player in pairs(Players:GetPlayers()) do
		if not player.Character then continue end
		
		local data = PlayerData.getPlayerData(player.UserId)
		if not data then continue end
		
		local state = getPlayerState(player.UserId)
		local timeSinceLastUse = tick() - state.lastStaminaUseTime
		
		-- START REGENERATING after MIN_REGEN_DELAY
		if timeSinceLastUse >= MIN_REGEN_DELAY and data.stamina < data.maxStamina then
			data.stamina = math.min(data.maxStamina, data.stamina + (STAMINA_REGEN_RATE * deltaTime))
			state.isRegenerating = true
		elseif data.stamina >= data.maxStamina then
			state.isRegenerating = false
		end
	end
end)

--! TRACK STAMINA USAGE
local function onStaminaUsed(userId: number, amount: number)
	local state = getPlayerState(userId)
	state.lastStaminaUseTime = tick()
	state.isRegenerating = false
	
	print("⚡ Stamina used: " .. amount .. " (Regen paused for " .. MIN_REGEN_DELAY .. "s)")
end

--! PLAYER JOIN/LEAVE
Players.PlayerAdded:Connect(function(player)
	task.wait(0.5) -- Wait for character
	local data = PlayerData.getPlayerData(player.UserId)
	data.stamina = data.maxStamina -- Full stamina on spawn
	print("✅ Player " .. player.Name .. " spawned with " .. data.stamina .. " stamina")
end)

Players.PlayerRemoving:Connect(function(player)
	playerStaminaStates[player.UserId] = nil
end)

print("✅ StaminaRegen loaded - Stamina regenerates at " .. STAMINA_REGEN_RATE .. "/sec")
