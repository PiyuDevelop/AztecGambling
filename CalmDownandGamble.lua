
CalmDownandGamble = LibStub("AceAddon-3.0"):NewAddon("CalmDownandGamble", "AceConsole-3.0", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "AceSerializer-3.0")
local CalmDownandGamble	= LibStub("AceAddon-3.0"):GetAddon("CalmDownandGamble")
local AceGUI = LibStub("AceGUI-3.0")


-- Initializer 
-- =============
function CalmDownandGamble:OnInitialize()
	self:PrintDebug("On Initialize")

	-- Member Initializers
	local defaults = {
	    global = {
			rankings = { },
			ban_list = { },
			chat_index = 1,
			game_mode_index = 1, 
			game_stage_index = 1,
			window_shown = false,
			ui_frame = nil, 
			custom_channel = {
				index = nil,
				name = "",
			}, 
			minimap = {
				hide = false,
			}
		}
	}
    self.db = LibStub("AceDB-3.0"):New("CalmDownandGambleDB", defaults)
	
	self.game = {
		mode_id = self.db.global.game_mode_index,
		mode = {}, 
		stage_id = 1, 
		stage = {}
	}
	
	self.previous_gameData = nil
	self.last_payout = nil

	-- If we're going to dynamically add private channels, we need to ensure we dont start with them
	self.chat = {
		channel_id = self.db.global.chat_index,
		channel = {},
		CHANNEL_CONSTS = { 
			{ label = "Raid"  ,   const = "RAID"  ,  addon_const = "RAID",  callback = "CHAT_MSG_RAID"  ,  callback_leader = "CHAT_MSG_RAID_LEADER"  }, -- Index 1
			{ label = "Party" ,   const = "PARTY" ,  addon_const = "PARTY", callback = "CHAT_MSG_PARTY" ,  callback_leader = "CHAT_MSG_PARTY_LEADER" }, -- Index 2
			{ label = "Guild" ,   const = "GUILD" ,  addon_const = "GUILD", callback = "CHAT_MSG_GUILD"     },                     -- Index 3
			{ label = "Say"   ,   const = "SAY"   ,  addon_const = "GUILD", callback = "CHAT_MSG_SAY"       },                     -- Index 4
    		{ label = "CDG", const = "CHANNEL", addon_const = "CHANNEL", callback = "CHAT_MSG_CHANNEL" },                     -- Index 5
		}
	}	

	-- AceGUI Table Constructor
	self:ConstructUI()

	-- Register with the minimap icon frame
	self:ConstructMiniMapIcon()

	-- Register the slash commands
	self:RegisterSlashCommands()

	-- Initialize Game States	
	self:SetChatChannel()
	self:SetGameMode()
	self:SetGameStage()
	
	self:PrintDebug("Load Complete!")
end

-- Chat Channels
-- =================
function CalmDownandGamble:SetChatChannel()
	self.chat.channel = self.chat.CHANNEL_CONSTS[self.chat.channel_id]
	self.chat.num_channels = table.getn(self.chat.CHANNEL_CONSTS)

	-- Only offer Say, Party and Raid in the dropdown, in that order - Guild and
	-- CDG stay fully usable internally, they're just not shown as a choice here
	local visible_labels = { "Say", "Party", "Raid" }
	local channel_list, channel_order = {}, {}
	for _, label in ipairs(visible_labels) do
		for index, channel in ipairs(self.chat.CHANNEL_CONSTS) do
			if (channel.label == label) then
				channel_list[index] = label
				table.insert(channel_order, index)
				break
			end
		end
	end
	self.ui.chat_channel:SetList(channel_list, channel_order)
	self.ui.chat_channel:SetValue(self.chat.channel_id)

	self:PrintDebug(self.chat.channel.label)
end

function CalmDownandGamble:SelectChatChannel(channel_id)
	self.chat.channel_id = channel_id
	self.db.global.chat_index = channel_id
	self:SetChatChannel()
end

function CalmDownandGamble:MessageChat(msg)
	SendChatMessage(msg, self.chat.channel.const, nil, self.db.global.custom_channel.index)
end

function CalmDownandGamble:MessageAddon(event, msg)
	self:SendCommMessage(event, msg, self.chat.channel.addon_const, tostring(self.db.global.custom_channel.index))
end

function CalmDownandGamble:RegisterChatEvents()
	self:RegisterEvent("CHAT_MSG_SYSTEM", function(...) self:RollCallback(...) end)
	self:RegisterEvent(self.chat.channel.callback, function(...) self:ChatChannelCallback(...) end)
	if (self.chat.channel.callback_leader) then
		self:RegisterEvent(self.chat.channel.callback_leader, function(...) self:ChatChannelCallback(...) end)
	end
end

function CalmDownandGamble:UnregisterChatEvents()
	self:CancelAllTimers()
	self:UnregisterEvent("CHAT_MSG_SYSTEM")
	self:UnregisterEvent(self.chat.channel.callback)
	if (self.chat.channel.callback_leader) then
		self:UnregisterEvent(self.chat.channel.callback_leader)
	end
end

-- Game Modes
-- ================
function CalmDownandGamble:SetGameMode()
	-- Loaded from external File
	GAME_MODES = { CDG_HILO, CDG_INVERSE, CDG_BIGTWOS, CDG_LILONES, CDG_YAHTZEE, CDG_CURLING, CDG_COUNTDOWN, CDG_BLACKJACK }
	self.game.mode = GAME_MODES[self.game.mode_id]
	self.game.num_modes = table.getn(GAME_MODES)

	-- Populate the dropdown with every mode's label, in GAME_MODES order
	local mode_labels, mode_order = {}, {}
	for index = 1, self.game.num_modes do
		mode_labels[index] = GAME_MODES[index].label
		mode_order[index] = index
	end
	self.ui.game_mode:SetList(mode_labels, mode_order)
	self.ui.game_mode:SetValue(self.game.mode_id)
