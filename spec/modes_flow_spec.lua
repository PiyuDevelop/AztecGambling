-- Each game mode played from start to finish: the modes with their own flow
-- (Countdown's turns, Blackjack's hit or stand) and the ones that announce
-- extra results (Curling, Yahtzee).
local loader = require("spec.support.loader")
local known_bug = require("spec.support.known_bug")
local helpers = require("spec.support.helpers")

describe("playing", function()
	local env, game

	before_each(function()
		env = loader.load()
		game = helpers.new(env)
	end)

	describe("HiLo's siblings", function()
		it("Inverse makes the lowest roll win", function()
			game:start_round({ mode = "Inverse", players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 37)
			game:roll("Piyu", 480)
			assert.is_true(game:chat_contains("Piyu owes Jayred 443 gold!"))
		end)

		it("Big2s makes a 2 win the full bet", function()
			game:start_round({ mode = "Big2s", players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 2)
			game:roll("Piyu", 1)
			assert.is_true(game:chat_contains("Piyu owes Jayred 500 gold!"))
		end)

		it("LilOnes makes a 1 win the full bet", function()
			game:start_round({ mode = "LilOnes", players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 1)
			game:roll("Piyu", 2)
			assert.is_true(game:chat_contains("Piyu owes Jayred 500 gold!"))
		end)
	end)

	describe("Countdown", function()
		local function start()
			game:start_round({ mode = "Countdown", players = { "Jayred", "Piyu" } })
		end

		it("decides who goes first with a 1-100 roll-off, then alternates turns until someone rolls a 1", function()
			start()
			assert.is_true(game:chat_contains("Roll 1-100 to see who goes first! Command:   /roll (1-100)"))

			game:roll("Jayred", 70)
			game:roll("Piyu", 30)
			assert.is_true(game:chat_contains("Jayred rolled higher and goes first! Command:   /roll (1-500)"))

			game:roll("Jayred", 200)
			assert.is_true(game:chat_contains("Piyu's turn! Command:   /roll (1-200)"))

			game:roll("Piyu", 1)
			assert.is_true(game:chat_contains("Piyu owes Jayred 500 gold!"))
		end)

		it("tells companion windows whose turn it is and what to roll", function()
			start()
			game:roll("Jayred", 70)
			game:roll("Piyu", 30)
			game:roll("Jayred", 200)
			assert.are.same({ "RollOff 1 100", "Jayred 1 500", "Piyu 1 200" }, game:comm_texts("AG_TURN_UPDATE"))
		end)

		it("ignores rolls out of turn", function()
			start()
			game:roll("Jayred", 70)
			game:roll("Piyu", 30)
			game:roll("Piyu", 1)
			assert.is_false(game:chat_contains("owes"))
			assert.are.equal("Jayred", game.host.game.data.turn_player)
		end)

		it("rolls the roll-off again on a tie", function()
			start()
			game:roll("Jayred", 50)
			game:roll("Piyu", 50)
			assert.is_true(game:chat_contains("Tie! Roll again to see who goes first."))

			game:roll("Jayred", 40)
			game:roll("Piyu", 60)
			assert.is_true(game:chat_contains("Piyu rolled higher and goes first!"))
		end)

		it("names only the player whose turn it is with Status, after the first turn", function()
			start()
			game:roll("Jayred", 70)
			game:roll("Piyu", 30)
			game:roll("Jayred", 200)
			local mark = game:mark()
			game:click_stage() -- Status
			assert.is_true(game:chat_has_line("Player: Piyu still needs to roll", mark))
			assert.is_false(game:chat_contains("Jayred still needs", mark))
		end)

		-- Bug #14 in docs/improvements.md: after the roll-off both players are
		-- marked as still having to roll, so Status names both on the first turn
		known_bug("names only the player whose turn it is with Status, on the first turn too (bug #14)", function()
			start()
			game:roll("Jayred", 70)
			game:roll("Piyu", 30)
			local mark = game:mark()
			game:click_stage() -- Status
			assert.is_true(game:chat_has_line("Player: Jayred still needs to roll", mark))
			assert.is_false(game:chat_contains("Piyu still needs", mark))
		end)

		it("needs exactly two players", function()
			game:set_mode("Countdown")
			game:set_bet("500")
			game:click_stage()
			game:say("Jayred", "1")
			game:click_stage()
			game:click_stage()
			assert.is_true(game:chat_contains("Countdown needs exactly 2 players."))
			assert.are.equal("StartRoll", game:stage())
		end)

		it("doesn't let a third player join", function()
			game:set_mode("Countdown")
			game:set_bet("500")
			game:click_stage()
			game:say("Jayred", "1")
			game:say("Piyu", "1")
			game:say("Zed", "1")
			assert.are.same({ "Jayred", "Piyu" }, game:joined_players())
		end)
	end)

	describe("Blackjack", function()
		local function deal(rolls)
			local players = {}
			for index = 1, #rolls, 2 do table.insert(players, rolls[index]) end
			game:start_round({ mode = "Blackjack", players = players })
			for index = 1, #rolls, 2 do game:roll(rolls[index], rolls[index + 1]) end
		end

		local function total(player)
			return game.host.game.data.player_rolls[player]
		end

		it("deals a hand to everyone, then lets players hit or stand until all are done", function()
			deal({ "Jayred", 21, "Piyu", 15, "Zed", 18 })
			assert.is_true(game:chat_contains("Jayred has a natural BLACKJACK!"))
			assert.is_true(game:chat_contains(AG_MESSAGES.DEALT))

			game:say("Piyu", "hit")
			assert.is_true(game:chat_contains("Piyu hits! Command:   /roll (1-10)"))
			game:roll("Piyu", 4)
			assert.is_true(game:chat_contains("Piyu drew a 4 for 19. Hit or stand?"))
			game:say("Piyu", "stand")
			assert.is_true(game:chat_contains("Piyu stands with 19!"))

			game:say("Zed", "hit")
			game:roll("Zed", 5)
			assert.is_true(game:chat_contains("Zed drew a 5 for 23 - BUST!"))

			assert.is_true(game:chat_contains("Zed owes Jayred 500 gold!"))
		end)

		it("tells companion windows what range a hit rolls", function()
			deal({ "Jayred", 15, "Piyu", 18 })
			game:say("Jayred", "hit")
			assert.are.same({ "Jayred 1 10" }, game:comm_texts("AG_TURN_UPDATE"))
		end)

		it("ignores a hit roll from a player who didn't say hit", function()
			deal({ "Jayred", 15, "Piyu", 18 })
			game:roll("Jayred", 4)
			assert.are.equal(15, total("Jayred"))
		end)

		it("stands a player automatically when a hit reaches 21", function()
			deal({ "Jayred", 15, "Piyu", 18 })
			game:say("Jayred", "hit")
			game:roll("Jayred", 6)
			assert.is_true(game:chat_contains("Jayred drew a 6 for 21 - BLACKJACK!"))
			assert.is_false(game.host.game.data.blackjack_active.Jayred)
		end)

		it("deals a new hand from 1-21 when the hands tie", function()
			deal({ "Jayred", 15, "Piyu", 18 })
			game:say("Jayred", "hit")
			game:roll("Jayred", 3)
			game:say("Jayred", "stand")
			game:say("Piyu", "stand") -- 18 against 18
			assert.is_true(game:chat_contains("The Winners Bracket! High Tiebreaker:"))
			assert.are.equal("(1-21)", game.host.game.data.roll_range)
			assert.is_false(game.host.game.data.dealt)

			game:roll("Jayred", 20)
			game:roll("Piyu", 17)
			assert.are.equal(2, game:count_chat(AG_MESSAGES.DEALT))
			game:say("Jayred", "stand")
			game:say("Piyu", "stand")
			assert.is_true(game:chat_contains("Piyu owes Jayred 500 gold!"))
		end)

		it("lists who still has to hit or stand with Status", function()
			deal({ "Jayred", 21, "Piyu", 15, "Zed", 18 })
			game:say("Zed", "stand")
			local mark = game:mark()
			game:click_stage() -- Status
			assert.is_true(game:chat_has_line("Player: Piyu still needs to hit or stand", mark))
			assert.is_false(game:chat_contains("Jayred still needs", mark))
			assert.is_false(game:chat_contains("Zed still needs", mark))
		end)

		it("ignores hit and stand from a player who is already done", function()
			deal({ "Jayred", 21, "Piyu", 15 })
			game:say("Jayred", "hit")
			assert.is_false(game:chat_contains("Jayred hits!"))
		end)
	end)

	describe("Curling", function()
		local original_random

		before_each(function()
			original_random = math.random
			math.random = function() return 50 end
		end)

		after_each(function()
			math.random = original_random
		end)

		it("makes the loser pay their distance to the target and reveals it", function()
			game:start_round({ mode = "Curling", players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 48)
			game:roll("Piyu", 90)
			assert.is_true(game:chat_contains("Bullseye for Curling was: 50"))
			assert.is_true(game:chat_contains("Piyu was 40 away from the bullseye!"))
			assert.is_true(game:chat_contains("Piyu owes Jayred 40 gold!"))
		end)
	end)

	describe("Yahtzee", function()
		it("reads each roll as five dice and announces every hand before the payout", function()
			game:start_round({ mode = "Yahtzee", players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 44442)
			game:roll("Piyu", 13579)

			local texts = game:chat_texts()
			local last = #texts
			assert.are.same({
				"Jayred Roll: 4-4-4-4-2 Score: 80 - Four of a Kind!",
				"Piyu Roll: 1-3-5-7-9 Score: 9 - Singles, 9 High",
				"Piyu owes Jayred 500 gold!",
			}, { texts[last - 2], texts[last - 1], texts[last] })
		end)
	end)
end)
