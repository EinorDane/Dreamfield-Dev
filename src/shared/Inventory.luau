--!strict

local PlayerData = require(script.Parent.PlayerData)

local Inventory = {}

-- CONFIG
local RARITY_WEIGHTS = {
	Common = 1.0,
	Uncommon = 1.5,
	Rare = 2.0,
	Epic = 3.0,
	Legendary = 5.0,
}

-- ============================================================
-- TYPES
-- ============================================================

export type Item = {
	id: string,
	name: string,
	rarity: string,
	weight: number,
	type: string,
	quantity: number,
	properties: { [string]: any },
	slotIndex: number,
}

export type InventoryState = {
	items: { Item },
	maxSlots: number,
	maxWeight: number,
	currentWeight: number,
}

-- ============================================================
-- PRIVATE: Item ID Generator
-- ============================================================

local function generateItemId(): string
	--!strict
	return "item_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- ============================================================
-- PUBLIC: Inventory Creation
-- ============================================================

function Inventory.createState(maxSlots: number, maxWeight: number): InventoryState
	--!strict
	if maxSlots < 1 or maxSlots > 100 then
		error("Max slots must be between 1 and 100", 2)
	end
	
	if maxWeight < 1 or maxWeight > 1000 then
		error("Max weight must be between 1 and 1000", 2)
	end
	
	return {
		items = {},
		maxSlots = maxSlots,
		maxWeight = maxWeight,
		currentWeight = 0,
	}
end

-- ============================================================
-- PUBLIC: Item Creation
-- ============================================================

function Inventory.createShard(
	shardId: string,
	name: string,
	rarity: string,
	corruption: number,
	level: number
): Item
	--!strict
	if not RARITY_WEIGHTS[rarity] then
		error("Invalid rarity: " .. rarity, 2)
	end
	
	if corruption < 0 or corruption > 100 then
		error("Corruption must be between 0 and 100", 2)
	end
	
	local rarityMultiplier = RARITY_WEIGHTS[rarity]
	
	return {
		id = generateItemId(),
		name = name,
		rarity = rarity,
		weight = 0.5 * rarityMultiplier,
		type = "shard",
		quantity = 1,
		properties = {
			shardId = shardId,
			corruption = corruption,
			level = level,
			durability = 100,
			maxDurability = 100,
		},
		slotIndex = 0,
	}
end

-- NEW: Create actual Shard object for equipping
function Inventory.createShardObject(
	shardId: string,
	name: string,
	rarity: string,
	corruption: number,
	level: number
): PlayerData.Shard
	--!strict
	if not RARITY_WEIGHTS[rarity] then
		error("Invalid rarity: " .. rarity, 2)
	end
	
	if corruption < 0 or corruption > 100 then
		error("Corruption must be between 0 and 100", 2)
	end
	
	return {
		id = shardId,
		name = name .. " Shard",
		rarity = rarity,
		corruption = corruption,
		durability = 100,
		maxDurability = 100,
		level = level,
	}
end

function Inventory.createWeapon(
	weaponId: string,
	name: string,
	rarity: string,
	attackType: string
): Item
	--!strict
	if not RARITY_WEIGHTS[rarity] then
		error("Invalid rarity: " .. rarity, 2)
	end
	
	local rarityMultiplier = RARITY_WEIGHTS[rarity]
	
	return {
		id = generateItemId(),
		name = name,
		rarity = rarity,
		weight = 3.0 * rarityMultiplier,
		type = "weapon",
		quantity = 1,
		properties = {
			weaponId = weaponId,
			attackType = attackType,
			damage = 10 * rarityMultiplier,
			crit = 5 + (10 * rarityMultiplier),
			durability = 100,
			maxDurability = 100,
		},
		slotIndex = 0,
	}
end

function Inventory.createConsumable(
	consumableId: string,
	name: string,
	rarity: string,
	effectType: string,
	quantity: number
): Item
	--!strict
	if not RARITY_WEIGHTS[rarity] then
		error("Invalid rarity: " .. rarity, 2)
	end
	
	if quantity < 1 or quantity > 999 then
		error("Quantity must be between 1 and 999", 2)
	end
	
	return {
		id = generateItemId(),
		name = name,
		rarity = rarity,
		weight = 0.1 * quantity,
		type = "consumable",
		quantity = quantity,
		properties = {
			consumableId = consumableId,
			effectType = effectType,
			potency = 10,
		},
		slotIndex = 0,
	}
end

-- ============================================================
-- PUBLIC: Inventory Operations
-- ============================================================

function Inventory.getItemCount(state: InventoryState): number
	--!strict
	return #state.items
end

function Inventory.getAvailableSlots(state: InventoryState): number
	--!strict
	return state.maxSlots - #state.items
end

function Inventory.canAddItem(state: InventoryState, item: Item): (boolean, string)
	--!strict
	if #state.items >= state.maxSlots then
		return false, "Inventory full"
	end
	
	if state.currentWeight + item.weight > state.maxWeight then
		return false, "Too heavy"
	end
	
	return true, "OK"