end


function CalmDownandGamble:SelectGameMode(mode_id)
	self.game.mode_id = mode_id
	self.db.global.game_mode_index = mode_id
	self:SetGameMode()
end


-- Game Stages
-- =====================
function CalmDownandGamble:SetGameStage() 
	GAME_STAGES = {
			{ label = "NewGame",  callback = function() self:StartGame() end }, -- Index 1
			{ label = "LastCall",   callback = function() self:LastCall() end }, -- Index 2
			{ label = "StartRoll", callback = function() self:StartRolls() end }, -- Index 3
			{ label = "Status", callback = function() self:RollStatus() end }, -- Index 4
	}	
	
	self.game.stage = GAME_STAGES[self.game.stage_id]
	self.game.num_stages = table.getn(GAME_STAGES)
	self.ui.game_stage:SetText(self.game.stage.label)
	
	self:PrintDebug(self.game.stage.label)
end

function CalmDownandGamble:ResetGameStage()
	self.game.stage_id = 1
	self:SetGameStage()
end


function CalmDownandGamble:ToggleGameStage()
	self.game.stage.callback()
	if self.game.stage_id < self.game.num_stages then 
		self.game.stage_id = self.game.stage_id + 1 
		self:SetGameStage()
	end
end

-- Stage Callbacks
-- (stage_id = 1) Game will always start here in start game
function CalmDownandGamble:StartGame()
	-- Reset & Init Current GAME
	self.game.data = {
		accepting_players = true,
		accepting_rolls = false,
		high_tiebreaker = false,
		low_tiebreaker = false,
		winner = nil,
		loser = nil,
		winning_roll = nil,
		losing_roll = nil,
		high_roller_playoff = {},
		low_roller_playoff = {},
		player_rolls = {},
		turn_order = {},
		turn_player = nil,
		determining_starter = false,
		dealt = false,
		blackjack_active = {},
		awaiting_hit = {}
	}
	self.previous_gameData = self.game.data
	self:SetGoldAmount()
	self:RegisterChatEvents()
	self.game.mode.init_game(self.game)
	self:PrintDebug("Initialized Current GAME")

	-- In case of custom channel, we need to let the guild know! 
	if ((self.chat.channel.const == "CHANNEL") and (self.db.global.custom_channel.index == nil)) then 
		self:JoinCustomChannel(nil)
		SendChatMessage("Just started a Gambling Round in a custom channel! To join in use /cdg joinChat or /join "..self.db.global.custom_channel.name, "GUILD")
	end

	-- Welcome Message!
	local welcome_msg = "CDG is now in session! Mode: "..self.game.mode.label..", Bet: "..self.game.data.gold_amount.." gold"
	self:MessageChat(welcome_msg)
	if (self.game.mode.custom_intro ~= nil) then self:MessageChat(self.game.mode.custom_intro()) end
	self:MessageChat("Press 1 to Join!")

	-- TODO: Why is this BS different?
	if (self.chat.channel.const == "CHANNEL") then 
		self:MessageChat("Tell your friends to join the channel by /cdg join or /join "..self.db.global.custom_channel.name) 
	end
	
	-- Notify Clients of New GAME
	local start_args = self.game.data.roll_lower.." "..self.game.data.roll_upper.." "..self.game.data.gold_amount.." "..self.chat.channel.const
	self:MessageAddon("CDG_NEW_GAME", start_args)
	self:PrintDebug(start_args)
end

-- (stage_id = 2) Count Down to Game Start
function CalmDownandGamble:LastCall()
	self:MessageChat("Last call! 10 seconds left!")
	self:ScheduleTimer("TimedStart", 10)
end

-- (stage_id = 3) After accepting entries via chat callbacks, start the rolls
function CalmDownandGamble:StartRolls()
	-- Cancel the countdown to start if its there
	self:CancelAllTimers()

	-- Turn-based modes (ex: Countdown) run their own start sequence
	if self.game.mode.turn_based then
		self:StartCountdownTurn()
		return
	end

	-- Hit-or-stand modes (ex: Blackjack) need a fresh deal range and hand
	-- state each time rolls start, including tiebreaker redeals
	if self.game.mode.hit_stand then
		self.game.data.dealt = false
		self.game.data.blackjack_active = {}
		self.game.data.awaiting_hit = {}
		self.game.mode.init_game(self.game)
	end

	-- Make sure we have enough players
	self:PrintDebug(self:TableLength(self.game.data.player_rolls))
	if (self:TableLength(self.game.data.player_rolls) <= 1) then
		self:MessageChat("Can't start a game with less than 2 players")
		self.game.stage_id = self.game.stage_id - 1
		self:SetGameStage()
		return 
	end

	-- Allow roll callbacks
	self.game.data.accepting_rolls = true
	self.game.data.accepting_players = false
	
	-- Tell Tiebreakers Who Has to Roll
	local roll_msg = ""
	if self.game.data.high_tiebreaker then 
		self:MessageChat("The Winners Bracket! High Tiebreaker:")
		self:PrintTieBreakerPlayers(self.game.data.player_rolls)
	elseif self.game.data.low_tiebreaker then 
		self:MessageChat("The Losers! Low Tiebreaker:")
		self:PrintTieBreakerPlayers(self.game.data.player_rolls)
	end
	
	-- Off to the races!
	self:MessageChat(roll_msg)
	self:MessageChat("Time to roll! Good Luck! Command:   /roll "..self.game.data.roll_range)
