--!strict
--[[
	CombatRemotes.luau - ENHANCED WITH MOBILITY
	Shared module for all combat + mobility network calls
	Place in: src/shared/CombatRemotes.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remoteFolder.Name = "Remotes"
remoteFolder.Parent = ReplicatedStorage

local function createOrGetRemoteFunction(name: string)
	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local function createOrGetRemoteEvent(name: string)
	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local CombatRemotes = {
	Attack = createOrGetRemoteFunction("Attack"),
	Parry = createOrGetRemoteFunction("Parry"),
	Block = createOrGetRemoteFunction("Block"),
	Dash = createOrGetRemoteFunction("Dash"),
	SprintStart = createOrGetRemoteFunction("SprintStart"),
	SprintEnd = createOrGetRemoteFunction("SprintEnd"),
	HandleLanding = createOrGetRemoteFunction("HandleLanding"),
	UpdateComboCounter = createOrGetRemoteEvent("UpdateComboCounter"),
	ApplyKnockback = createOrGetRemoteEvent("ApplyKnockback"),
	TriggerRagdoll = createOrGetRemoteEvent("TriggerRagdoll"),
	LandingRoll = createOrGetRemoteEvent("LandingRoll"),
	TakeFallDamage = createOrGetRemoteEvent("TakeFallDamage"),
	StaminaLow = createOrGetRemoteEvent("StaminaLow"),
	StaminaCritical = createOrGetRemoteEvent("StaminaCritical"),
	SprintStarted = createOrGetRemoteEvent("SprintStarted"),
	SprintEnded = createOrGetRemoteEvent("SprintEnded"),
	BlockStarted = createOrGetRemoteEvent("BlockStarted"),
	BlockEnded = createOrGetRemoteEvent("BlockEnded"),
}

return CombatRemotes
