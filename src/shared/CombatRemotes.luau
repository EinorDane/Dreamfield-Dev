--!strict
--[[
	CombatRemotes.luau
	Network event definitions for combat system
	Handles: Attack, Parry, Block, Dash
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--! Create remotes dynamically if they don't exist
local function getOrCreateRemote(name: string)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing
	end
	
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local function getOrCreateEvent(name: string)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing
	end
	
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

export type CombatRemote = {
	Attack: RemoteFunction,
	Parry: RemoteFunction,
	Block: RemoteFunction,
	Dash: RemoteFunction,
	UpdateComboCounter: RemoteEvent,
	UpdateCombatUI: RemoteEvent,
}

local CombatRemotes: CombatRemote = {
	Attack = getOrCreateRemote("CombatAttack"),
	Parry = getOrCreateRemote("CombatParry"),
	Block = getOrCreateRemote("CombatBlock"),
	Dash = getOrCreateRemote("CombatDash"),
	UpdateComboCounter = getOrCreateEvent("UpdateComboCounter"),
	UpdateCombatUI = getOrCreateEvent("UpdateCombatUI"),
}

return CombatRemotes