end

-- (Countdown) Kick off a turn-based game: settle who goes first with a 1-100 roll-off
function CalmDownandGamble:StartCountdownTurn()
	local required = self.game.mode.max_players or 2

	if (self:TableLength(self.game.data.player_rolls) ~= required) then
		self:MessageChat("Countdown needs exactly "..required.." players.")
		self.game.stage_id = self.game.stage_id - 1
		self:SetGameStage()
		return
	end

	self.game.data.accepting_rolls = true
	self.game.data.accepting_players = false
	self:StartCountdownStarterRoll()
end

-- (Countdown) Roll-off to decide who goes first - ties reroll
function CalmDownandGamble:StartCountdownStarterRoll()
	self.game.data.determining_starter = true
	self.game.data.roll_range = "(1-100)"
	self.game.data.player_rolls[self.game.data.turn_order[1]] = -1
	self.game.data.player_rolls[self.game.data.turn_order[2]] = -1

	self:MessageChat("Roll 1-100 to see who goes first! Command:   /roll (1-100)")
	self:MessageAddon("CDG_TURN_UPDATE", "RollOff 1 100")
	self:UpdateRollStatusUI()
end

-- (Countdown) Handle one player's roll-off roll; once both are in, higher starts (tie = reroll)
function CalmDownandGamble:CountdownStarterRollCallback(player, roll, roll_range)
	if (roll_range ~= self.game.data.roll_range) then return end
	if (self.game.data.player_rolls[player] ~= -1) then return end

	self.game.data.player_rolls[player] = tonumber(roll)
	self:UpdateRollStatusUI()

	local p1, p2 = self.game.data.turn_order[1], self.game.data.turn_order[2]
	if (self.game.data.player_rolls[p1] == -1) or (self.game.data.player_rolls[p2] == -1) then
		return -- still waiting on the other player
	end

	if (self.game.data.player_rolls[p1] == self.game.data.player_rolls[p2]) then
		self:MessageChat("Tie! Roll again to see who goes first.")
		self:StartCountdownStarterRoll()
		return
	end

	local starter = (self.game.data.player_rolls[p1] > self.game.data.player_rolls[p2]) and p1 or p2
	self.game.data.determining_starter = false
	self.game.mode.init_game(self.game) -- restore the real bet range after the roll-off
	self.game.data.player_rolls[p1] = -1
	self.game.data.player_rolls[p2] = -1
	self.game.data.turn_player = starter

	self:MessageChat(starter.." rolled higher and goes first! Command:   /roll "..self.game.data.roll_range)
	self:MessageAddon("CDG_TURN_UPDATE", starter.." "..self.game.data.roll_lower.." "..self.game.data.roll_upper)
end

-- (Countdown) Handle one player's roll, pass the turn, or end the game on a 1
function CalmDownandGamble:CountdownRollCallback(player, roll, roll_range)
	if (not self.game.data.accepting_rolls) then return end
	if (player ~= self.game.data.turn_player) then return end
	if (roll_range ~= self.game.data.roll_range) then return end

	roll = tonumber(roll)
	self.game.data.player_rolls[player] = roll

	local opponent = (player == self.game.data.turn_order[1]) and self.game.data.turn_order[2] or self.game.data.turn_order[1]

	if (roll == 1) then
		self.game.data.accepting_rolls = false
		self.game.data.loser = player
		self.game.data.winner = opponent
		self.game.data.winning_roll = self.game.data.player_rolls[opponent]
		self.game.data.losing_roll = roll
		self:UpdateRollStatusUI()
		self:FinishGame()
		return
	end

	self.game.data.roll_upper = roll
	self.game.data.roll_range = "(1-"..roll..")"
	self.game.data.turn_player = opponent
	self.game.data.player_rolls[opponent] = -1

	self:UpdateRollStatusUI()
	self:MessageChat(opponent.."'s turn! Command:   /roll "..self.game.data.roll_range)
	self:MessageAddon("CDG_TURN_UPDATE", opponent.." "..self.game.data.roll_lower.." "..self.game.data.roll_upper)
end

function CalmDownandGamble:PrintTieBreakerPlayers(players)
	tiebreaker_list = ""
	for player, roll in pairs(players) do
		-- TODO - Figure out how to use this for Yahtzee self.game.mode.fmt_score(roll)
		tiebreaker_list = tiebreaker_list..player.." vs "
	end
	tiebreaker_list = tiebreaker_list:sub(1, -5)
	self:MessageChat(tiebreaker_list)
end

-- (stage_id =4) Poll for Roll Status
function CalmDownandGamble:RollStatus()
	self:CheckRollsComplete(true)
end

function CalmDownandGamble:CheckRollsComplete(print_players)

	local rolls_complete = true

	self:PrintDebug("CheckRollsComplete() Called")

	-- Once Blackjack is past the deal, completion is tracked via
	-- blackjack_active/CheckBlackjackHandsComplete, not raw rolls
	if self.game.mode.hit_stand and self.game.data.dealt then
		if print_players then
			for player, active in pairs(self.game.data.blackjack_active) do
				if active then
					self:MessageChat("Player: "..player.." still needs to hit or stand")
				end
			end
		end
		return
	end

	for player, roll in pairs(self.game.data.player_rolls) do
		if (roll == -1) then
			rolls_complete = false
			if print_players then
				self:MessageChat("Player: "..player.." still needs to roll") 
			end
		end
	end
	
	if (rolls_complete) then
		self.game.accepting_rolls = false
		if self.game.mode.hit_stand and (not self.game.data.dealt) then
			self:StartBlackjackHitPhase()
		else
			self:GameLoop()
		end
	end

end

