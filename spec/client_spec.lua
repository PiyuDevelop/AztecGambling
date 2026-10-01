-- The companion window (AGClient), as a player who isn't hosting sees it:
-- it learns about the round from the host's addon messages and offers Enter,
-- Roll and Trade.
local loader = require("spec.support.loader")
local UIStub = require("spec.support.ui_stub")

describe("the companion window", function()
	local env, client

	-- The logged-in player is Jayred; Host runs the round from another client
	local function load_as(player_name)
		env = loader.load({ player_name = player_name or "Jayred" })
		client = AGClient
	end

	before_each(function()
		load_as("Jayred")
	end)

	local function from_host(prefix, text, distribution, sender)
		env.deliver_comm(prefix, text, distribution or "PARTY", sender or "Host")
	end

	local function status_text()
		local call = UIStub.last_call(client.ui.AG_Frame, "SetStatusText")
		return call and call[1]
	end

	local function times_shown()
		return #UIStub.calls(client.ui.AG_Frame, "Show")
	end

	describe("when a round starts", function()
		it("learns the range, the bet and the chat channel from AG_NEW_GAME", function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY")
			local round = client.current_game
			assert.are.equal("(1-500)", round.roll_range)
			assert.are.equal("500", round.cash_winnings)
			assert.are.equal("PARTY", round.channel_const)
			assert.are.equal("PARTY", round.addon_const)
		end)

		it("pops up showing what to roll and the bet", function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY")
			assert.are.equal(1, times_shown())
			assert.are.equal("Roll: (1-500)   Cash: 500", status_text())
		end)

		it("stays closed when auto-show is turned off", function()
			client.db.global.auto_pop = false
			from_host("AG_NEW_GAME", "1 500 500 PARTY")
			assert.are.equal(0, times_shown())
			assert.is_table(client.current_game)
		end)

		it("stays closed for the round the player is hosting", function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY", "PARTY", "Jayred")
			assert.are.equal(0, times_shown())
		end)
	end)

	describe("during a round", function()
		before_each(function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY")
		end)

		it("follows Countdown's roll-off and turns", function()
			from_host("AG_TURN_UPDATE", "RollOff 1 100")
			assert.are.equal("Roll-off to go first: Roll (1-100)", status_text())

			from_host("AG_TURN_UPDATE", "Piyu 1 200")
			assert.are.equal("Piyu's turn: Roll (1-200)", status_text())
			assert.are.equal("(1-200)", client.current_game.roll_range)
		end)

		it("rolls the round's range with Roll", function()
			client:RollForMe()
			assert.are.same({ 1, 500 }, { tonumber(env.random_rolls[1].low), tonumber(env.random_rolls[1].high) })
		end)

		it("rolls the new range after a turn update", function()
			from_host("AG_TURN_UPDATE", "Jayred 1 200")
			client:RollForMe()
			assert.are.same({ 1, 200 }, { tonumber(env.random_rolls[1].low), tonumber(env.random_rolls[1].high) })
		end)

		it("types 1 in the round's chat with Enter", function()
			client:EnterForMe()
			assert.are.same({ text = "1", chat_type = "PARTY" }, { text = env.chat[1].text, chat_type = env.chat[1].chat_type })
		end)

		it("shows the result from AG_END_GAME", function()
			from_host("AG_END_GAME", "Piyu Zed 443")
			assert.are.equal("443g Zed = > Piyu", status_text())
			assert.are.equal("Piyu", client.current_game.winner)
			assert.are.equal("Zed", client.current_game.loser)
		end)
	end)

	describe("with no round", function()
		it("ignores turn updates and results", function()
			assert.has_no.errors(function()
				from_host("AG_TURN_UPDATE", "Piyu 1 200")
				from_host("AG_END_GAME", "Piyu Zed 443")
			end)
			assert.is_nil(client.current_game)
		end)

		it("does nothing on Roll or Enter", function()
			client:RollForMe()
			client:EnterForMe()
			assert.are.same({}, env.random_rolls)
			assert.are.same({}, env.chat)
		end)
	end)

	describe("Trade", function()
		it("opens a trade with the winner for the player who lost", function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY")
			from_host("AG_END_GAME", "Piyu Jayred 443")
			client:OpenTradeWinner()
			assert.are.same({ "Piyu" }, env.trades)
		end)

		-- Bug #1 in docs/improvements.md
		pending("does nothing when pressed before any round (bug #1)", function()
			assert.has_no.errors(function() client:OpenTradeWinner() end)
			assert.are.same({}, env.trades)
		end)

		pending("opens a trade with the loser for the player who won (bug #1)", function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY")
			from_host("AG_END_GAME", "Jayred Piyu 443")
			client:OpenTradeWinner()
			assert.are.same({ "Piyu" }, env.trades)
		end)
	end)

	-- Outside a group, other players' /roll results aren't always visible, so in
	-- Guild and Say rounds each companion window shares its player's rolls
	describe("in Guild and Say rounds", function()
		local function roll_message(player, roll)
			return string.format(RANDOM_ROLL_RESULT, player, roll, 1, 500)
		end

		local function forwarded()
			local texts = {}
			for _, message in ipairs(env.comm_sent) do
				if message.prefix == "AG_GUILD_ROLL" then table.insert(texts, message.text .. " via " .. message.distribution) end
			end
			return texts
		end

		it("shares the player's own rolls over the addon channel", function()
			from_host("AG_NEW_GAME", "1 500 500 SAY", "GUILD")
			env.fire_event("CHAT_MSG_SYSTEM", roll_message("Jayred", 57))
			assert.are.same({ "Jayred rolls 57 (1-500) via GUILD" }, forwarded())
		end)

		it("doesn't share other players' rolls, or rolls with another range", function()
			from_host("AG_NEW_GAME", "1 500 500 SAY", "GUILD")
			env.fire_event("CHAT_MSG_SYSTEM", roll_message("Piyu", 57))
			env.fire_event("CHAT_MSG_SYSTEM", string.format(RANDOM_ROLL_RESULT, "Jayred", 57, 1, 100))
			assert.are.same({}, forwarded())
		end)

		it("doesn't share rolls in Party or Raid rounds, where everyone sees them", function()
			from_host("AG_NEW_GAME", "1 500 500 PARTY", "PARTY")
			env.fire_event("CHAT_MSG_SYSTEM", roll_message("Jayred", 57))
			assert.are.same({}, forwarded())
		end)

		it("shows rolls shared by other players as system messages, but not the player's own", function()
			from_host("AG_NEW_GAME", "1 500 500 SAY", "GUILD")
			from_host("AG_GUILD_ROLL", roll_message("Piyu", 57), "GUILD", "Piyu")
			from_host("AG_GUILD_ROLL", roll_message("Jayred", 12), "GUILD", "Jayred")
			assert.are.same({ "Piyu rolls 57 (1-500)" }, env.system)
		end)
	end)
end)
