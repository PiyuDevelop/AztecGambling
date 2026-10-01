-- The helper functions in AGUtils.lua, which the game logic relies on to read
-- chat text and to order players by their rolls.
local loader = require("spec.support.loader")

describe("AGUtils", function()
	before_each(function()
		loader.load()
	end)

	describe("SplitString", function()
		it("splits a /roll system message into words", function()
			local words = AztecGambling:SplitString("Jayred rolls 57 (1-100)", "%S+")
			assert.are.same({ "Jayred", "rolls", "57", "(1-100)" }, words)
		end)

		it("returns an empty list for an empty text", function()
			assert.are.same({}, AztecGambling:SplitString("", "%S+"))
		end)
	end)

	describe("sortedpairs", function()
		local function keys_in_order(iterator)
			local keys = {}
			for key, value in iterator do table.insert(keys, key .. "=" .. value) end
			return keys
		end

		it("goes through the keys in alphabetical order when no order is given", function()
			local rolls = { Piyu = 12, Jayred = 57, Zed = 3 }
			assert.are.same({ "Jayred=57", "Piyu=12", "Zed=3" }, keys_in_order(AztecGambling:sortedpairs(rolls)))
		end)

		it("uses the given order, which receives the table and two keys", function()
			local rolls = { Piyu = 12, Jayred = 57, Zed = 3 }
			local highest_first = function(t, a, b) return t[b] < t[a] end
			assert.are.same({ "Jayred=57", "Piyu=12", "Zed=3" }, keys_in_order(AztecGambling:sortedpairs(rolls, highest_first)))
			local lowest_first = function(t, a, b) return t[b] > t[a] end
			assert.are.same({ "Zed=3", "Piyu=12", "Jayred=57" }, keys_in_order(AztecGambling:sortedpairs(rolls, lowest_first)))
		end)

		it("goes through nothing for an empty table", function()
			assert.are.same({}, keys_in_order(AztecGambling:sortedpairs({})))
		end)
	end)

	describe("TableLength", function()
		it("counts the entries of a table keyed by player name", function()
			assert.are.equal(3, AztecGambling:TableLength({ Jayred = 57, Piyu = -1, Zed = 3 }))
		end)

		it("counts 0 for an empty table and for nil", function()
			assert.are.equal(0, AztecGambling:TableLength({}))
			assert.are.equal(0, AztecGambling:TableLength(nil))
		end)
	end)

	describe("CopyTable", function()
		it("makes a new table with the same values, sharing nested tables", function()
			local nested = { hide = false }
			local original = setmetatable({ width = 400, minimap = nested }, { __index = { height = 220 } })
			local copy = AztecGambling:CopyTable(original)
			assert.are_not.equal(original, copy)
			assert.are.equal(400, copy.width)
			assert.are.equal(nested, copy.minimap)
			assert.are.equal(220, copy.height)
		end)
	end)

	describe("deepcopy", function()
		it("copies nested tables too", function()
			local original = { rankings = { Jayred = 500 }, name = "casino" }
			local copy = AztecGambling:deepcopy(original)
			assert.are.same(original, copy)
			assert.are_not.equal(original.rankings, copy.rankings)
			copy.rankings.Jayred = 0
			assert.are.equal(500, original.rankings.Jayred)
		end)

		it("returns plain values as they are", function()
			assert.are.equal(42, AztecGambling:deepcopy(42))
			assert.are.equal("HiLo", AztecGambling:deepcopy("HiLo"))
		end)
	end)
end)