-- (Blackjack) Deal is complete - flag naturals, then let players hit or stand
function CalmDownandGamble:StartBlackjackHitPhase()
	self.game.data.dealt = true
	self.game.data.roll_lower = self.game.mode.hit_lower
	self.game.data.roll_upper = self.game.mode.hit_upper
	self.game.data.roll_range = self.game.mode.hit_range

	for player, total in pairs(self.game.data.player_rolls) do
		if (tonumber(total) == 21) then
			self.game.data.blackjack_active[player] = false
			self:MessageChat(player.." has a natural BLACKJACK!")
		else
			self.game.data.blackjack_active[player] = true
		end
	end

	self:MessageChat("Dealt! Type 'hit' to draw another card or 'stand' to lock in your total.")
	self:UpdateRollStatusUI()
	self:CheckBlackjackHandsComplete()
end

-- (Blackjack) Once every player has stood or busted, hand off to scoring
function CalmDownandGamble:CheckBlackjackHandsComplete()
	for player, active in pairs(self.game.data.blackjack_active) do
		if active then return end
	end
	self:GameLoop()
end

function CalmDownandGamble:FinishGame()
	self.game.mode.payout(self.game)
	local payout_msg = self.game.data.loser.." owes "..self.game.data.winner.." "..self.game.data.cash_winnings.." gold!"
	self.last_payout = payout_msg
	self:MessageChat(payout_msg)
	self:LogResults()
	self:EndGame()
end

-- Re-announce the last payout, in case people missed it or started a new round before paying up
function CalmDownandGamble:RepeatLastPayout()
	if (self.last_payout == nil) then
		self:MessageChat("No payout to repeat yet!")
		return
	end
	self:MessageChat(self.last_payout)
end

function CalmDownandGamble:GameLoop()
	if (CalmDownandGamble:EvaluateScores()) then
		self:FinishGame()
	end
end


function CalmDownandGamble:EndGame()
	-- Tell  the clients and UI were done
	local end_args = self.game.data.winner.." "..self.game.data.loser.." "..self.game.data.cash_winnings
	self:MessageAddon("CDG_END_GAME", end_args)
	self.ui.CDG_Frame:SetStatusText(self.game.data.cash_winnings.."g  "..self.game.data.loser.." => "..self.game.data.winner)
	
	-- Clear the Roll Status UI
	self.ui.CDG_RollFrame:ReleaseChildren()
	self.ui.CDG_RollFrame:Release()
	self.ui.CDG_RollFrame = nil

	-- Reset Game Hooks and Data
	self:UnregisterChatEvents()
	self:ResetGameStage()
	self.previous_gameData = self:deepcopy(self.game.data)
	self.game.data = nil
end


function CalmDownandGamble:ResetGame()
	self:UnregisterChatEvents()
	self.game.data = nil
	self:ResetGameStage()
	self:MessageChat("Game has been reset.")
end

-- Utils
-- ========
function CalmDownandGamble:GameResultsCallback(...)
	local callback = select(1, ...)
	local message = select(2, ...)
	local chat = select(3, ...)
	local sender = select(4, ...)

	-- Parse the message
	message = self:SplitString(message, "%S+")	
    winner = message[1]
	loser = message[2]
    cash_winnings = message[3]
	
	-- Don't record what we're sending out
	local name, realm = UnitName("player")
	if (sender == name) then
		return
	end
	
	-- Log results
	if (self.db.global.rankings[winner] ~= nil) then
		self.db.global.rankings[winner] = self.db.global.rankings[winner] + cash_winnings
	else
		self.db.global.rankings[winner] = (1*cash_winnings)
	end
	
	if (self.db.global.rankings[loser] ~= nil) then
		self.db.global.rankings[loser] = self.db.global.rankings[loser] - cash_winnings
	else
		self.db.global.rankings[loser] = (-1*cash_winnings)
	end
end

function CalmDownandGamble:LogResults() 
	self:PrintDebug("Winner: "..self.game.data.winner)
	self:PrintDebug("Loser: "..self.game.data.loser)
	self:PrintDebug("CASH: "..self.game.data.cash_winnings)
	
	if (self.db.global.rankings[self.game.data.winner] ~= nil) then
		self.db.global.rankings[self.game.data.winner] = self.db.global.rankings[self.game.data.winner] + self.game.data.cash_winnings
	else
		self.db.global.rankings[self.game.data.winner] = (1*self.game.data.cash_winnings)
	end
	
	if (self.db.global.rankings[self.game.data.loser] ~= nil) then
		self.db.global.rankings[self.game.data.loser] = self.db.global.rankings[self.game.data.loser] - self.game.data.cash_winnings
	else
		self.db.global.rankings[self.game.data.loser] = (-1*self.game.data.cash_winnings)
	end
end

function CalmDownandGamble:SetGoldAmount() 

	local text_box = self.ui.gold_amount_entry:GetText()
	local text_box_valid = (not string.match(text_box, "[^%d]")) and (text_box ~= '')
	if ( text_box_valid ) then
		self.game.data.gold_amount = text_box
	else
		self.game.data.gold_amount = 100
	end

end

