--!strict
--[[
	THREAD-002: PlayerData Module (Core Storage)
	
	Central data storage system for all player progression, inventory,
	and game state. Uses ProfileService for persistence.
	Uses strict type checking for data safety.
	
	File: src/shared/PlayerData.luau
	Priority: CRITICAL (all systems depend on this)
	Complexity: Medium
	Time Estimate: 3-4 hours
]]

local PlayerData = {}

-- CONFIG
local DEFAULT_LEVEL = 1
local DEFAULT_CORRUPTION = 0
local DEFAULT_MAX_CORRUPTION = 100
local DEFAULT_STAMINA = 100
local DEFAULT_MAX_STAMINA = 100
local DEFAULT_INVENTORY_SLOTS = 25
local DEFAULT_EQUIPPED_SHARDS_SLOTS = 5

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- TYPES
-- ============================================================

export type Shard = {
	id: string,
	name: string,
	rarity: string,
	corruption: number,
	durability: number,
	maxDurability: number,
	level: number,
}

export type InventoryItem = {
	id: string,
	shardId: string?,
	quantity: number,
	weight: number,
	rarity: string,
	equipped: boolean,
	slotIndex: number,
}

export type PlayerProfile = {
	-- Character Stats
	level: number,
	experience: number,
	
	-- Corruption System
	corruption: number,
	maxCorruption: number,
	corruptionPool: number,
	tolerance: number,
	overloaded: boolean,
	
	-- Stamina System
	stamina: number,
	maxStamina: number,
	
	-- Inventory
	inventory: { InventoryItem },
	inventorySlots: number,
	inventoryWeight: number,
	maxInventoryWeight: number,
	
	-- Equipment
	equippedShards: { Shard? },
	
	-- Progression
	tasksCompleted: { string },
	factionsReputation: { [string]: number },
	
	-- World State
	currentWorld: string,
	position: { number },
	
	-- Timestamps
	lastLogin: number,
	createdAt: number,
}

-- ============================================================
-- PRIVATE: Default Profile Factory
-- ============================================================

local function createDefaultProfile(): PlayerProfile
	--!strict
	return {
		-- Character Stats
		level = DEFAULT_LEVEL,
		experience = 0,
		
		-- Corruption System
		corruption = DEFAULT_CORRUPTION,
		maxCorruption = DEFAULT_MAX_CORRUPTION,
		corruptionPool = 0,
		tolerance = DEFAULT_LEVEL * 5,
		overloaded = false,
		
		-- Stamina System
		stamina = DEFAULT_MAX_STAMINA,
		maxStamina = DEFAULT_MAX_STAMINA,
		
		-- Inventory
		inventory = {},
		inventorySlots = DEFAULT_INVENTORY_SLOTS,
		inventoryWeight = 0,
		maxInventoryWeight = 50,
		
		-- Equipment
		equippedShards = { nil, nil, nil, nil, nil },
		
		-- Progression
		tasksCompleted = {},
		factionsReputation = {
			Authority = 0,
			Untethered = 0,
			FirstCrown = 0,
			Hollow = 0,
		},
		
		-- World State
		currentWorld = "RuinedEarth",
		position = { 0, 5, 0 },
		
		-- Timestamps
		lastLogin = os.time(),
		createdAt = os.time(),
	}
end

-- ============================================================
-- PRIVATE: Data Validation
-- ============================================================

local function validateProfile(profile: any): boolean
	--!strict
	if typeof(profile) ~= "table" then
		return false
	end
	
	if not profile.level or not profile.corruption or not profile.inventory then
		return false
	end
	
	if typeof(profile.inventory) ~= "table" then
		return false
	end
	
	return true
end

-- ============================================================
-- PUBLIC: Profile Management
-- ============================================================

function PlayerData.createProfile(): PlayerProfile
	--!strict
	return createDefaultProfile()
end

