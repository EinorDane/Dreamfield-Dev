--!strict
--[[
	THREAD-001: Test Framework & Utilities
	
	This module provides a lightweight, Roblox-compatible testing framework
	for unit testing Dreamfield systems. Inspired by TestEZ and Lua Unit.
	
	File: src/shared/TestFramework.luau
	Priority: CRITICAL (dependency for all other tests)
	Complexity: Low
	Time Estimate: 2-3 hours
]]

local TestFramework = {}

-- CONFIG
local VERBOSE_OUTPUT = true

-- SERVICES
local RunService = game:GetService("RunService")

-- TEST STATE
type TestCase = {
	name: string,
	func: () -> (),
	passed: boolean,
	error: string?,
}

type TestSuite = {
	name: string,
	tests: { TestCase },
	passed: number,
	failed: number,
}

local suites: { TestSuite } = {}
local currentSuite: TestSuite? = nil

-- ============================================================
-- PUBLIC: Test Suite Management
-- ============================================================

function TestFramework.describe(suiteName: string, callback: () -> ()): ()
	--!strict
	if currentSuite ~= nil then
		error("Cannot nest describe() calls", 2)
	end
	
	currentSuite = {
		name = suiteName,
		tests = {},
		passed = 0,
		failed = 0,
	}
	
	callback()
	
	table.insert(suites, currentSuite)
	currentSuite = nil
end

function TestFramework.it(testName: string, callback: () -> ()): ()
	--!strict
	if currentSuite == nil then
		error("it() must be called inside describe()", 2)
	end
	
	local testCase: TestCase = {
		name = testName,
		func = callback,
		passed = false,
		error = nil,
	}
	
	-- Run test and catch errors
	local success, result = pcall(callback)
	
	if success then
		testCase.passed = true
		currentSuite.passed += 1
	else
		testCase.passed = false
		testCase.error = tostring(result)
		currentSuite.failed += 1
	end
	
	table.insert(currentSuite.tests, testCase)
end

-- ============================================================
-- PUBLIC: Assertions
-- ============================================================

function TestFramework.assertEqual(actual: any, expected: any): ()
	--!strict
	if actual ~= expected then
		error(
			string.format(
				"Expected %s but got %s",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

function TestFramework.assertNotEqual(actual: any, expected: any): ()
	--!strict
	if actual == expected then
		error(
			string.format(
				"Values should not be equal: %s",
				tostring(actual)
			),
			2
		)
	end
end

function TestFramework.assertTrue(value: any): ()
	--!strict
	if not value then
		error(
			string.format(
				"Expected true but got %s",
				tostring(value)
			),
			2
		)
	end
end

function TestFramework.assertFalse(value: any): ()
	--!strict
	if value then
		error(
			string.format(
				"Expected false but got %s",
				tostring(value)
			),
			2
		)
	end
end

function TestFramework.assertNil(value: any): ()
	--!strict
	if value ~= nil then
		error(
			string.format(
				"Expected nil but got %s",
				tostring(value)
			),
			2
		)
	end
end

function TestFramework.assertNotNil(value: any): ()
	--!strict
	if value == nil then
		error("Expected non-nil value but got nil", 2)
	end
end

function TestFramework.assertIsTable(value: any): ()
	--!strict
	if typeof(value) ~= "table" then
		error(
			string.format(
				"Expected table but got %s",
				typeof(value)
			),
			2
		)
	end
end

function TestFramework.assertTableLength(tbl: any, expectedLength: number): ()
	--!strict
	if typeof(tbl) ~= "table" then
		error(
			string.format(
				"Expected table but got %s",
				typeof(tbl)
			),
			2
		)
	end
	
	local actualLength = #(tbl :: { any })
	if actualLength ~= expectedLength then
		error(
			string.format(
				"Expected table length %d but got %d",
				expectedLength,
				actualLength
			),
			2
		)
	end
end

function TestFramework.assertError(callback: () -> (), expectedMessage: string?): ()
	--!strict
	local success, result = pcall(callback)
	
	if success then
		error("Expected callback to throw an error but it succeeded", 2)
	end
	
	if expectedMessage and not string.find(tostring(result), expectedMessage, 1, true) then
		error(
			string.format(
				"Error message should contain %q but got %q",
				expectedMessage,
				tostring(result)
			),
			2
		)
	end
end

function TestFramework.assertGreater(actual: number, expected: number): ()
	--!strict
	if actual <= expected then
		error(
			string.format(
				"Expected %s to be greater than %s",
				tostring(actual),
				tostring(expected)
			),
			2
		)
	end
end

function TestFramework.assertLess(actual: number, expected: number): ()
	--!strict
	if actual >= expected then
		error(
			string.format(
				"Expected %s to be less than %s",
				tostring(actual),
				tostring(expected)
			),
			2
		)
	end
end

-- ============================================================
-- PUBLIC: Test Execution
-- ============================================================

function TestFramework.run(): (number, number)
	--!strict
	local totalPassed = 0
	local totalFailed = 0
	
	print("\n" .. string.rep("=", 60))
	print("🧪 DREAMFIELD TEST SUITE")
	print(string.rep("=", 60) .. "\n")
	
	for _, suite in ipairs(suites) do
		print(string.format("📦 %s", suite.name))
		print(string.rep("-", 40))
		
		for _, test in ipairs(suite.tests) do
			local status = test.passed and "✅ PASS" or "❌ FAIL"
			print(string.format("  %s: %s", status, test.name))
			
			if test.error and VERBOSE_OUTPUT then
				print(string.format("     Error: %s", test.error))
			end
		end
		
		print(string.format(
			"\n  Results: %d passed, %d failed",
			suite.passed,
			suite.failed
		))
		print()
		
		totalPassed += suite.passed
		totalFailed += suite.failed
	end
	
	print(string.rep("=", 60))
	print(string.format(
		"📊 TOTAL: %d passed, %d failed (%.1f%% pass rate)",
		totalPassed,
		totalFailed,
		totalPassed > 0 and (totalPassed / (totalPassed + totalFailed) * 100) or 0
	))
	print(string.rep("=", 60) .. "\n")
	
	return totalPassed, totalFailed
end

function TestFramework.reset(): ()
	--!strict
	suites = {}
	currentSuite = nil
end

-- ============================================================
-- UTILITY: Test Helpers
-- ============================================================

function TestFramework.createMockPlayer(userId: number, name: string): { any }
	--!strict
	return {
		UserId = userId,
		Name = name,
		IsDescendantOf = function(self, parent)
			return true
		end,
	}
end

function TestFramework.createMockRemote(remoteType: string): { any }
	--!strict
	local mock: { any } = {}
	
	if remoteType == "RemoteFunction" then
		mock.OnServerInvoke = nil :: any
		function mock:InvokeClient(player, ...)
			return nil
		end
		function mock:InvokeServer(...)
			if self.OnServerInvoke then
				return self.OnServerInvoke(nil, ...)
			end
			return nil
		end
	elseif remoteType == "RemoteEvent" then
		mock.OnServerEvent = nil :: any
		mock.OnClientEvent = nil :: any
		
		function mock:FireServer(...)
			if self.OnServerEvent then
				self.OnServerEvent(nil, ...)
			end
		end
		
		function mock:FireClient(player, ...)
			if self.OnClientEvent then
				self.OnClientEvent(...)
			end
		end
		
		function mock:FireAllClients(...)
			if self.OnClientEvent then
				self.OnClientEvent(...)
			end
		end
	end
	
	return mock
end

return TestFramework