-- SCORING FUNCTION
-- ===================
-- Sorts the rolls base on the game mode sorting function
-- The game mode sorting fucntion accepts rolls and returns a sorted table
-- based on scores where the winner is always first, and the loser last
function CalmDownandGamble:EvaluateScores()
	self:PrintDebug("Evaluating Scores")
	
	local winning_roll, losing_roll, high_roller_playoff, low_roller_playoff = nil, nil, {}, {}
	local winner, loser = nil, nil
	
    -- Loop over the players and look for highest/lowest/etc
	local roll_index, total_rolls = 0, table.getn(self.game.data.player_rolls)
	for player, roll in self:sortedpairs(self.game.data.player_rolls, self.game.mode.sort_rolls) do
		
		-- Loop Incrementer
		roll_index = roll_index + 1
		player_score = self.game.mode.roll_to_score(roll)
		self:PrintDebug("    "..player.." "..player_score)
		
		-- Roll Index == 1 -> Winner 
		if (roll_index == 1) then 
			winning_roll = player_score
			high_roller_playoff[player] = -1
			winner = player
		
		-- Score == Winner -> Tiebreaker
		elseif (player_score == winning_roll) then
			high_roller_playoff[player] = -1
		
		-- Score != Winner -> First Loser
		elseif (losing_roll == nil) then      
			losing_roll = player_score
			low_roller_playoff[player] = -1
			loser = player
			
		-- Score != Loser and Index != End -> New Loser
		elseif (player_score ~= losing_roll) then   
			low_roller_playoff = {}
			losing_roll = player_score
			low_roller_playoff[player] = -1
			loser = player
		
		-- Score == Loser -> Tiebreaker
		elseif (player_score == losing_roll)  then  -- also the worst
			low_roller_playoff[player] = -1
		
		else
		end
		
		
	end

	-- Save the actual high and low for payouts
	if self.game.data.winning_roll == nil then	
		self.game.data.winning_roll = winning_roll	
	end	
	if self.game.data.losing_roll == nil then	
		self.game.data.losing_roll = losing_roll	
	end	

	
	-- Determine Tiebreaker State
	local high_roller_count = self:TableLength(high_roller_playoff)
	local low_roller_count = self:TableLength(low_roller_playoff)
	local found_winner = (high_roller_count == 1) 
	local found_loser = (low_roller_count == 1) 
	
	-- Set the payout values before we tiebreak
	if self.game.data.winning_roll == nil then
		self.game.data.winning_roll = winning_roll
	end
	if self.game.data.losing_roll == nil then
		self.game.data.losing_roll = losing_roll
	end

	-- High Tiebreaker -- 
	if self.game.data.high_tiebreaker then 
		if found_winner then 
			self.game.data.winner = winner
			self.game.data.high_tiebreaker = false
			self.game.data.high_roller_playoff = {}
		else
			self.game.data.player_rolls = self:CopyTable(high_roller_playoff)
			self.game.data.high_tiebreaker = true
			self:StartRolls()
			self:PrintDebug("High Tie Breaker #2")
			return false
		end
	-- Low Tiebreaker -- 
	elseif self.game.data.low_tiebreaker then 

		
		-- if total_players == high_rollers
		if (high_roller_count == self:TableLength(self.game.data.player_rolls)) then
			
		end
	
		if found_loser then 
			self.game.data.loser = loser
			self.game.data.low_tiebreaker = false
			self.game.data.low_roller_playoff = {}
		elseif (high_roller_count == self:TableLength(self.game.data.player_rolls)) then
		-- all low tied again? will show up in "high_roller_playoff"
			self.game.data.player_rolls = self:CopyTable(high_roller_playoff)
			self.game.data.low_tiebreaker = true
			self:StartRolls()
			self:PrintDebug("Low Tiebreaker #4")
			return false
		else
			self.game.data.player_rolls = self:CopyTable(low_roller_playoff)
			self.game.data.low_tiebreaker = true
			self:StartRolls()
			self:PrintDebug("Low Tiebreaker #2")
			return false
		end
	-- No Tiebreaker -- 
	else
		if found_winner then 
			self.game.data.winner = winner
			self.game.data.high_tiebreaker = false
			self.game.data.high_roller_playoff = {}
		else 
			self.game.data.high_roller_playoff = self:CopyTable(high_roller_playoff)
		end
		
		if found_loser then 
			self.game.data.loser = loser
			self.game.data.low_tiebreaker = false
			self.game.data.low_roller_playoff = {}
		else
			self.game.data.low_roller_playoff = self:CopyTable(low_roller_playoff)
		end

	end
	
	
	if (self:TableLength(self.game.data.low_roller_playoff) > 1) then 
		self:PrintDebug("Low Tiebreaker #1")
		-- start low tiebreaker -- 
		self.game.data.low_tiebreaker = true
		self.game.data.player_rolls = self:CopyTable(self.game.data.low_roller_playoff)
		self:StartRolls()
		return false
	elseif (self:TableLength(self.game.data.high_roller_playoff) > 1) then 
		self:PrintDebug("High Tiebreaker #1")
		self.game.data.high_tiebreaker = true
		self.game.data.player_rolls = self:CopyTable(self.game.data.high_roller_playoff)
		self:StartRolls()
		return false
	elseif (self.game.data.loser == nil) and (not found_loser) then  -- special case, everyone was a high roller
		self:PrintDebug("Low Tiebreaker #3")
		self.game.data.low_tiebreaker = true
		self.game.data.player_rolls = self:CopyTable(low_roller_playoff)
		self:StartRolls()
		return false
	elseif (self.game.data.loser == nil) and found_loser then  -- special case, everyone was a high roller, 1v1
		self.game.data.loser = loser
		return true
	else
		return true
	end
		
end

-- ChatFrame Interaction Callbacks (Entry and Rolls)
-- ==================================================== 

