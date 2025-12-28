--!strict
--[[
	Stamina.luau
	Stamina management system
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

local Stamina = {}

--! CONFIG
Stamina.CONFIG = {
	MAX_STAMINA = 100,
	REGEN_RATE = 10, --! per second
	REGEN_DELAY = 2, --! seconds before regen starts
}

--! Deduct stamina from player
function Stamina:DeductStamina(userId: number, amount: number)
	local playerData = PlayerData:GetPlayerData(userId)
	playerData.stamina = math.max(0, playerData.stamina - amount)
end

--! Add stamina to player
function Stamina:AddStamina(userId: number, amount: number)
	local playerData = PlayerData:GetPlayerData(userId)
	playerData.stamina = math.min(Stamina.CONFIG.MAX_STAMINA, playerData.stamina + amount)
end

--! Check if player has enough stamina
function Stamina:HasStamina(userId: number, amount: number): boolean
	local playerData = PlayerData:GetPlayerData(userId)
	return playerData.stamina >= amount
end

--! Get current stamina
function Stamina:GetStamina(userId: number): number
	local playerData = PlayerData:GetPlayerData(userId)
	return playerData.stamina
end

--! Refill stamina completely
function Stamina:RefillStamina(userId: number)
	local playerData = PlayerData:GetPlayerData(userId)
	playerData.stamina = Stamina.CONFIG.MAX_STAMINA
end

return Stamina
