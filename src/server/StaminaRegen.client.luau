--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerData = require(Shared:WaitForChild("PlayerData"))

local RATE = 15 -- Regenerate 15 stamina per second

RunService.Heartbeat:Connect(function(dt)
	for _, player in pairs(Players:GetPlayers()) do
		local data = PlayerData.getPlayerData(player.UserId)
		
		if data and data.stamina < data.maxStamina then
			data.stamina = math.min(data.maxStamina, data.stamina + (RATE * dt))
		end
	end
end)