function CalmDownandGamble:UpdateRollStatusUI()
	if ((self.ui ~= nil) and (self.game.data ~= nil)) then

		if (self.ui.CDG_RollFrame == nil) then

			-- Create the Rolling Frame and attach it to the casino frame
			-- *THIS IS STUPID DO IT IN XML TODODODODO*TODO -- 
			self.ui.CDG_RollFrame = AceGUI:Create("Frame")
			self.ui.CDG_RollFrame:SetWidth(200)
			self.ui.CDG_RollFrame:SetHeight(self.ui.CDG_Frame.frame:GetHeight() * 2)
			self.ui.CDG_RollFrame:ClearAllPoints()
			self.ui.CDG_RollFrame:SetPoint("BOTTOMLEFT", self.ui.CDG_Frame.frame, "BOTTOMRIGHT", 0, 0)
			self.ui.CDG_RollFrame:SetTitle("Roll Status")
			

			-- Boiler plat code for a container object
			self.ui.CDG_RollFrameScrollcontainer = AceGUI:Create("SimpleGroup") 
			self.ui.CDG_RollFrameScrollcontainer:SetFullWidth(true)
			self.ui.CDG_RollFrameScrollcontainer:SetHeight(self.ui.CDG_RollFrame.frame:GetHeight() - 75)
			self.ui.CDG_RollFrameScrollcontainer:SetLayout("Fill") 
			self.ui.CDG_RollFrame:AddChild(self.ui.CDG_RollFrameScrollcontainer)

			-- Attach a scrollbar to the container 
			self.ui.CDG_RollFrameScroll = AceGUI:Create("ScrollFrame")
			self.ui.CDG_RollFrameScroll:SetLayout("Flow") 
			self.ui.CDG_RollFrameScrollcontainer:AddChild(self.ui.CDG_RollFrameScroll)

		end

		-- Refresh the list of players and their rolls
		self.ui.CDG_RollFrameScroll:ReleaseChildren()	
		for player, roll in self:sortedpairs(self.game.data.player_rolls, self.game.mode.sort_rolls) do

			label = AceGUI:Create("Label")
			if (roll ~= tonumber(-1)) then 
				label:SetText(roll.." : "..player)
			else 
				label:SetText(" - : "..player)
			end
			label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE, MONOCHROME")
			label:SetColor(255, 255, 0)
			self.ui.CDG_RollFrameScroll:AddChild(label)
		end
	
	end
end


function CalmDownandGamble:RollCallback(...)
	if (self.game.data == nil) then return end

	-- Parse the input Args 
	local channel = select(1, ...)
	local roll_text = select(2, ...)
	local message = self:SplitString(roll_text, "%S+")
	local player, roll, roll_range = message[1], message[3], message[4]
	if (roll_range == nil) then return end  -- If rollrange is nil its not a roll

	if self.game.mode.turn_based then
		if self.game.data.determining_starter then
			self:CountdownStarterRollCallback(player, roll, roll_range)
		else
			self:CountdownRollCallback(player, roll, roll_range)
		end
		return
	end

	-- (Blackjack) Apply a "hit" roll to the player's running total
	if self.game.mode.hit_stand and self.game.data.dealt then
		if (roll_range == self.game.data.roll_range) and self.game.data.awaiting_hit[player] then
			self.game.data.awaiting_hit[player] = nil
			local new_total = tonumber(self.game.data.player_rolls[player]) + tonumber(roll)
			self.game.data.player_rolls[player] = new_total

			if (new_total > 21) then
				self.game.data.blackjack_active[player] = false
				self:MessageChat(player.." drew a "..roll.." for "..new_total.." - BUST!")
			elseif (new_total == 21) then
				self.game.data.blackjack_active[player] = false
				self:MessageChat(player.." drew a "..roll.." for 21 - BLACKJACK!")
			else
				self:MessageChat(player.." drew a "..roll.." for "..new_total..". Hit or stand?")
			end

			self:UpdateRollStatusUI()
			self:CheckBlackjackHandsComplete()
		end
		return
	end

	self:PrintDebug("Checking Roll for Range: "..self.game.data.roll_range)
	self:PrintDebug("Player: "..player.." Roll: "..roll)
	-- Check that the roll is valid ( also that the message is for us)
	local valid_roll = (self.game.data.roll_range == roll_range) and self.game.data.accepting_rolls

	if valid_roll then 
		if (self.game.data.player_rolls[player] == -1) then
			self:PrintDebug("Player: "..player.." Roll: "..roll.." RollRange: "..roll_range)

			-- Update Game State Data 
			-- TODO: Only in NONGROUP channels if channel == "CDG_ROLL_DICE" then SendSystemMessage(roll_text) end
			self.game.data.player_rolls[player] = tonumber(roll)

			-- Update the UI and Check for the game end 
			self:UpdateRollStatusUI()			
			self:CheckRollsComplete(false)
		end
	end
	
end

function CalmDownandGamble:ChatChannelCallback(...)
	if (self.game.data == nil) then return end

	local message = select(2, ...)
	local sender = select(3, ...)
	
	message = message:gsub("%s+", "") -- trim whitespace
	sender = Ambiguate(sender, "short")

	-- (Blackjack) Let active players choose to hit or stand via chat
	if self.game.mode.hit_stand and self.game.data.dealt and self.game.data.blackjack_active[sender] then
		local choice = string.lower(message)

		if (choice == "hit") then
			self.game.data.awaiting_hit[sender] = true
			self:MessageChat(sender.." hits! Command:   /roll "..self.game.data.roll_range)
			self:MessageAddon("CDG_TURN_UPDATE", sender.." "..self.game.data.roll_lower.." "..self.game.data.roll_upper)
			return
		elseif (choice == "stand") then
			self.game.data.blackjack_active[sender] = false
			self.game.data.awaiting_hit[sender] = nil
			self:MessageChat(sender.." stands with "..self.game.data.player_rolls[sender].."!")
			self:UpdateRollStatusUI()
			self:CheckBlackjackHandsComplete()
			return
		end
	end

	local max_players = self.game.mode.max_players
	local under_cap = (max_players == nil) or (self:TableLength(self.game.data.player_rolls) < max_players)

	local player_join = (
		(self.game.data.player_rolls[sender] == nil)
		and (self.game.data.accepting_players)
		and (message == "1")
        and (not self.db.global.ban_list[sender])
		and under_cap
	)

	if (player_join) then
		self.game.data.player_rolls[sender] = -1
		table.insert(self.game.data.turn_order, sender)
		self:PrintDebug(sender.." joined the game")
	end