end

function Inventory.addItem(state: InventoryState, item: Item): (boolean, string)
	--!strict
	local canAdd, reason = Inventory.canAddItem(state, item)
	if not canAdd then
		return false, reason
	end
	
	item.slotIndex = #state.items + 1
	table.insert(state.items, item)
	state.currentWeight += item.weight
	
	return true, "Item added"
end

function Inventory.removeItem(state: InventoryState, slotIndex: number): (Item?, string)
	--!strict
	if slotIndex < 1 or slotIndex > #state.items then
		return nil, "Invalid slot"
	end
	
	local item = state.items[slotIndex]
	if item then
		state.currentWeight -= item.weight
		table.remove(state.items, slotIndex)
		
		for i = slotIndex, #state.items do
			state.items[i].slotIndex = i
		end
	end
	
	return item, "Item removed"
end

function Inventory.getItem(state: InventoryState, slotIndex: number): Item?
	--!strict
	if slotIndex < 1 or slotIndex > #state.items then
		return nil
	end
	
	return state.items[slotIndex]
end

function Inventory.findItemById(state: InventoryState, itemId: string): Item?
	--!strict
	for _, item in ipairs(state.items) do
		if item.id == itemId then
			return item
		end
	end
	
	return nil
end

function Inventory.findItemsByType(state: InventoryState, itemType: string): { Item }
	--!strict
	local items = {}
	
	for _, item in ipairs(state.items) do
		if item.type == itemType then
			table.insert(items, item)
		end
	end
	
	return items
end

function Inventory.findItemsByRarity(state: InventoryState, rarity: string): { Item }
	--!strict
	local items = {}
	
	for _, item in ipairs(state.items) do
		if item.rarity == rarity then
			table.insert(items, item)
		end
	end
	
	return items
end

function Inventory.sortByRarity(state: InventoryState): ()
	--!strict
	local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	
	table.sort(state.items, function(a, b)
		return (rarityOrder[a.rarity] or 0) > (rarityOrder[b.rarity] or 0)
	end)
	
	for i, item in ipairs(state.items) do
		item.slotIndex = i
	end
end

function Inventory.sortByWeight(state: InventoryState): ()
	--!strict
	table.sort(state.items, function(a, b)
		return a.weight > b.weight
	end)
	
	for i, item in ipairs(state.items) do
		item.slotIndex = i
	end
end

-- ============================================================
-- PUBLIC: Weight & Slot Management
-- ============================================================

function Inventory.getWeightPercentage(state: InventoryState): number
	--!strict
	return (state.currentWeight / state.maxWeight) * 100
end

function Inventory.getSlotPercentage(state: InventoryState): number
	--!strict
	return (#state.items / state.maxSlots) * 100
end

function Inventory.isFull(state: InventoryState): boolean
	--!strict
	return #state.items >= state.maxSlots
end

function Inventory.isOverweight(state: InventoryState): boolean
	--!strict
	return state.currentWeight > state.maxWeight
end

function Inventory.upgradeMaxSlots(state: InventoryState, newMaxSlots: number): ()
	--!strict
	if newMaxSlots <= state.maxSlots then
		error("New max slots must be greater than current", 2)
	end
	
	state.maxSlots = newMaxSlots
end

function Inventory.upgradeMaxWeight(state: InventoryState, newMaxWeight: number): ()
	--!strict
	if newMaxWeight <= state.maxWeight then
		error("New max weight must be greater than current", 2)
	end
	
	state.maxWeight = newMaxWeight
end

-- ============================================================
-- PUBLIC: Inventory Utility
-- ============================================================

function Inventory.clear(state: InventoryState): ()
	--!strict
	state.items = {}
	state.currentWeight = 0
end

function Inventory.getStats(state: InventoryState): { [string]: any }
	--!strict
	return {
		itemCount = #state.items,
		totalWeight = state.currentWeight,
		maxWeight = state.maxWeight,
		maxSlots = state.maxSlots,
		usedSlots = #state.items,
		availableSlots = state.maxSlots - #state.items,
		weightPercentage = Inventory.getWeightPercentage(state),
		slotPercentage = Inventory.getSlotPercentage(state),
	}
end

function Inventory.printState(state: InventoryState): ()
	--!strict
	print("\n=== INVENTORY STATE ===")
	print(string.format("Items: %d/%d", #state.items, state.maxSlots))
	print(string.format("Weight: %.1f/%.1f", state.currentWeight, state.maxWeight))
	print(string.format("Weight %%: %.1f%%", Inventory.getWeightPercentage(state)))
	
	if #state.items > 0 then
		print("\nItems:")
		for i, item in ipairs(state.items) do
			print(
				string.format(
					"  [%d] %s (%s) - Weight: %.1f",
					i,
					item.name,
					item.rarity,
					item.weight
				)
			)
		end
	end
	
	print("======================\n")
end

return Inventory