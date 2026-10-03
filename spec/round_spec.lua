-- Full rounds as the host runs them: starting a game, players joining,
-- Last Call, rolls, the payout and the rankings, plus the buttons around
-- a round (Status, PAY!, Trade, Reset, Enter, Roll!).
local loader = require("spec.support.loader")
local known_bug = require("spec.support.known_bug")
local helpers = require("spec.support.helpers")

describe("a round", function()
	local env, game

	before_each(function()
		env = loader.load()
		game = helpers.new(env)
	end)

	local function play_hilo_round(winner, winning_roll, loser, losing_roll)
		game:start_round({ mode = "HiLo", bet = "500", players = { winner, loser } })
		game:roll(winner, winning_roll)
		game:roll(loser, losing_roll)
	end

	describe("from start to finish", function()
		it("goes from New Game to the payout", function()
			game:set_channel("PARTY")
			game:set_mode("HiLo")
			game:set_bet("500")

			game:click_stage()
			local expected_welcome = "Aztec Gambling v" .. loader.addon_version() .. " is now in session! Mode: HiLo, Bet: 500 gold"
			assert.are.same({ expected_welcome, "Press 1 to Join!" }, game:chat_texts())
			assert.are.equal("LastCall", game:stage())

			game:say("Jayred", "1")
			game:say("Piyu", "1")
			assert.are.same({ "Jayred", "Piyu" }, game:joined_players())

			game:click_stage()
			assert.is_true(game:chat_contains("Last call! 10 seconds left!"))
			assert.are.equal("StartRoll", game:stage())

			-- Last Call starts the rolls by itself after 10 seconds
			game:advance(9.9)
			assert.is_false(game:chat_contains("Time to roll!"))
			game:advance(0.1)
			assert.is_true(game:chat_contains("Time to roll! You have " .. game:time_left() .. " seconds. Good Luck! Command:   /roll (1-500)"))

			game:roll("Jayred", 480)
			game:roll("Piyu", 37)
			assert.is_true(game:chat_contains("Piyu owes Jayred 443 gold!"))
			assert.are.equal(443, game:rankings().Jayred)
			assert.are.equal(-443, game:rankings().Piyu)

			-- Ready for the next round
			assert.are.equal("NewGame", game:stage())
			assert.is_false(game:is_listening())
			assert.are.equal(0, env.clock:pending_count())
		end)

		it("announces everything in the chosen chat channel", function()
			game:start_round({ channel = "SAY", players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 480)
			game:roll("Piyu", 37)
			for _, message in ipairs(env.chat) do
				assert.are.equal("SAY", message.chat_type)
			end
		end)

		it("tells companion windows when the round starts and how it ended", function()
			play_hilo_round("Jayred", 480, "Piyu", 37)
			assert.are.same({ "1 500 500 PARTY" }, game:comm_texts("AG_NEW_GAME"))
			assert.are.same({ "Jayred Piyu 443" }, game:comm_texts("AG_END_GAME"))
			assert.are.equal("PARTY", env.comm_sent[1].distribution)
		end)

		it("starts the rolls right away when the host clicks again during Last Call", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			assert.are.equal(1, game:count_chat("Time to roll!"))
			assert.are.equal("Status", game:stage())

			-- The automatic start was cancelled
			game:advance(10)
			assert.are.equal(1, game:count_chat("Time to roll!"))
		end)

		it("adds up the rankings over several rounds", function()
			play_hilo_round("Jayred", 480, "Piyu", 37)
			play_hilo_round("Piyu", 300, "Jayred", 200)
			assert.are.equal(343, game:rankings().Jayred)
			assert.are.equal(-343, game:rankings().Piyu)
		end)
	end)

	describe("joining", function()
		before_each(function()
			game:set_channel("PARTY")
			game:set_bet("500")
			game:click_stage()
		end)

		it("lets players join by typing 1, with or without spaces", function()
			game:say("Jayred", "1")
			game:say("Piyu", " 1 ")
			assert.are.same({ "Jayred", "Piyu" }, game:joined_players())
		end)

		it("ignores anything other than 1", function()
			game:say("Jayred", "11")
			game:say("Piyu", "join")
			game:say("Zed", "hi 1")
			assert.are.same({}, game:joined_players())
		end)

		it("counts a second 1 from the same player only once", function()
			game:say("Jayred", "1")
			game:say("Jayred", "1")
			assert.are.same({ "Jayred" }, game.host.game.data.turn_order)
		end)

		it("also listens to the group leader's chat", function()
			env.fire_event("CHAT_MSG_PARTY_LEADER", "1", "Jayred-Tichondrius")
			assert.are.same({ "Jayred" }, game:joined_players())
		end)

		it("keeps banned players out", function()
			game.host.db.global.ban_list.Zed = true
			game:say("Zed", "1")
			assert.are.same({}, game:joined_players())
		end)

		it("needs at least 2 players to start rolling", function()
			game:say("Jayred", "1")
			game:click_stage() -- Last Call
			game:click_stage() -- Start Rolling
			assert.is_true(game:chat_contains("Can't start a game with less than 2 players"))
			assert.is_false(game:chat_contains("Time to roll!"))
			assert.are.equal("StartRoll", game:stage())

			-- Players can still join, and the host can try again
			game:say("Piyu", "1")
			game:click_stage()
			assert.is_true(game:chat_contains("Time to roll!"))
		end)

		it("stops taking players once the rolls start", function()
			game:say("Jayred", "1")
			game:say("Piyu", "1")
			game:click_stage()
			game:click_stage()
			game:say("Zed", "1")
			assert.are.same({ "Jayred", "Piyu" }, game:joined_players())
		end)
	end)

	describe("rolling", function()
		local function rolls()
			return game.host.game.data.player_rolls
		end

		it("ignores rolls made before the rolls start", function()
			game:set_bet("500")
			game:click_stage()
			game:say("Jayred", "1")
			game:roll("Jayred", 480, 1, 500)
			assert.are.equal(-1, rolls().Jayred)
		end)

		it("ignores rolls with the wrong range", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 57, 1, 100)
			assert.are.equal(-1, rolls().Jayred)
		end)

		it("ignores rolls from players who didn't join", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			game:roll("Zed", 400)
			assert.is_nil(rolls().Zed)
		end)

		it("counts only each player's first roll", function()
			game:start_round({ players = { "Jayred", "Piyu", "Zed" } })
			game:roll("Jayred", 480)
			game:roll("Jayred", 10)
			assert.are.equal(480, rolls().Jayred)
		end)

		it("ignores system messages that aren't rolls", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			env.fire_event("CHAT_MSG_SYSTEM", "Piyu has gone offline.")
			env.fire_event("CHAT_MSG_SYSTEM", "Zed has joined the party.")
			assert.are.same({ Jayred = -1, Piyu = -1 }, rolls())
		end)

		it("rolls the round's range for the host with Roll!", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			game.host:RollForMe()
			assert.are.same({ { low = 1, high = 500 } }, env.random_rolls)
		end)

		it("tells the host there's nothing to roll for when no round is running", function()
			game.host:RollForMe()
			assert.are.same({}, env.random_rolls)
			assert.are.same({ "You need an active game for me to roll for you!" }, env.system)
		end)

		it("types 1 in the game's chat for the host with Enter", function()
			game:set_channel("PARTY")
			game.host:EnterForMe()
			assert.are.same({ text = "1", chat_type = "PARTY" }, { text = env.chat[1].text, chat_type = env.chat[1].chat_type })
		end)

		-- Bug #3 in docs/improvements.md. RANDOM_ROLL_RESULT copied from the esMX
		-- and esES clients (both use the same text).
		known_bug("counts rolls from a Spanish client (bug #3)", function()
			game:set_roll_format("%s tira los dados y obtiene %d (%d-%d)")
			play_hilo_round("Jayred", 480, "Piyu", 37)
			assert.is_true(game:chat_contains("Piyu owes Jayred 443 gold!"))
		end)

		-- Bug #9 in docs/improvements.md
		known_bug("never sends an empty chat message (bug #9)", function()
			play_hilo_round("Jayred", 480, "Piyu", 37)
			for _, text in ipairs(game:chat_texts()) do
				assert.are_not.equal("", text)
			end
		end)
	end)

	describe("the buttons around a round", function()
		it("posts the time left and who still has to roll with Status", function()
			game:start_round({ players = { "Jayred", "Piyu", "Zed" } })
			game:roll("Jayred", 480)
			game:advance(5)
			local mark = game:mark()
			game:click_stage() -- Status
			assert.is_true(game:chat_contains("Time left to roll: " .. math.floor(game:time_left()) .. " seconds", mark))
			assert.is_true(game:chat_contains("Player: Piyu still needs to roll", mark))
			assert.is_true(game:chat_contains("Player: Zed still needs to roll", mark))
			assert.is_false(game:chat_contains("Player: Jayred", mark))
		end)

		it("repeats the last payout with PAY!", function()
			game.host:RepeatLastPayout()
			assert.are.same({ "No payout to repeat yet!" }, game:chat_texts())

			play_hilo_round("Jayred", 480, "Piyu", 37)
			local mark = game:mark()
			game.host:RepeatLastPayout()
			assert.are.same({ "Piyu owes Jayred 443 gold!" }, game:chat_since(mark))
		end)

		it("opens a trade with the winner for the player who lost", function()
			env = loader.load({ player_name = "Piyu" })
			game = helpers.new(env)
			play_hilo_round("Jayred", 480, "Piyu", 37)
			game.host:OpenTradeWinner()
			assert.are.same({ "Jayred" }, env.trades)
		end)

		it("cancels the round with Reset", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			game:roll("Jayred", 480)
			game.host:ResetGame()

			assert.is_true(game:chat_contains("Game has been reset."))
			assert.is_nil(game.host.game.data)
			assert.are.equal("NewGame", game:stage())
			assert.is_false(game:is_listening())
			assert.are.equal(0, env.clock:pending_count())
			assert.are.same({}, game:rankings())
		end)

		it("cancels Last Call's automatic start with Reset", function()
			game:set_bet("500")
			game:click_stage()
			game:say("Jayred", "1")
			game:say("Piyu", "1")
			game:click_stage() -- Last Call
			game.host:ResetGame()
			assert.has_no.errors(function() game:advance(10) end)
			assert.is_false(game:chat_contains("Time to roll!"))
			assert.are.equal("NewGame", game:stage())
		end)

		-- Bug #1 in docs/improvements.md
		known_bug("does nothing when Trade is pressed before any round (bug #1)", function()
			assert.has_no.errors(function() game.host:OpenTradeWinner() end)
			assert.are.same({}, env.trades)
		end)

		known_bug("opens a trade with the loser for the player who won (bug #1)", function()
			env = loader.load({ player_name = "Jayred" })
			game = helpers.new(env)
			play_hilo_round("Jayred", 480, "Piyu", 37)
			game.host:OpenTradeWinner()
			assert.are.same({ "Piyu" }, env.trades)
		end)

		-- Bug #5 in docs/improvements.md
		known_bug("tells companion windows the round was reset (bug #5)", function()
			game:start_round({ players = { "Jayred", "Piyu" } })
			local sent = #env.comm_sent
			game.host:ResetGame()
			assert.is_true(#env.comm_sent > sent)
		end)
	end)

	-- Bug #13 in docs/improvements.md: the host can change the chat channel
	-- while a round is open. These pass whether the fix locks the dropdown
	-- during a round or moves the listening to the new channel.
	describe("when the host changes the chat channel during a round", function()
		before_each(function()
			game:set_channel("PARTY")
			game:set_bet("500")
			game:click_stage()
			game:say("Jayred", "1")
			game:set_channel("RAID")
		end)

		known_bug("hears players in the channel where the round is announced (bug #13)", function()
			game:click_stage() -- Last Call, announced in the round's channel
			local announced_in = env.chat[#env.chat].chat_type
			env.fire_event("CHAT_MSG_" .. announced_in, "1", "Piyu-Tichondrius")
			assert.are.same({ "Jayred", "Piyu" }, game:joined_players())
		end)

		known_bug("stops listening to every chat channel when the round ends (bug #13)", function()
			game:say("Piyu", "1")
			env.fire_event("CHAT_MSG_PARTY", "1", "Piyu-Tichondrius")
			game:click_stage()
			game:click_stage()
			game:roll("Jayred", 480)
			game:roll("Piyu", 37)
			for _, event in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" }) do
				assert.is_false(env.is_event_registered(event, game.host), event)
			end
		end)
	end)

	-- Bug #6 in docs/improvements.md: an invalid bet should stop the round
	-- from starting and tell the host, instead of being used or replaced silently
	describe("the bet", function()
		known_bug("refuses a bet of 0 and tells the host (bug #6)", function()
			game:set_bet("0")
			game:click_stage()
			assert.is_false(game:chat_contains("now in session"))
			assert.is_true(#env.prints > 0)
		end)

		known_bug("refuses a bet that isn't a number and tells the host (bug #6)", function()
			game:set_bet("lots")
			game:click_stage()
			assert.is_false(game:chat_contains("now in session"))
			assert.is_true(#env.prints > 0)
		end)
	end)
end)
