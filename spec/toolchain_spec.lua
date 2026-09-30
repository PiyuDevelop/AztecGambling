-- Checks the test environment itself: the addon needs Lua 5.1 (the version
-- WoW uses), which still has table.getn - removed in later Lua versions
describe("test toolchain", function()
	it("runs on Lua 5.1", function()
		assert.are.equal("Lua 5.1", _VERSION)
	end)

	it("has table.getn, which the addon uses", function()
		assert.is_function(table.getn)
		assert.are.equal(3, table.getn({ "a", "b", "c" }))
	end)
end)
