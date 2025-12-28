--!strict
--[[
	CorruptionCalc.luau - Corruption & Cooldown System
	
	Calculates:
	- Corruption pool (sum of equipped shard corruptions)
	- Tolerance progression (level * 5)
	- Cooldown penalties (max(0, (pool - tolerance) * 0.02))
	- Damage multipliers (0.8 + (pool/100)*0.5)
	- Overload state (pool >= maxCorruption)
	- Risk levels (Low/Med/High/Crit)
	
	Used by: CombatCore, SkillSystem, UI
	Depends on: PlayerData, ShardEquip
]]

--!strict

local CorruptionCalc = {}

-- ============================================================
-- TYPES
-- ============================================================

export type CorruptionMetrics = {
	corruptionPool: number,        -- Current total (0-100+)
	maxCorruption: number,         -- Capacity (default 100)
	tolerance: number,             -- Resistance (level * 5)
	overloaded: boolean,           -- Pool >= max
	overloadedPercent: number,     -- (pool / max) * 100
	riskLevel: string,             -- "Low" | "Medium" | "High" | "Critical"
	damageMultiplier: number,      -- 0.8 to 1.3+
	cooldownPenalty: number,       -- 0 to Infinity
	equippedCount: number,         -- How many shards equipped
	percentageUsed: number,        -- (pool / max) * 100
}

-- ============================================================
-- CONFIG
-- ============================================================

local CONFIG = {
	MAX_CORRUPTION = 100,
	BASE_DAMAGE_MULTIPLIER = 0.8,
	DAMAGE_MULTIPLIER_SCALE = 0.5, -- per 100 corruption
	COOLDOWN_PENALTY_FACTOR = 0.02, -- per point over tolerance
	TOLERANCE_SCALE = 5, -- level * this
	
	-- Risk level thresholds (% of maxCorruption)
	RISK_THRESHOLDS = {
		Low = 25,
		Medium = 50,
		High = 85,
		Critical = 100,
	},
	
	-- Colors for UI (RGB 0-1)
	RISK_COLORS = {
		Low = { r = 0.2, g = 1, b = 0.2 }, -- Green
		Medium = { r = 1, g = 1, b = 0.2 }, -- Yellow
		High = { r = 1, g = 0.65, b = 0.2 }, -- Orange
		Critical = { r = 1, g = 0.2, b = 0.2 }, -- Red
	},
}

-- ============================================================
-- PRIVATE FUNCTIONS
-- ============================================================

local function validateMetrics(metrics: CorruptionMetrics): (boolean, string)
	if metrics.corruptionPool < 0 then
		return false, "Corruption pool cannot be negative"
	end
	if metrics.maxCorruption <= 0 then
		return false, "Max corruption must be positive"
	end
	if metrics.tolerance < 0 then
		return false, "Tolerance cannot be negative"
	end
	if metrics.damageMultiplier < 0.5 or metrics.damageMultiplier > 2.0 then
		return false, "Damage multiplier out of expected range"
	end
	if metrics.cooldownPenalty < 0 then
		return false, "Cooldown penalty cannot be negative"
	end
	return true, ""
end

local function calculateTolerance(level: number): number
	if level < 1 then
		return 0
	end
	return level * CONFIG.TOLERANCE_SCALE
end

local function calculateCorruptionPool(equippedShards: table?): number
	if not equippedShards then
		return 0
	end
	
	local pool = 0
	for _, shard in ipairs(equippedShards) do
		if shard then
			pool += shard.corruption or 0
		end
	end
	return pool
end

local function calculateCooldownPenalty(corruptionPool: number, tolerance: number): number
	local penalty = math.max(0, (corruptionPool - tolerance) * CONFIG.COOLDOWN_PENALTY_FACTOR)
	return penalty
end

local function calculateDamageMultiplier(corruptionPool: number): number
	-- 0.8 (base) + (0.5 * corruption/100)
	-- 0% corruption = 0.8x
	-- 50% corruption = 1.05x
	-- 100% corruption = 1.3x
	local multiplier = CONFIG.BASE_DAMAGE_MULTIPLIER + (corruptionPool / 100) * CONFIG.DAMAGE_MULTIPLIER_SCALE
	return math.max(0.5, multiplier) -- Clamp at minimum 0.5x
end

local function calculateRiskLevel(corruptionPercent: number): string
	if corruptionPercent < CONFIG.RISK_THRESHOLDS.Low then
		return "Low"
	elseif corruptionPercent < CONFIG.RISK_THRESHOLDS.Medium then
		return "Medium"
	elseif corruptionPercent < CONFIG.RISK_THRESHOLDS.High then
		return "High"
	else
		return "Critical"
	end
end