end

-- Button Interaction Callbacks (State and Settings)
-- ==================================================== 
function CalmDownandGamble:PrintBanlist()
	self:MessageChat("Hall of GTFO:")
	for player, _ in pairs(self.db.global.ban_list) do
		self:MessageChat(player)
    end
end

function CalmDownandGamble:PrintRanklist()

	self:MessageChat("Hall of Fame: ")
	local index = 1
	local sort_descending = function(t,a,b) return t[b] < t[a] end
	for player, gold in self:sortedpairs(self.db.global.rankings, sort_descending) do
		if gold <= 0 then break end
		
		local msg = string.format("%d. %s won %d gold.", index, player, gold)
		self:MessageChat(msg)
		index = index + 1
	end
	
	self:MessageChat("~~~~~~")
	
	self:MessageChat("Hall of Shame: ")
	index = 1
	local sort_ascending = function(t,a,b) return t[b] > t[a] end
	for player, gold in self:sortedpairs(self.db.global.rankings, sort_ascending) do
		if gold >= 0 then break end
	
		local msg = string.format("%d. %s lost %d gold.", index, player, math.abs(gold))
		self:MessageChat(msg)
		index = index + 1
	end
	
end

function CalmDownandGamble:RollForMe()
	if self.game.data == nil then 
		SendSystemMessage("You need an active game for me to roll for you!")
		return
	end
	RandomRoll(self.game.data.roll_lower, self.game.data.roll_upper)
end

function CalmDownandGamble:EnterForMe()
	self:MessageChat("1")
end

function CalmDownandGamble:TimedStart() 
	if (self.game.data ~= nil) then
		if not self.game.data.accepting_rolls then 
			self.game.stage_id = 4 -- 4 is the final stage
			self:SetGameStage()
			self:StartRolls()
		end
	end
end

-- NEEDS TO BE COMMON WITH CDGCLIENT! TODO!
function CalmDownandGamble:OpenTradeWinner()		
	if (self.game.data and self.game.data.winner) then
		if (TradeFrame:IsVisible()) then
			local copper = self.game.data.cash_winnings * 100 * 100 
			SetTradeMoney(copper)
			MoneyInputFrame_SetCopper(TradePlayerInputMoneyFrame, copper)
		else 
			InitiateTrade(self.game.data.winner)
		end
	end
end
-- UI ELEMENTS 
-- ======================================================
function CalmDownandGamble:ShowUI()
	self.ui.CDG_Frame:Show()
	self.db.global.window_shown = true
end

function CalmDownandGamble:HideUI()
	self.ui.CDG_Frame:Hide()
	self.db.global.window_shown = false
	self:SaveFrameState()
end

function CalmDownandGamble:SaveFrameState()
	self.db.global.ui_frame = self:CopyTable(self.ui.CDG_Frame.status)
end

