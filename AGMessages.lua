-- AGMessages.lua
-- ======================================================
-- Every piece of text that gets sent out to chat (via MessageChat /
-- SendChatMessage) lives here, in one place, so it can be reworded
-- without hunting through the game logic files.
--
-- Static lines are plain strings. Lines that need to embed a name,
-- number, etc. are functions that take those values and return the
-- final string.

AG_MESSAGES = {

	-- Game start / join flow
	CUSTOM_CHANNEL_ANNOUNCE = function(channel_name)
		return "Just started a Gambling Round in a custom channel! To join in use /ag join or /join "..channel_name
	end,
	WELCOME = function(mode_label, gold_amount)
		return "Aztec Gambiling is now in session! Mode: "..mode_label..", Bet: "..gold_amount.." gold"
	end,
	PRESS_TO_JOIN = "Press 1 to Join!",
	TELL_FRIENDS = function(channel_name)
		return "Tell your friends to join the channel by /ag join or /join "..channel_name
	end,
	JOIN_SIGNAL = "1", -- the actual chat text a "join" / "enter for me" click sends
	LAST_CALL = "Last call! 10 seconds left!",
	NOT_ENOUGH_PLAYERS = "Can't start a game with less than 2 players",

	-- Tiebreakers
	HIGH_TIEBREAKER = "The Winners Bracket! High Tiebreaker:",
	LOW_TIEBREAKER = "The Losers! Low Tiebreaker:",
	TIEBREAKER_VS = " vs ",
	ROLL_OFF_TIE = "Tie! Roll again to see who goes first.",

	-- Rolling
	ROLL_GOODLUCK = function(roll_range, seconds)
		return "Time to roll! You have "..seconds.." seconds. Good Luck! Command:   /roll "..roll_range
	end,
	TIME_LEFT = function(seconds_left)
		return "Time left to roll: "..seconds_left.." seconds"
	end,
	PLAYER_NEEDS_HIT_OR_STAND = function(player)
		return "Player: "..player.." still needs to hit or stand"
	end,
	PLAYER_NEEDS_ROLL = function(player)
		return "Player: "..player.." still needs to roll"
	end,

	-- Roll time limit (players is a list of names)
	ROLL_TIME_WARNING = function(seconds_left, players)
		return seconds_left.." seconds left! Still waiting on: "..table.concat(players, ", ")
	end,
	TIMEOUT_REMOVED = function(players)
		return "Time's up! Removed for not rolling: "..table.concat(players, ", ")
	end,
	TIMEOUT_GAVE_UP_WIN = function(players)
		return "Time's up! Gave up the win for not rolling: "..table.concat(players, ", ")
	end,
	TIMEOUT_TIED_LAST = function(players)
		return "Time's up! Tied for last for not rolling: "..table.concat(players, ", ")
	end,
	TIMEOUT_LOSES = function(player)
		return "Time's up! "..player.." didn't roll and loses the round."
	end,
	TIMEOUT_AUTO_STAND = function(players)
		return "Time's up! Standing automatically: "..table.concat(players, ", ")
	end,
	TIMEOUT_CANCELLED = "Time's up! Not enough players rolled. Round cancelled.",

	-- Countdown (1v1 roll war)
	COUNTDOWN_NEEDS_PLAYERS = function(required)
		return "Countdown needs exactly "..required.." players."
	end,
	ROLL_OFF_FIRST = "Roll 1-100 to see who goes first! Command:   /roll (1-100)",
	ROLL_OFF_WINNER = function(starter, roll_range)
		return starter.." rolled higher and goes first! Command:   /roll "..roll_range
	end,
	OPPONENT_TURN = function(opponent, roll_range)
		return opponent.."'s turn! Command:   /roll "..roll_range
	end,
	COUNTDOWN_INTRO = "1v1 Roll War! Each roll sets the ceiling for the next one - whoever rolls a 1 loses the bet!",

	-- Blackjack
	NATURAL_BLACKJACK = function(player)
		return player.." has a natural BLACKJACK!"
	end,
	DEALT = "Dealt! Type 'hit' to draw another card or 'stand' to lock in your total.",
	HIT_DRAW_BUST = function(player, roll, new_total)
		return player.." drew a "..roll.." for "..new_total.." - BUST!"
	end,
	HIT_DRAW_BLACKJACK = function(player, roll)
		return player.." drew a "..roll.." for 21 - BLACKJACK!"
	end,
	HIT_DRAW_CONTINUE = function(player, roll, new_total)
		return player.." drew a "..roll.." for "..new_total..". Hit or stand?"
	end,
	HITS = function(sender, roll_range)
		return sender.." hits! Command:   /roll "..roll_range
	end,
	STANDS = function(sender, total)
		return sender.." stands with "..total.."!"
	end,
	BLACKJACK_INTRO = "Roll your starting hand! Then type 'hit' to draw another card (1-10) or 'stand' to lock in your total. Get as close to 21 as possible without busting!",

	-- Yahtzee
	YAHTZEE_ROLL = function(player, formatted_roll, score, hand)
		return player.." Roll: "..formatted_roll.." Score: "..score.." - "..hand
	end,

	-- Curling
	CURLING_INTRO = function(gold_amount, target_roll)
		return "Roll from 1-"..gold_amount.." to try and hit "..target_roll.."!"
	end,
	CURLING_BULLSEYE = function(target_roll)
		return "Bullseye for Curling was: "..target_roll
	end,
	CURLING_AWAY = function(loser, cash_winnings)
		return loser.." was "..cash_winnings.." away from the bullseye!"
	end,

	-- Payout / results
	PAYOUT = function(loser, winner, cash_winnings)
		return loser.." owes "..winner.." "..cash_winnings.." gold!"
	end,
	NO_PAYOUT_YET = "No payout to repeat yet!",
	GAME_RESET = "Game has been reset.",

	-- Rankings / banlist
	HALL_OF_GTFO = "Hall of GTFO:",
	HALL_OF_FAME = "Hall of Fame: ",
	HALL_OF_SHAME = "Hall of Shame: ",
	RANK_SEPARATOR = "~~~~~~",
	RANK_WON = function(index, player, gold)
		return string.format("%d. %s won %d gold.", index, player, gold)
	end,
	RANK_LOST = function(index, player, gold)
		return string.format("%d. %s lost %d gold.", index, player, math.abs(gold))
	end,

	-- Misc / system messages (not sent to chat, shown locally via SendSystemMessage)
	NO_ACTIVE_GAME_TO_ROLL = "You need an active game for me to roll for you!",
}
