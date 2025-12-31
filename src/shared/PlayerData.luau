--!strict
--[[
	THREAD-002: PlayerData Module (Core Storage)
	
	Central data storage system for all player progression, inventory,
	and game state. Uses strict type checking for data safety.
	
	File: src/shared/PlayerData.luau
	Priority: CRITICAL (all systems depend on this)
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
-- PRIVATE: Global Player Profiles Cache
-- ============================================================

local PlayerProfiles: { [number]: PlayerProfile } = {}

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

function PlayerData.getPlayerData(userId: number): PlayerProfile
	--!strict
	if not PlayerProfiles[userId] then
		PlayerProfiles[userId] = createDefaultProfile()
	end
	return PlayerProfiles[userId]
end

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
	
	-- Calculate levels gained and reset experience counter
	while profile.experience >= 100 do
		profile.level += 1
		profile.experience -= 100
	end
	
	profile.tolerance = profile.level * 5
end

function PlayerData.removeExperience(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 then
		error("Experience amount must be positive", 2)
	end
	
	profile.experience -= amount
	
	-- Handle level downs if experience goes negative
	while profile.experience < 0 and profile.level > 1 do
		profile.level -= 1
		profile.experience += 100
	end
	
	profile.experience = math.max(0, profile.experience)
	profile.tolerance = profile.level * 5
end

-- ============================================================
-- PUBLIC: Stamina Management (CRITICAL FOR COMBAT)
-- ============================================================

function PlayerData.addStamina(profile: PlayerProfile, amount: number): number
	--!strict
	if amount < 0 then
		error("Stamina amount must be positive", 2)
	end
	
	profile.stamina = math.min(profile.stamina + amount, profile.maxStamina)
	return profile.stamina
end

function PlayerData.removeStamina(profile: PlayerProfile, amount: number): number
	--!strict
	if amount < 0 then
		error("Stamina amount must be positive", 2)
	end
	
	profile.stamina = math.max(profile.stamina - amount, 0)
	return profile.stamina
end

function PlayerData.setStamina(profile: PlayerProfile, amount: number): number
	--!strict
	if amount < 0 or amount > profile.maxStamina then
		error("Stamina must be between 0 and " .. profile.maxStamina, 2)
	end
	
	profile.stamina = amount
	return profile.stamina
end

function PlayerData.restoreStamina(profile: PlayerProfile): number
	--!strict
	profile.stamina = profile.maxStamina
	return profile.stamina
end

-- ============================================================
-- PUBLIC: Corruption Management
-- ============================================================

function PlayerData.addCorruption(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 then
		error("Corruption amount must be positive", 2)
	end
	
	profile.corruptionPool = math.min(profile.corruptionPool + amount, profile.maxCorruption * 1.5)
	profile.overloaded = profile.corruptionPool >= profile.maxCorruption
end

function PlayerData.removeCorruption(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 then
		error("Corruption amount must be positive", 2)
	end
	
	profile.corruptionPool = math.max(profile.corruptionPool - amount, 0)
	profile.overloaded = profile.corruptionPool >= profile.maxCorruption
end

function PlayerData.setCorruption(profile: PlayerProfile, amount: number): ()
	--!strict
	if amount < 0 then
		error("Corruption cannot be negative", 2)
	end
	
	profile.corruptionPool = math.min(amount, profile.maxCorruption * 1.5)
	profile.overloaded = profile.corruptionPool >= profile.maxCorruption
end

function PlayerData.getCorruption(profile: PlayerProfile): number
	--!strict
	return profile.corruptionPool
end

function PlayerData.updateCorruptionPool(profile: PlayerProfile): ()
	--!strict
	-- Recalculate corruption from equipped shards
	local totalCorruption = 0
	
	for i = 1, 5 do
		if profile.equippedShards[i] then
			totalCorruption += profile.equippedShards[i].corruption or 0
		end
	end
	
	profile.corruptionPool = totalCorruption
	profile.overloaded = profile.corruptionPool >= profile.maxCorruption
	profile.tolerance = profile.level * 5
end

-- ============================================================
-- PUBLIC: Inventory Management
-- ============================================================

function PlayerData.addInventoryItem(profile: PlayerProfile, item: InventoryItem): boolean
	--!strict
	if #profile.inventory >= profile.inventorySlots then
		return false
	end
	
	profile.inventory[#profile.inventory + 1] = item
	profile.inventoryWeight += item.weight
	
	return true
end

function PlayerData.removeInventoryItem(profile: PlayerProfile, itemId: string): boolean
	--!strict
	for i, item in ipairs(profile.inventory) do
		if item.id == itemId then
			profile.inventoryWeight -= item.weight
			table.remove(profile.inventory, i)
			return true
		end
	end
	
	return false
end

function PlayerData.getInventoryItem(profile: PlayerProfile, itemId: string): InventoryItem?
	--!strict
	for _, item in ipairs(profile.inventory) do
		if item.id == itemId then
			return item
		end
	end
	
	return nil
end

-- ============================================================
-- PUBLIC: Equipment Management
-- ============================================================

function PlayerData.equipShard(profile: PlayerProfile, shard: Shard, slot: number): boolean
	--!strict
	if slot < 1 or slot > #profile.equippedShards then
		return false
	end
	
	profile.equippedShards[slot] = shard
	PlayerData.updateCorruptionPool(profile)
	return true
end

function PlayerData.unequipShard(profile: PlayerProfile, slot: number): Shard?
	--!strict
	if slot < 1 or slot > #profile.equippedShards then
		return nil
	end
	
	local shard = profile.equippedShards[slot]
	profile.equippedShards[slot] = nil
	PlayerData.updateCorruptionPool(profile)
	return shard
end

function PlayerData.getEquippedShards(profile: PlayerProfile): { Shard? }
	--!strict
	return profile.equippedShards
end

-- ============================================================
-- PUBLIC: Faction Reputation
-- ============================================================

function PlayerData.addReputation(profile: PlayerProfile, faction: string, amount: number): ()
	--!strict
	if not profile.factionsReputation[faction] then
		profile.factionsReputation[faction] = 0
	end
	
	profile.factionsReputation[faction] += amount
end

function PlayerData.getReputation(profile: PlayerProfile, faction: string): number
	--!strict
	return profile.factionsReputation[faction] or 0
end

-- ============================================================
-- PUBLIC: World State
-- ============================================================

function PlayerData.setWorldPosition(profile: PlayerProfile, world: string, position: { number }): ()
	--!strict
	profile.currentWorld = world
	profile.position = position
end

function PlayerData.getWorldPosition(profile: PlayerProfile): (string, { number })
	--!strict
	return profile.currentWorld, profile.position
end

-- ============================================================
-- PUBLIC: Tasks & Progression
-- ============================================================

function PlayerData.completeTask(profile: PlayerProfile, taskId: string): boolean
	--!strict
	if table.find(profile.tasksCompleted, taskId) then
		return false
	end
	
	table.insert(profile.tasksCompleted, taskId)
	return true
end

function PlayerData.isTaskCompleted(profile: PlayerProfile, taskId: string): boolean
	--!strict
	return table.find(profile.tasksCompleted, taskId) ~= nil
end

-- ============================================================
-- PUBLIC: Cleanup & Persistence
-- ============================================================

function PlayerData.clearPlayerData(userId: number): ()
	--!strict
	PlayerProfiles[userId] = nil
end

function PlayerData.getAllProfiles(): { [number]: PlayerProfile }
	--!strict
	return PlayerProfiles
end

return PlayerData
