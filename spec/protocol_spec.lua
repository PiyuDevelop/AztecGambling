-- The host and the companion window talking over a fake network: every addon
-- message the host sends is delivered to the companion window as if another
-- player were hosting. After each step, the companion window has to agree
-- with the host on what to roll and how the round ended.
local loader = require("spec.support.loader")
local known_bug = require("spec.support.known_bug")
local helpers = require("spec.support.helpers")

describe("the host and the companion window", function()
	local game, host, client

	before_each(function()
		game = helpers.new(loader.load({ player_name = "Jayred" }))
		host, client = AztecGambling, AGClient
	end)

	-- Delivers what the host sent, from a player other than the one logged in
	local function sync()
		game:deliver_addon_messages("Host")
	end

	local function assert_same_range()
		assert.are.equal(host.game.data.roll_range, client.current_game.roll_range)
	end

	it("agree on the round from start to finish", function()
		game:start_round({ mode = "HiLo", bet = "500", players = { "Jayred", "Piyu" } })
		sync()
		assert_same_range()
		assert.are.equal(tostring(host.game.data.gold_amount), client.current_game.cash_winnings)
		assert.are.equal(host.chat.channel.const, client.current_game.channel_const)

		game:roll("Jayred", 37)
		game:roll("Piyu", 480)
		sync()
		local data = host.game.data
		assert.are.same(
			{ data.winner, data.loser, tostring(data.cash_winnings) },
			{ client.current_game.winner, client.current_game.loser, client.current_game.cash_winnings }
		)
	end)

	it("agree on what to roll at every step of Countdown", function()
		game:start_round({ mode = "Countdown", bet = "500", players = { "Jayred", "Piyu" } })
		sync()
		assert_same_range() -- the 1-100 roll-off

		game:roll("Jayred", 70)
		game:roll("Piyu", 30)
		sync()
		assert_same_range() -- Jayred's first turn

		game:roll("Jayred", 200)
		sync()
		assert_same_range() -- Piyu's turn, below Jayred's roll
	end)

	it("agree on what a Blackjack hit rolls", function()
		game:start_round({ mode = "Blackjack", bet = "500", players = { "Jayred", "Piyu" } })
		sync()
		assert_same_range() -- the deal

		game:roll("Jayred", 15)
		game:roll("Piyu", 18)
		game:say("Jayred", "hit")
		sync()
		assert_same_range() -- the hit
	end)

	-- Bug #11 in docs/improvements.md: a tie in Blackjack starts a new deal,
	-- but only the host goes back to 1-21
	known_bug("agree on what to roll when Blackjack deals again after a tie (bug #11)", function()
		game:start_round({ mode = "Blackjack", bet = "500", players = { "Jayred", "Piyu" } })
		game:roll("Jayred", 15)
		game:roll("Piyu", 18)
		game:say("Jayred", "hit")
		game:roll("Jayred", 3)
		game:say("Jayred", "stand")
		game:say("Piyu", "stand") -- 18 against 18: tie, new deal
		sync()
		assert.are.equal("(1-21)", host.game.data.roll_range)
		assert_same_range()
	end)

	-- Bug #5 in docs/improvements.md
	known_bug("agree that there's no round after the host resets it (bug #5)", function()
		game:start_round({ mode = "HiLo", bet = "500", players = { "Jayred", "Piyu" } })
		sync()
		host:ResetGame()
		sync()
		assert.is_nil(client.current_game)
	end)
end)