function CalmDownandGamble:ConstructUI()

	-- Settings to be used --
	local cdg_ui_elements = {
		-- Main Box Frame --
		main_frame = {
			width = 400,
			height = 190
		},

		-- Each row is built with the AceGUI "Table" layout: a {weight=1} spacer
		-- column on either side auto-centers the fixed-width controls between
		-- them, same idea as flex-grow - no more manual invisible padding buttons
		row1_index = { "enter_for_me", "roll_for_me", "open_trade" },
		row2_index = { "gold_amount_entry", "chat_channel", "game_mode" },
		row3_index = { "game_stage", "reset_game", "repeat_payout" },

		-- Button Definitions --
		buttons = {
			chat_channel = {
				width = 70
			},
			reset_game = {
				width = 70, 
				label = "Reset",
				click_callback = function() self:ResetGame() end
			},
			game_stage = {
				width = 120,
				label = "Start!",
				click_callback = function() self:ToggleGameStage() end

			},
			enter_for_me = {
				width = 100,
				label = "Enter",
				click_callback = function() self:EnterForMe() end
			},
			roll_for_me = {
				width = 100,
				label = "Roll!",
				click_callback = function() self:RollForMe() end
			},
			-- TODO : Make this common with CDGClient
			-- Disabled for now, OpenTradeWinner isn't working - use "PAY!" to re-announce the payout instead
			open_trade = {
				width = 100,
				label = "Payout",
				disabled = true,
				click_callback = function() self:OpenTradeWinner() end
			},
			repeat_payout = {
				width = 110, -- Matches game_mode's width, so row 3 lines up column-for-column with row 2
				label = "PAY!",
				click_callback = function() self:RepeatLastPayout() end
			},
			gold_amount_entry = {
				width = 120
			},
			game_mode = {
				width = 110
			}
		}
	};

	-- ui - represents the Top level of the storage hierarchy for the UI
	self.ui = {}
	
	-- CDG_Frame - Represents the window frame of the addon
	self.ui.CDG_Frame = AceGUI:Create("Frame")
	self.ui.CDG_Frame:SetTitle("Aztec Gambling")
	self.ui.CDG_Frame:SetStatusText("")
	self.ui.CDG_Frame:SetLayout("Flow")
	self.ui.CDG_Frame:SetStatusTable(cdg_ui_elements.main_frame)
	self.ui.CDG_Frame:EnableResize(false)
	self.ui.CDG_Frame:SetCallback("OnClose", function() self:HideUI() end)
	self.ui.CDG_Frame.frame:EnableMouse(true)
	self.ui.CDG_Frame.frame:SetUserPlaced(true)

	-- Mouse callbacks 
	on_mouse_down = function(w, button) 
		if (button == "RightButton") then 
			self:ToggleCasino() 
		end 
	end
	self.ui.CDG_Frame.frame:SetScript("OnMouseDown", on_mouse_down)
	
	-- BuildRow - Creates one centered row of controls using the "Table" layout.
	-- A {weight=1, alignH="fill"} spacer column on each side of the fixed-width
	-- controls soaks up the leftover space evenly, the same way flex-grow would.
	-- Every column needs an actual child occupying it (Table has no notion of a
	-- decorative empty column), so the spacers are real, invisible buttons.
	-- =====================================================
	local function BuildRow(control_names, row_width)
		local row = AceGUI:Create("SimpleGroup")
		row:SetLayout("Table")
		row:SetWidth(row_width)

		local columns = { {weight = 1, alignH = "fill"} }
		for _, name in ipairs(control_names) do
			table.insert(columns, cdg_ui_elements.buttons[name].width)
		end
		table.insert(columns, {weight = 1, alignH = "fill"})
		row:SetUserData("table", { columns = columns, space = 4 })

		local left_spacer = AceGUI:Create("Button")
		left_spacer.frame:SetAlpha(0)
		row:AddChild(left_spacer)

		for _, name in ipairs(control_names) do
			local control_settings = cdg_ui_elements.buttons[name]

			if (name == "gold_amount_entry") then
				-- gold_amount_entry - Text box for gold entry
				self.ui.gold_amount_entry = AceGUI:Create("EditBox")
				self.ui.gold_amount_entry:SetWidth(control_settings.width)
				row:AddChild(self.ui.gold_amount_entry)
			elseif (name == "game_mode") then
				-- game_mode - Dropdown select for choosing a mode directly, instead of a button that rotates them
				self.ui.game_mode = AceGUI:Create("Dropdown")
				self.ui.game_mode:SetWidth(control_settings.width)
				self.ui.game_mode:SetCallback("OnValueChanged", function(widget, event, mode_id) self:SelectGameMode(mode_id) end)
				row:AddChild(self.ui.game_mode)
			elseif (name == "chat_channel") then
				-- chat_channel - Dropdown select for choosing the chat channel directly, instead of a button that rotates them
				self.ui.chat_channel = AceGUI:Create("Dropdown")
				self.ui.chat_channel:SetWidth(control_settings.width)
				self.ui.chat_channel:SetCallback("OnValueChanged", function(widget, event, channel_id) self:SelectChatChannel(channel_id) end)
				row:AddChild(self.ui.chat_channel)
			else
				self.ui[name] = AceGUI:Create("Button")
				self.ui[name]:SetText(control_settings.label)
				self.ui[name]:SetWidth(control_settings.width)
				self.ui[name]:SetCallback("OnClick", control_settings.click_callback)
				if control_settings.disabled then
					self.ui[name]:SetDisabled(true)
				end
				row:AddChild(self.ui[name])
			end
		end

		local right_spacer = AceGUI:Create("Button")
		right_spacer.frame:SetAlpha(0)
		row:AddChild(right_spacer)

		return row
	end

	-- Row 1: Enter, Roll!, Payout
	self.ui.CDG_PlayFrame = BuildRow(cdg_ui_elements.row1_index, cdg_ui_elements.main_frame.width)
	self.ui.CDG_Frame:AddChild(self.ui.CDG_PlayFrame)

	-- CDG_CasinoGroup - Bordered, titled "Casino" box wrapping rows 2 and 3
	-- ====================================================
	self.ui.CDG_CasinoGroup = AceGUI:Create("InlineGroup")
	self.ui.CDG_CasinoGroup:SetTitle("Casino")
	self.ui.CDG_CasinoGroup:SetLayout("Flow")
	self.ui.CDG_CasinoGroup:SetWidth(cdg_ui_elements.main_frame.width)

	-- InlineGroup insets its content by 20px (10px on each side) - rows inside
	-- it need to be built to that narrower width, not the full frame width
	local casino_row_width = cdg_ui_elements.main_frame.width - 20

	-- Row 2: chat channel, gold entry, game mode, new game, reset
	self.ui.CDG_CasinoFrame = BuildRow(cdg_ui_elements.row2_index, casino_row_width)
	self.ui.CDG_CasinoGroup:AddChild(self.ui.CDG_CasinoFrame)

	-- Row 3: PAY!
	self.ui.CDG_ModeFrame = BuildRow(cdg_ui_elements.row3_index, casino_row_width)
	self.ui.CDG_CasinoGroup:AddChild(self.ui.CDG_ModeFrame)

	self.ui.CDG_Frame:AddChild(self.ui.CDG_CasinoGroup)


	
	if (self.db.global.ui_frame ~= nil) then
		-- Restore the saved position, but always keep the width/height defined above -
		-- otherwise a size saved by an older layout (fewer rows) keeps overriding it forever
		self.ui.CDG_Frame:SetStatusTable(self.db.global.ui_frame)
		self.ui.CDG_Frame:SetWidth(cdg_ui_elements.main_frame.width)
		self.ui.CDG_Frame:SetHeight(cdg_ui_elements.main_frame.height)
	end
	
	if not self.db.global.window_shown then
		self.ui.CDG_Frame:Hide()
	end
	
	-- Register for UI Events
	self:RegisterEvent("PLAYER_LEAVING_WORLD", function(...) self:SaveFrameState(...) end)
end