function PlayerData.addExperience(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 then
		error("Experience amount must be positive", 2)
	end
	
	profile.experience += amount
	
	local levelsGained = math.floor(profile.experience / 100)
	if levelsGained > 0 then
		profile.level += levelsGained
		profile.tolerance = profile.level * 5
	end
end

function PlayerData.setCorruption(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 or amount > profile.maxCorruption then
		error(
			string.format(
				"Corruption must be between 0 and %d",
				profile.maxCorruption
			),
			2
		)
	end
	
	profile.corruption = amount
	profile.overloaded = amount >= profile.maxCorruption
end

function PlayerData.updateCorruptionPool(profile: PlayerProfile): ()
	--!strict
	local totalCorruption = 0
	
	for _, shard in ipairs(profile.equippedShards) do
		if shard then
			totalCorruption += shard.corruption
		end
	end
	
	profile.corruptionPool = totalCorruption
end

function PlayerData.addStamina(profile: PlayerProfile, amount: number): ()
	--!strict
	profile.stamina = math.min(profile.stamina + amount, profile.maxStamina)
end

function PlayerData.removeStamina(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 then
		error("Stamina amount must be positive", 2)
	end
	
	profile.stamina = math.max(profile.stamina - amount, 0)
end

function PlayerData.canAddInventoryItem(profile: PlayerProfile, item: InventoryItem): boolean
	--!strict
	if #profile.inventory >= profile.inventorySlots then
		return false
	end
	
	if profile.inventoryWeight + item.weight > profile.maxInventoryWeight then
		return false
	end
	
	return true
end

function PlayerData.addInventoryItem(profile: PlayerProfile, item: InventoryItem): boolean
	--!strict
	if not PlayerData.canAddInventoryItem(profile, item) then
		return false
	end
	
	item.slotIndex = #profile.inventory + 1
	table.insert(profile.inventory, item)
	profile.inventoryWeight += item.weight
	
	return true
end

function PlayerData.removeInventoryItem(profile: PlayerProfile, slotIndex: number): InventoryItem?
	--!strict
	if slotIndex < 1 or slotIndex > #profile.inventory then
		return nil
	end
	
	local item = profile.inventory[slotIndex]
	if item then
		profile.inventoryWeight -= item.weight
		table.remove(profile.inventory, slotIndex)
		
		for i = slotIndex, #profile.inventory do
			profile.inventory[i].slotIndex = i
		end
	end
	
	return item
end

function PlayerData.getInventoryItem(profile: PlayerProfile, slotIndex: number): InventoryItem?
	--!strict
	if slotIndex < 1 or slotIndex > #profile.inventory then
		return nil
	end
	
	return profile.inventory[slotIndex]
end

function PlayerData.equipShard(profile: PlayerProfile, shardSlot: number, shard: Shard): boolean
	--!strict
	if shardSlot < 1 or shardSlot > #profile.equippedShards then
		error("Shard slot out of range", 2)
	end
	
	profile.equippedShards[shardSlot] = shard
	PlayerData.updateCorruptionPool(profile)
	
	return true
end

function PlayerData.unequipShard(profile: PlayerProfile, shardSlot: number): Shard?
	--!strict
	if shardSlot < 1 or shardSlot > #profile.equippedShards then
		error("Shard slot out of range", 2)
	end
	
	local shard = profile.equippedShards[shardSlot]
	profile.equippedShards[shardSlot] = nil
	PlayerData.updateCorruptionPool(profile)
	
	return shard
end

function PlayerData.changeWorld(profile: PlayerProfile, world: string): ()
	--!strict
	if world ~= "RuinedEarth" and world ~= "Dreamfield" then
		error("Invalid world: " .. world, 2)
	end
	
	profile.currentWorld = world
	profile.lastLogin = os.time()
end

function PlayerData.addTaskCompletion(profile: PlayerProfile, taskId: string): ()
	--!strict
	for _, completedTaskId in ipairs(profile.tasksCompleted) do
		if completedTaskId == taskId then
			return
		end
	end
	
	table.insert(profile.tasksCompleted, taskId)
end

function PlayerData.hasCompletedTask(profile: PlayerProfile, taskId: string): boolean
	--!strict
	for _, completedTaskId in ipairs(profile.tasksCompleted) do
		if completedTaskId == taskId then
			return true
		end
	end
	
	return false
end

function PlayerData.updateFactionReputation(
	profile: PlayerProfile,
	faction: string,
	amount: number
): ()
	--!strict
	if not profile.factionsReputation[faction] then
		error("Unknown faction: " .. faction, 2)
	end
	
	profile.factionsReputation[faction] += amount
end

-- ============================================================
-- PUBLIC: Validation & Save
-- ============================================================

function PlayerData.validate(profile: any): boolean
	--!strict
	return validateProfile(profile)
end

function PlayerData.sanitize(profile: PlayerProfile): PlayerProfile
	--!strict
	profile.level = math.max(profile.level, 1)
	profile.corruption = math.clamp(profile.corruption, 0, profile.maxCorruption)
	profile.stamina = math.clamp(profile.stamina, 0, profile.maxStamina)
	profile.tolerance = profile.level * 5
	
	return profile
end

-- ============================================================
-- PUBLIC: Debug Helpers
-- ============================================================

function PlayerData.printProfile(profile: PlayerProfile): ()
	--!strict
	print("\n=== PLAYER PROFILE ===")
	print(string.format("Level: %d (XP: %d)", profile.level, profile.experience))
	print(string.format("Corruption: %d/%d (Pool: %d)", profile.corruption, profile.maxCorruption, profile.corruptionPool))
	print(string.format("Stamina: %d/%d", profile.stamina, profile.maxStamina))
	print(string.format("Inventory: %d/%d slots, Weight: %.1f/%.1f", 
		#profile.inventory, 
		profile.inventorySlots,
		profile.inventoryWeight,
		profile.maxInventoryWeight
	))
	print(string.format("World: %s", profile.currentWorld))
	print("=====================\n")
end

return PlayerData
