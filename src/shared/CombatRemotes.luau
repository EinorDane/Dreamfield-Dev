--!strict
--[[
	CombatRemotes.luau
	Network event definitions for combat system
	Handles: Attack, Parry, Block, Dash
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteManager = require(ReplicatedStorage.Shared.RemoteManager)

export type CombatRemote = {
	Attack: RemoteFunction,
	Parry: RemoteFunction,
	Block: RemoteFunction,
	Dash: RemoteFunction,
	UpdateComboCounter: RemoteEvent,
	UpdateCombatUI: RemoteEvent,
}

local CombatRemotes: CombatRemote = {
	Attack = RemoteManager:GetRemote("CombatAttack"),
	Parry = RemoteManager:GetRemote("CombatParry"),
	Block = RemoteManager:GetRemote("CombatBlock"),
	Dash = RemoteManager:GetRemote("CombatDash"),
	UpdateComboCounter = RemoteManager:GetRemote("UpdateComboCounter"),
	UpdateCombatUI = RemoteManager:GetRemote("UpdateCombatUI"),
}

return CombatRemotes
