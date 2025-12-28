--!strict
--[[
	Constants.luau
	Game-wide constants and configuration
]]

export type Constants = {
	MAX_LEVEL: number,
	MAX_CORRUPTION: number,
	MAX_STAMINA: number,
	SHARD_SLOTS: number,
}

local Constants: Constants = {
	MAX_LEVEL = 100,
	MAX_CORRUPTION = 200,
	MAX_STAMINA = 100,
	SHARD_SLOTS = 3,
}

return Constants
