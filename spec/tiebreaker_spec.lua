-- Tiebreakers: when players tie for the win or for last place, only the tied
-- players roll again until there's a single winner and a single loser. The
-- loser still pays based on the first round's rolls.
local loader = require("spec.support.loader")
local helpers = require("spec.support.helpers")

describe("tiebreakers", function()
	local game

	before_each(function()
		game = helpers.new(loader.load())
	end)

	local function play(players_and_rolls, mode)
		local players = {}
		for index = 1, #players_and_rolls, 2 do table.insert(players, players_and_rolls[index]) end
		game:start_round({ mode = mode or "HiLo", bet = "500", players = players })
		for index = 1, #players_and_rolls, 2 do
			game:roll(players_and_rolls[index], players_and_rolls[index + 1])
		end
	end

	local function rolling_players()
		return game:joined_players()
	end

	it("settles a tie for the win with a winners' tiebreaker", function()
		play({ "Jayred", 400, "Piyu", 400, "Zed", 100 })
		assert.is_true(game:chat_contains("The Winners Bracket! High Tiebreaker:"))
		assert.is_true(game:chat_lists_tiebreaker({ "Jayred", "Piyu" }))
		assert.are.same({ "Jayred", "Piyu" }, rolling_players())

		game:roll("Jayred", 50)
		game:roll("Piyu", 20)
		assert.is_true(game:chat_contains("Zed owes Jayred 300 gold!"))
	end)

	it("settles a tie for last with a losers' tiebreaker", function()
		play({ "Jayred", 400, "Piyu", 100, "Zed", 100 })
		assert.is_true(game:chat_contains("The Losers! Low Tiebreaker:"))
		assert.is_true(game:chat_lists_tiebreaker({ "Piyu", "Zed" }))

		game:roll("Piyu", 300)
		game:roll("Zed", 200)
		assert.is_true(game:chat_contains("Zed owes Jayred 300 gold!"))
	end)

	it("only lets the tied players roll", function()
		play({ "Jayred", 400, "Piyu", 400, "Zed", 100 })
		game:roll("Zed", 500)
		assert.is_nil(game.host.game.data.player_rolls.Zed)
	end)

	it("settles the tie for last first, then the tie for the win", function()
		play({ "Jayred", 400, "Piyu", 400, "Zed", 100, "Kal", 100 })
		assert.is_true(game:chat_lists_tiebreaker({ "Zed", "Kal" }))
		assert.is_false(game:chat_contains("The Winners Bracket!"))

		game:roll("Zed", 50)
		game:roll("Kal", 20)
		assert.is_true(game:chat_contains("The Winners Bracket! High Tiebreaker:"))
		assert.is_true(game:chat_lists_tiebreaker({ "Jayred", "Piyu" }))

		game:roll("Jayred", 30)
		game:roll("Piyu", 10)
		assert.is_true(game:chat_contains("Kal owes Jayred 300 gold!"))
	end)

	it("rolls a winners' tiebreaker again when it ties again", function()
		play({ "Jayred", 400, "Piyu", 400, "Zed", 100 })
		game:roll("Jayred", 50)
		game:roll("Piyu", 50)
		assert.are.equal(2, game:count_chat("The Winners Bracket!"))

		game:roll("Jayred", 60)
		game:roll("Piyu", 20)
		assert.is_true(game:chat_contains("Zed owes Jayred 300 gold!"))
	end)

	it("rolls a losers' tiebreaker again when it ties again", function()
		play({ "Jayred", 400, "Piyu", 100, "Zed", 100 })
		game:roll("Piyu", 200)
		game:roll("Zed", 200)
		assert.are.equal(2, game:count_chat("The Losers! Low Tiebreaker:"))

		game:roll("Piyu", 300)
		game:roll("Zed", 100)
		assert.is_true(game:chat_contains("Zed owes Jayred 300 gold!"))
	end)

	it("narrows a losers' tiebreaker down to the players who tie for last again", function()
		play({ "Jayred", 400, "Piyu", 100, "Zed", 100, "Kal", 100 })
		assert.is_true(game:chat_lists_tiebreaker({ "Piyu", "Zed", "Kal" }))

		local mark = game:mark()
		game:roll("Piyu", 300)
		game:roll("Zed", 50)
		game:roll("Kal", 50)
		assert.is_true(game:chat_lists_tiebreaker({ "Zed", "Kal" }, mark))
		assert.are.same({ "Kal", "Zed" }, game:joined_players())

		game:roll("Zed", 40)
		game:roll("Kal", 20)
		assert.is_true(game:chat_contains("Kal owes Jayred 300 gold!"))
	end)

	-- When everyone ties, the first round has no losing roll, so these only
	-- check who wins and who pays
	describe("when everyone ties", function()
		it("has everyone roll a tiebreaker that decides the winner and the loser", function()
			play({ "Jayred", 250, "Piyu", 250, "Zed", 250 })
			assert.is_true(game:chat_lists_tiebreaker({ "Jayred", "Piyu", "Zed" }))

			game:roll("Jayred", 400)
			game:roll("Piyu", 300)
			game:roll("Zed", 100)
			assert.is_true(game:chat_contains("Zed owes Jayred "))
		end)

		it("works with only two players", function()
			play({ "Jayred", 250, "Piyu", 250 })
			game:roll("Jayred", 400)
			game:roll("Piyu", 100)
			assert.is_true(game:chat_contains("Piyu owes Jayred "))
		end)

		it("follows with a losers' tiebreaker when that tiebreaker ties for last", function()
			play({ "Jayred", 250, "Piyu", 250, "Zed", 250 })
			game:roll("Jayred", 400)
			game:roll("Piyu", 100)
			game:roll("Zed", 100)
			assert.is_true(game:chat_contains("The Losers! Low Tiebreaker:"))
			assert.is_true(game:chat_lists_tiebreaker({ "Piyu", "Zed" }))

			game:roll("Piyu", 300)
			game:roll("Zed", 200)
			assert.is_true(game:chat_contains("Zed owes Jayred "))
		end)
	end)
end)
