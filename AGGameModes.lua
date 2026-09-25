
-- Consts for Sorting, shortcuts for common cases
local AG_SORT_DESCENDING = function(scores, playera, playerb) return scores[playerb] < scores[playera] end
local AG_SORT_ASCENDING  = function(scores, playera, playerb) return scores[playerb] > scores[playera] end
local AG_MAX_ROLL = function(roll) return (tonumber(roll) > 1000000) and 1000000 or tonumber(roll) end

-- High/Low 
-- ==================
AG_HILO = {
	-- String for game name
	label = "HiLo",

	-- When everyone ties, the tiebreaker plays like a normal round with fewer
	-- players: whoever doesn't roll in time is removed instead of losing
	everyone_tied_removes = true,

	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = AG_MAX_ROLL(game.data.gold_amount)
		game.data.roll_range = "(1-"..game.data.roll_upper..")"
	end,
	
	roll_to_score = function(roll)
		return tonumber(roll)
	end,
	
	fmt_score = function(roll) return roll end,

	sort_rolls = AG_SORT_DESCENDING,
	
	payout = function(game)
		game.data.cash_winnings = game.data.winning_roll - game.data.losing_roll
	end,
}

-- Mystery
-- ==============
AG_MYSTERY = {
	-- String for game name
	label = "HiLo",
	
	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = AG_MAX_ROLL(game.data.gold_amount)
		game.data.roll_range = "(1-"..game.data.roll_upper..")"
	end,
	
	roll_to_score = function(roll)
		return tonumber(roll)
	end,
	
	fmt_score = function(roll) return roll end,

	sort_rolls = AG_SORT_DESCENDING,
	
	payout = function(game)
		game.data.cash_winnings = game.data.winning_roll - game.data.losing_roll
	end,
}

-- BigTwos 
-- ==============
AG_BIGTWOS = {
	label = "Big2s",
	
	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = 2
		game.data.roll_range = "(1-2)"
	end,
	
	roll_to_score = function(roll)
		return tonumber(roll)
	end,
	
	fmt_score = function(roll) return roll end,
	
	sort_rolls = AG_SORT_DESCENDING,
	
	payout = function(game)
		game.data.cash_winnings = game.data.gold_amount
	end,

}

-- LILONES
-- ==============
AG_LILONES = {
	label = "LilOnes",
	
	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = 2
		game.data.roll_range = "(1-2)"
	end,
	
	roll_to_score = function(roll)
		return tonumber(roll)
	end,
	
	fmt_score = function(roll) return roll end,
	
	sort_rolls = AG_SORT_ASCENDING,
	
	payout = function(game)
		game.data.cash_winnings = game.data.gold_amount
	end,

}

-- Inverse
-- ===========
AG_INVERSE = {
	label = "Inverse",
	everyone_tied_removes = true, -- see AG_HILO

	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = AG_MAX_ROLL(game.data.gold_amount)
		game.data.roll_range = "(1-"..game.data.roll_upper..")"
	end,
	
	roll_to_score = function(roll)
		return tonumber(roll)
	end,
	
	fmt_score = function(roll) return roll end,
	
	sort_rolls = AG_SORT_ASCENDING,
	
	payout = function(game)
		game.data.cash_winnings = game.data.losing_roll - game.data.winning_roll
	end,

}

-- Russian Roullette
-- ===================
AG_ROULETTE= {
	label = "Roulette",
	
	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = 6
		game.data.roll_range = "(1-6)"
	end,
	
	roll_to_score = function(roll)
		if (tonumber(roll) == 1) then
			return 0 -- They LOSE
		else
			return 1
		end
	end,
	
	fmt_score = function(roll) return roll end,
	
	sort_rolls = AG_SORT_DESCENDING,
	
	payout = function(game)
		game.data.cash_winnings = game.data.gold_amount
	end,

}


-- Yahtzee
-- ============
local function ScoreYahtzee(roll)
	-- Get the total of this dice, common score
	total = 0
	for digit in string.gmatch(roll, "%d") do
		if (tonumber(digit) == 0) then
			total = total + 1 -- Adjust for 0
		else
			total = total + tonumber(digit)
		end
	end
	
	hand, score, highroll = "", 0, 0
	
	-- Evaluate best possible hand
	for digit in string.gmatch(roll, "%d") do
	
		-- If you hit these your other numbers wont be better
		local _, count = string.gsub(roll, digit, "")
		if (count == 5) then
			return "YAHTZEE!", 100 + total
		end
		
		if (count == 4) then
			return "Four of a Kind!", 80
		end
		
		if (count == 3) then
			-- Check for Full House
			for digit in string.gmatch(roll, "%d") do
				local _, other_count = string.gsub(roll, digit, "")
				if (other_count == 2) then
					return "Full House!", 75
				end
			end
			
			return "Three of a Kind!", 30
		end
		
		
		-- Doubles, could get better
		if (count == 2) then
			-- Check for full house
			for digit in string.gmatch(roll, "%d") do
				local _, other_count = string.gsub(roll, digit, "")
				if (other_count == 3) then
					return "Full House!", 75
				end
			end
			
			-- Doubles are the dice added together, 0->1 
			new_score = tonumber(digit)*2 
			if (tonumber(digit) == 0) then
				new_score = 2 + total
			end
			
			-- Evaluate the best doubles
			if (new_score > score) then
				score = new_score 
				hand = "Double "..digit.."s!"
			end
		end
		
		-- Singles UGH
		if (count == 1) then
			if (tonumber(digit) > highroll) then
				highroll = tonumber(digit)
			end
		end
		
	end	
	
	-- Singles Bummer
	if (score == 0) then
		score = highroll
		hand = "Singles, "..highroll.." High"
		if (highroll == 0) then
			score = 1
		end
	end

	return hand, score
