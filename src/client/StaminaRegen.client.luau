local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerData = require(Shared:WaitForChild("PlayerData"))

local RATE = 15 -- Regenerate 15 stamina per second

RunService.Heartbeat:Connect(function(dt)
	local data = PlayerData:GetPlayerData(Players.LocalPlayer.UserId)
	if data and data.stamina < data.maxStamina then
		data.stamina = math.min(data.maxStamina, data.stamina + (RATE * dt))
	end
end)