local function countEquippedShards(equippedShards: table?): number
	if not equippedShards then
		return 0
	end
	
	local count = 0
	for _, shard in ipairs(equippedShards) do
		if shard then
			count += 1
		end
	end
	return count
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--[[
	calculateMetrics(profile: PlayerProfile): CorruptionMetrics
	
	Calculates all corruption-related metrics based on player profile.
	This is the main entry point.
	
	@param profile - PlayerData profile
	@returns - CorruptionMetrics table with all calculations
]]
function CorruptionCalc.calculateMetrics(profile: any): CorruptionMetrics
	if not profile then
		error("Profile is required")
	end
	
	-- Get values from profile
	local level = profile.level or 1
	local equippedShards = profile.equippedShards or {}
	local maxCorruption = profile.maxCorruption or CONFIG.MAX_CORRUPTION
	
	-- Calculate base values
	local tolerance = calculateTolerance(level)
	local corruptionPool = calculateCorruptionPool(equippedShards)
	local equippedCount = countEquippedShards(equippedShards)
	
	-- Clamp corruption pool to max
	local clampedPool = math.min(corruptionPool, maxCorruption * 1.5) -- Allow slight overage
	
	-- Calculate derived values
	local overloaded = clampedPool >= maxCorruption
	local overloadedPercent = (clampedPool / maxCorruption) * 100
	local riskLevel = calculateRiskLevel(overloadedPercent)
	local damageMultiplier = calculateDamageMultiplier(clampedPool)
	local cooldownPenalty = calculateCooldownPenalty(clampedPool, tolerance)
	
	local metrics: CorruptionMetrics = {
		corruptionPool = clampedPool,
		maxCorruption = maxCorruption,
		tolerance = tolerance,
		overloaded = overloaded,
		overloadedPercent = overloadedPercent,
		riskLevel = riskLevel,
		damageMultiplier = damageMultiplier,
		cooldownPenalty = cooldownPenalty,
		equippedCount = equippedCount,
		percentageUsed = overloadedPercent,
	}
	
	-- Validate metrics
	local valid, msg = validateMetrics(metrics)
	if not valid then
		error("Invalid metrics calculated: " .. msg)
	end
	
	return metrics
end

--[[
	getTolerance(level: number): number
	
	Get tolerance for a specific level.
	
	@param level - Player level
	@returns - Tolerance value
]]
function CorruptionCalc.getTolerance(level: number): number
	return calculateTolerance(level)
end

--[[
	getCorruptionPool(equippedShards: table): number
	
	Get corruption pool from equipped shards.
	
	@param equippedShards - Array of equipped shards
	@returns - Total corruption pool
]]
function CorruptionCalc.getCorruptionPool(equippedShards: table?): number
	return calculateCorruptionPool(equippedShards)
end

--[[
	getCooldownPenalty(corruptionPool: number, tolerance: number): number
	
	Get cooldown penalty for a specific corruption level.
	
	@param corruptionPool - Current corruption pool
	@param tolerance - Player's tolerance
	@returns - Cooldown penalty in seconds
]]
function CorruptionCalc.getCooldownPenalty(corruptionPool: number, tolerance: number): number
	return calculateCooldownPenalty(corruptionPool, tolerance)
end

--[[
	getDamageMultiplier(corruptionPool: number): number
	
	Get damage multiplier for a specific corruption level.
	
	@param corruptionPool - Current corruption pool
	@returns - Damage multiplier (0.8 to 1.3+)
]]
function CorruptionCalc.getDamageMultiplier(corruptionPool: number): number
	return calculateDamageMultiplier(corruptionPool)
end

--[[
	getRiskLevel(corruptionPercent: number): string
	
	Get risk level string for UI.
	
	@param corruptionPercent - Corruption as % of max
	@returns - "Low" | "Medium" | "High" | "Critical"
]]
function CorruptionCalc.getRiskLevel(corruptionPercent: number): string
	return calculateRiskLevel(corruptionPercent)
end

--[[
	getRiskColor(riskLevel: string): table
	
	Get RGB color for a risk level.
	
	@param riskLevel - Risk level string
	@returns - { r, g, b } where each is 0-1
]]
function CorruptionCalc.getRiskColor(riskLevel: string): table
	return CONFIG.RISK_COLORS[riskLevel] or CONFIG.RISK_COLORS.Low
end

--[[
	isOverloaded(corruptionPool: number, maxCorruption: number): boolean
	
	Check if player is overloaded.
	
	@param corruptionPool - Current corruption pool
	@param maxCorruption - Max corruption capacity
	@returns - true if overloaded
]]
function CorruptionCalc.isOverloaded(corruptionPool: number, maxCorruption: number): boolean
	return corruptionPool >= maxCorruption
end

--[[
	getAppliedCooldown(baseCooldown: number, cooldownPenalty: number): number
	
	Get the final cooldown with penalty applied.
	
	@param baseCooldown - Base cooldown in seconds
	@param cooldownPenalty - Penalty in seconds
	@returns - Final cooldown
]]
function CorruptionCalc.getAppliedCooldown(baseCooldown: number, cooldownPenalty: number): number
	return baseCooldown + cooldownPenalty
end

--[[
	getAppliedDamage(baseDamage: number, damageMultiplier: number): number
	
	Get the final damage with multiplier applied.
	
	@param baseDamage - Base damage value
	@param damageMultiplier - Damage multiplier
	@returns - Final damage
]]
function CorruptionCalc.getAppliedDamage(baseDamage: number, damageMultiplier: number): number
	return baseDamage * damageMultiplier
end

--[[
	getConfig(): table
	
	Get the configuration table (for testing).
	
	@returns - CONFIG table
]]
function CorruptionCalc.getConfig(): table
	return CONFIG
end

return CorruptionCalc