end

local function FormatYahtzee(roll)
	local ret_string = ""
	for digit in string.gmatch(roll, "%d") do
		ret_string = ret_string..digit.."-"
    end
	ret_string = ret_string.."!!"
	return string.gsub(ret_string, "-!!", "")
end


AG_YAHTZEE = {
	label = "Yahtzee",
	
	init_game = function(game)
		game.data.roll_range = "(11111-99999)"
		game.data.roll_upper = 99999
		game.data.roll_lower = 11111
	end,
	
	roll_to_score = function(roll)
		hand, score = ScoreYahtzee(roll)
		return score
	end,
	
	fmt_score = function(roll)
		hand, score = ScoreYahtzee(roll)
		return " "..score.." - "..hand
	end,
	
	sort_rolls =  function(scores, playera, playerb) 
		local _, scoreA = ScoreYahtzee(scores[playera])
		local _, scoreB = ScoreYahtzee(scores[playerb])
		-- Sort from Highest to Lowest
		return scoreB < scoreA
	end,
	
	payout = function(game)
		for player, roll in AztecGambling:sortedpairs(game.data.player_rolls, game.mode.sort_rolls) do
			local hand, score = ScoreYahtzee(roll)
			AztecGambling:MessageChat(AG_MESSAGES.YAHTZEE_ROLL(player, FormatYahtzee(roll), score, hand))
		end
		game.data.cash_winnings = game.data.gold_amount
	end,

}

AG_CURLING = {
	label = "Curling",
	target_roll = 0,
	
	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = AG_MAX_ROLL(game.data.gold_amount) 
		game.data.roll_range = "(1-"..game.data.roll_upper..")"
		game.target_roll = math.random(game.data.roll_upper)
		AG_CURLING.game = game
	end,

	custom_intro = function()
		return AG_MESSAGES.CURLING_INTRO(AG_CURLING.game.data.gold_amount, AG_CURLING.game.target_roll)
	end,
			
	roll_to_score = function(roll)
		return math.abs(AG_CURLING.game.target_roll - tonumber(roll))
	end,
	
	fmt_score = function(roll) return roll end,
	
	sort_rolls =  function(scores, playera, playerb) 
		local scoreA = AG_CURLING.roll_to_score(scores[playera])
		local scoreB = AG_CURLING.roll_to_score(scores[playerb])
		-- Sort from Highest to Lowest
		return scoreB > scoreA
	end,
	
	payout = function(game)
		-- losing_roll is already the loser's distance from the target (see roll_to_score).
		-- Their entry in player_rolls can be gone or -1 after a tiebreaker or a roll timeout
		game.data.cash_winnings = game.data.losing_roll
		AztecGambling:MessageChat(AG_MESSAGES.CURLING_BULLSEYE(AG_CURLING.game.target_roll))
		AztecGambling:MessageChat(AG_MESSAGES.CURLING_AWAY(game.data.loser, game.data.cash_winnings))
	end,
}

-- Countdown (1v1 Roll War)
-- ==========================
-- Two players roll from the bet amount downward - each roll becomes the
-- upper bound for the next roll - whoever rolls a 1 loses the bet.
AG_COUNTDOWN = {
	label = "Countdown",
	turn_based = true,
	max_players = 2,

	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = AG_MAX_ROLL(game.data.gold_amount)
		game.data.roll_range = "(1-"..game.data.roll_upper..")"
	end,

	custom_intro = function()
		return AG_MESSAGES.COUNTDOWN_INTRO
	end,

	fmt_score = function(roll) return roll end,

	payout = function(game)
		game.data.cash_winnings = game.data.gold_amount
	end,
}

-- Blackjack (21)
-- ==================
-- Single roll represents your final hand total. Get as close to 21 as
-- possible - going over 21 is a BUST and an automatic last place, while
-- rolling exactly 21 is a natural Blackjack and the best possible hand.
local function ScoreBlackjack(roll)
	roll = tonumber(roll)
	if (roll > 21) then
		return -1 -- Bust! Ties with every other bust for last place
	else
		return roll -- Closer to 21 is better, 21 itself is the best hand
	end
end

local function FormatBlackjack(roll)
	roll = tonumber(roll)
	if (roll > 21) then
		return roll.." - BUST!"
	elseif (roll == 21) then
		return roll.." - BLACKJACK!"
	else
		return roll
	end
end

AG_BLACKJACK = {
	label = "Blackjack",

	-- Enables the hit-or-stand flow in AztecGambling.lua: after the deal,
	-- players can chat "hit" to draw again (roll hit_range) or "stand" to lock
	-- in their total, instead of being stuck with a single roll.
	hit_stand = true,
	hit_lower = 1,
	hit_upper = 10,
	hit_range = "(1-10)",

	init_game = function(game)
		game.data.roll_lower = 1
		game.data.roll_upper = 21
		game.data.roll_range = "(1-21)"
	end,

	custom_intro = function()
		return AG_MESSAGES.BLACKJACK_INTRO
	end,

	roll_to_score = function(roll)
		return ScoreBlackjack(roll)
	end,

	fmt_score = function(roll)
		return FormatBlackjack(roll)
	end,

	sort_rolls = function(scores, playera, playerb)
		return ScoreBlackjack(scores[playerb]) < ScoreBlackjack(scores[playera])
	end,

	payout = function(game)
		game.data.cash_winnings = game.data.gold_amount
	end,
}
