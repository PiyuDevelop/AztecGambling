-- The rules of each game mode on their own (AGGameModes.lua): roll range for
-- a bet, scoring, who wins and who loses, and how much gets paid. Full rounds
-- with joins, timers and tiebreakers are in the round specs.
local loader = require("spec.support.loader")
local known_bug = require("spec.support.known_bug")

-- A round as the game logic keeps it: the bet as typed in the gold box
local function new_game(bet)
	return { data = { gold_amount = bet } }
end

-- Players from winner to loser, the way the game logic orders them to score a round
local function ranking(mode, rolls)
	local order = {}
	for player in AztecGambling:sortedpairs(rolls, mode.sort_rolls) do
		table.insert(order, player)
	end
	return order
end

local function chat_texts(env)
	local texts = {}
	for index, message in ipairs(env.chat) do texts[index] = message.text end
	return texts
end

describe("game modes", function()
	local env

	before_each(function()
		env = loader.load()
	end)

	it("offers eight modes, in dropdown order", function()
		local labels = {}
		for index, mode in ipairs(GAME_MODES) do labels[index] = mode.label end
		assert.are.same({ "HiLo", "Inverse", "Big2s", "LilOnes", "Yahtzee", "Curling", "Countdown", "Blackjack" }, labels)
	end)

	describe("HiLo", function()
		it("rolls from 1 to the bet", function()
			local game = new_game("500")
			AG_HILO.init_game(game)
			assert.are.equal(1, game.data.roll_lower)
			assert.are.equal(500, game.data.roll_upper)
			assert.are.equal("(1-500)", game.data.roll_range)
		end)

		it("caps the roll range at 1,000,000", function()
			local game = new_game("5000000")
			AG_HILO.init_game(game)
			assert.are.equal(1000000, game.data.roll_upper)
			assert.are.equal("(1-1000000)", game.data.roll_range)
		end)

		it("makes the highest roll win and the lowest lose", function()
			local order = ranking(AG_HILO, { Jayred = 480, Piyu = 37, Zed = 250 })
			assert.are.same({ "Jayred", "Zed", "Piyu" }, order)
		end)

		it("pays the difference between the two rolls", function()
			local game = new_game("500")
			game.data.winning_roll, game.data.losing_roll = 480, 37
			AG_HILO.payout(game)
			assert.are.equal(443, game.data.cash_winnings)
		end)
	end)

	describe("Inverse", function()
		it("rolls from 1 to the bet", function()
			local game = new_game("500")
			AG_INVERSE.init_game(game)
			assert.are.equal("(1-500)", game.data.roll_range)
		end)

		it("makes the lowest roll win and the highest lose", function()
			local order = ranking(AG_INVERSE, { Jayred = 480, Piyu = 37, Zed = 250 })
			assert.are.same({ "Piyu", "Zed", "Jayred" }, order)
		end)

		it("pays the difference between the two rolls", function()
			local game = new_game("500")
			game.data.winning_roll, game.data.losing_roll = 37, 480
			AG_INVERSE.payout(game)
			assert.are.equal(443, game.data.cash_winnings)
		end)
	end)

	describe("Big2s", function()
		it("rolls 1-2 whatever the bet", function()
			local game = new_game("500")
			AG_BIGTWOS.init_game(game)
			assert.are.equal(1, game.data.roll_lower)
			assert.are.equal(2, game.data.roll_upper)
			assert.are.equal("(1-2)", game.data.roll_range)
		end)

		it("makes a 2 beat a 1", function()
			assert.are.same({ "Jayred", "Piyu" }, ranking(AG_BIGTWOS, { Jayred = 2, Piyu = 1 }))
		end)

		it("pays the full bet", function()
			local game = new_game("500")
			AG_BIGTWOS.payout(game)
			assert.are.equal("500", game.data.cash_winnings)
		end)
	end)

	describe("LilOnes", function()
		it("rolls 1-2 whatever the bet", function()
			local game = new_game("500")
			AG_LILONES.init_game(game)
			assert.are.equal("(1-2)", game.data.roll_range)
		end)

		it("makes a 1 beat a 2", function()
			assert.are.same({ "Piyu", "Jayred" }, ranking(AG_LILONES, { Jayred = 2, Piyu = 1 }))
		end)

		it("pays the full bet", function()
			local game = new_game("500")
			AG_LILONES.payout(game)
			assert.are.equal("500", game.data.cash_winnings)
		end)
	end)

	describe("Yahtzee", function()
		-- " 80 - Four of a Kind!": the score and the hand's name, as shown in chat
		local function hand(roll)
			return AG_YAHTZEE.fmt_score(roll)
		end

		it("rolls from 11111 to 99999, read as five dice", function()
			local game = new_game("500")
			AG_YAHTZEE.init_game(game)
			assert.are.equal(11111, game.data.roll_lower)
			assert.are.equal(99999, game.data.roll_upper)
			assert.are.equal("(11111-99999)", game.data.roll_range)
		end)

		it("scores five of a kind as a YAHTZEE worth 100 plus the dice", function()
			assert.are.equal(" 120 - YAHTZEE!", hand(44444))
			assert.are.equal(" 105 - YAHTZEE!", hand(11111))
		end)

		it("names each kind of hand, wherever its dice are", function()
			assert.are.equal(" 80 - Four of a Kind!", hand(44442))
			assert.are.equal(" 80 - Four of a Kind!", hand(24444))
			assert.are.equal(" 75 - Full House!", hand(33322))
			assert.are.equal(" 75 - Full House!", hand(22333))
			assert.are.equal(" 30 - Three of a Kind!", hand(55512))
			assert.are.equal(" 30 - Three of a Kind!", hand(12555))
			assert.are.equal(" 10 - Double 5s!", hand(55123))
			assert.are.equal(" 9 - Singles, 9 High", hand(13579))
		end)

		it("ranks Yahtzee over four of a kind, full house, three of a kind and a pair", function()
			local rolls = { Pair = 99123, Yahtzee = 44444, Three = 55512, Four = 44442, FullHouse = 33322 }
			assert.are.same({ "Yahtzee", "Four", "FullHouse", "Three", "Pair" }, ranking(AG_YAHTZEE, rolls))
		end)

		it("ranks a higher pair over a lower one, counting only the best pair of two", function()
			assert.are.equal(" 10 - Double 5s!", hand(22553))
			assert.are.same({ "Nines", "Fives" }, ranking(AG_YAHTZEE, { Fives = 55123, Nines = 99123 }))
		end)

		it("pays the full bet and announces every hand, best first", function()
			local game = new_game("500")
			game.mode = AG_YAHTZEE
			game.data.player_rolls = { Piyu = 13579, Jayred = 44442 }
			AG_YAHTZEE.payout(game)
			assert.are.equal("500", game.data.cash_winnings)
			assert.are.same({
				"Jayred Roll: 4-4-4-4-2 Score: 80 - Four of a Kind!",
				"Piyu Roll: 1-3-5-7-9 Score: 9 - Singles, 9 High",
			}, chat_texts(env))
		end)

		-- Bug #2 in docs/improvements.md: these describe the correct scoring.
		-- Turn each one into an it() once the bug is fixed. They compare scores,
		-- not the ranking: hands that wrongly tie can come out of the sort in
		-- either order, so a ranking check could pass by luck.
		local function beats(roll, other_roll)
			return AG_YAHTZEE.roll_to_score(roll) > AG_YAHTZEE.roll_to_score(other_roll)
		end

		known_bug("ranks any pair over any high card (bug #2)", function()
			assert.is_true(beats(11234, 12389), "a pair of 1s should beat 9 high")
		end)

		known_bug("ranks hands of the same kind by their dice (bug #2)", function()
			assert.is_true(beats(99992, 22229), "four 9s should beat four 2s")
			assert.is_true(beats(99912, 22219), "three 9s should beat three 2s")
			assert.is_true(beats(99922, 22299), "a full house of 9s over 2s should beat 2s over 9s")
		end)

		known_bug("never lets two pairs with 0s tie three of a kind (bug #2)", function()
			assert.is_true(beats(11123, 90098), "three of a kind should beat two pairs")
		end)

		pending("decide whether a 0 counts as 0 or 10, then test pairs of 0s against pairs of 9s (bug #2)")
	end)

	describe("Curling", function()
		local original_random, asked_for

		before_each(function()
			original_random = math.random
			math.random = function(upper)
				asked_for = upper
				return 50
			end
		end)

		after_each(function()
			math.random = original_random
		end)

		local function start(bet)
			local game = new_game(bet)
			AG_CURLING.init_game(game)
			return game
		end

		it("rolls from 1 to the bet, with a random target in that range", function()
			local game = start("500")
			assert.are.equal("(1-500)", game.data.roll_range)
			assert.are.equal(500, asked_for)
			assert.are.equal(50, game.target_roll)
		end)

		it("scores each roll by its distance to the target", function()
			start("500")
			assert.are.equal(0, AG_CURLING.roll_to_score(50))
			assert.are.equal(2, AG_CURLING.roll_to_score(48))
			assert.are.equal(40, AG_CURLING.roll_to_score(90))
		end)

		it("makes the closest roll win and the farthest lose", function()
			start("500")
			assert.are.same({ "Jayred", "Zed", "Piyu" }, ranking(AG_CURLING, { Jayred = 48, Piyu = 90, Zed = 55 }))
		end)

		it("makes the loser pay their distance to the target and announces it", function()
			local game = start("500")
			game.data.loser, game.data.losing_roll = "Piyu", 40
			AG_CURLING.payout(game)
			assert.are.equal(40, game.data.cash_winnings)
			assert.are.same({ "Bullseye for Curling was: 50", "Piyu was 40 away from the bullseye!" }, chat_texts(env))
		end)
	end)

	describe("Countdown", function()
		it("is a 1v1 mode played in turns, rolling from 1 to the bet", function()
			local game = new_game("500")
			AG_COUNTDOWN.init_game(game)
			assert.are.equal("(1-500)", game.data.roll_range)
			assert.are.equal(2, AG_COUNTDOWN.max_players)
			assert.is_true(AG_COUNTDOWN.turn_based)
		end)

		it("explains its rules when the round starts", function()
			assert.are.equal(AG_MESSAGES.COUNTDOWN_INTRO, AG_COUNTDOWN.custom_intro())
		end)

		it("pays the full bet", function()
			local game = new_game("500")
			AG_COUNTDOWN.payout(game)
			assert.are.equal("500", game.data.cash_winnings)
		end)
	end)

	describe("Blackjack", function()
		it("deals 1-21 and draws 1-10 on each hit", function()
			local game = new_game("500")
			AG_BLACKJACK.init_game(game)
			assert.are.equal("(1-21)", game.data.roll_range)
			assert.is_true(AG_BLACKJACK.hit_stand)
			assert.are.equal(1, AG_BLACKJACK.hit_lower)
			assert.are.equal(10, AG_BLACKJACK.hit_upper)
			assert.are.equal("(1-10)", AG_BLACKJACK.hit_range)
		end)

		it("makes the total closest to 21 win and a bust lose", function()
			local order = ranking(AG_BLACKJACK, { Jayred = 19, Piyu = 25, Zed = 21 })
			assert.are.same({ "Zed", "Jayred", "Piyu" }, order)
		end)

		it("scores every bust the same, below any hand that didn't bust", function()
			assert.are.equal(AG_BLACKJACK.roll_to_score(22), AG_BLACKJACK.roll_to_score(30))
			assert.is_true(AG_BLACKJACK.roll_to_score(22) < AG_BLACKJACK.roll_to_score(1))
		end)

		it("shows busts and blackjacks in the results", function()
			assert.are.equal("25 - BUST!", AG_BLACKJACK.fmt_score(25))
			assert.are.equal("21 - BLACKJACK!", AG_BLACKJACK.fmt_score(21))
			assert.are.equal(18, AG_BLACKJACK.fmt_score(18))
		end)

		it("pays the full bet", function()
			local game = new_game("500")
			AG_BLACKJACK.payout(game)
			assert.are.equal("500", game.data.cash_winnings)
		end)
	end)
end)
