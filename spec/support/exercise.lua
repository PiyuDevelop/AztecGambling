-- Runs as much of the addon as possible: a round of every mode, tiebreakers,
-- timeouts, the slash commands and the companion window. Used to find every
-- global the addon creates while it runs.
local Exercise = {}

local function round(game, mode, rolls)
	local players = {}
	for index = 1, #rolls, 2 do table.insert(players, rolls[index]) end
	game:start_round({ mode = mode, bet = "500", players = players })
	for index = 1, #rolls, 2 do game:roll(rolls[index], rolls[index + 1]) end
end

-- Every round here has to finish: a round left open would make the next
-- start_round click Status instead of New Game
function Exercise.everything(env, game)
	-- A fixed Curling target, so Curling's two rolls can't tie
	local original_random = math.random
	math.random = function() return 50 end

	-- Every mode, with a tie for the win and one for last place in HiLo
	round(game, "HiLo", { "Jayred", 400, "Piyu", 400, "Zed", 100, "Kal", 100 })
	game:roll("Zed", 50)
	game:roll("Kal", 20)
	game:roll("Jayred", 30)
	game:roll("Piyu", 10)
	round(game, "Inverse", { "Jayred", 37, "Piyu", 480 })
	round(game, "Big2s", { "Jayred", 2, "Piyu", 1 })
	round(game, "LilOnes", { "Jayred", 1, "Piyu", 2 })
	round(game, "Yahtzee", { "Jayred", 44442, "Piyu", 13579, "Zed", 55123, "Kal", 33322 })
	round(game, "Curling", { "Jayred", 48, "Piyu", 90 })

	round(game, "Countdown", { "Jayred", 70, "Piyu", 30 })
	game:roll("Jayred", 200)
	game:roll("Piyu", 1)

	round(game, "Blackjack", { "Jayred", 21, "Piyu", 15, "Zed", 18 })
	game:say("Piyu", "hit")
	game:roll("Piyu", 4)
	game:say("Piyu", "stand")
	game:say("Zed", "hit")
	game:roll("Zed", 5)
	-- Trade only works right after a finished round (bug #1)
	game.host:OpenTradeWinner()

	-- The Status button, a timeout in a losers' tiebreaker, and a cancelled round
	round(game, "HiLo", { "Jayred", 400, "Piyu", 100, "Zed", 100 })
	game:roll("Piyu", 300)
	game:click_stage()
	game:wait_for_timeout()
	game:start_round({ mode = "HiLo", bet = "500", players = { "Jayred", "Piyu" } })
	game:roll("Jayred", 400)
	game:wait_for_timeout()
	math.random = original_random

	-- The buttons and the slash commands
	game.host:RepeatLastPayout()
	game.host:RollForMe()
	game.host:EnterForMe()
	for _, command in ipairs({ "ban Zed", "unban Zed", "stats", "auto", "auto", "help", "dance", "", "", "", "join", "leave", "resetStats", "resetBans" }) do
		env.run_slash("ag", command)
	end
	env.run_slash("agm", "")
	env.fire_event("PLAYER_LEAVING_WORLD")

	-- The companion window
	game:deliver_addon_messages("Host")
	game.client:RollForMe()
	game.client:EnterForMe()
	game.client:OpenTradeWinner()
end

return Exercise
