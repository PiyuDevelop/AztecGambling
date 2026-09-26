
AztecGambling = LibStub("AceAddon-3.0"):NewAddon("AztecGambling", "AceConsole-3.0", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "AceSerializer-3.0")
local AztecGambling	= LibStub("AceAddon-3.0"):GetAddon("AztecGambling")
local AceGUI = LibStub("AceGUI-3.0")
-- Used by the RollCountdown widget's constructor near the bottom of this file
local CreateFrame, UIParent = CreateFrame, UIParent

-- Seconds players get to roll in each roll phase, and when to warn them in chat
local ROLL_TIME_LIMIT = 45
local ROLL_WARNING_SECONDS = 10


-- Initializer 
-- =============
function AztecGambling:OnInitialize()
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
    self.db = LibStub("AceDB-3.0"):New("AztecGamblingDB", defaults)
	
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
			{ label = "Raid"  ,   const = "RAID"  	,  addon_const = "RAID"		, callback = "CHAT_MSG_RAID"  ,  callback_leader = "CHAT_MSG_RAID_LEADER"  }, -- Index 1
			{ label = "Party" ,   const = "PARTY" 	,  addon_const = "PARTY"	, callback = "CHAT_MSG_PARTY" ,  callback_leader = "CHAT_MSG_PARTY_LEADER" }, -- Index 2
			{ label = "Guild" ,   const = "GUILD" 	,  addon_const = "GUILD"	, callback = "CHAT_MSG_GUILD"     },                     -- Index 3
			{ label = "Say"   ,   const = "SAY"   	,  addon_const = "GUILD"	, callback = "CHAT_MSG_SAY"       },                     -- Index 4
    		{ label = "AG"	  ,   const = "CHANNEL"	,  addon_const = "CHANNEL"	, callback = "CHAT_MSG_CHANNEL" },                     -- Index 5
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
function AztecGambling:SetChatChannel()
	self.chat.channel = self.chat.CHANNEL_CONSTS[self.chat.channel_id]
	self.chat.num_channels = table.getn(self.chat.CHANNEL_CONSTS)

	-- Only offer Say, Party and Raid in the dropdown, in that order - Guild and
	-- AG stay fully usable internally, they're just not shown as a choice here
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

function AztecGambling:SelectChatChannel(channel_id)
	self.chat.channel_id = channel_id
	self.db.global.chat_index = channel_id
	self:SetChatChannel()
end

function AztecGambling:MessageChat(msg)
	SendChatMessage(msg, self.chat.channel.const, nil, self.db.global.custom_channel.index)
end

function AztecGambling:MessageAddon(event, msg)
	self:SendCommMessage(event, msg, self.chat.channel.addon_const, tostring(self.db.global.custom_channel.index))
end

function AztecGambling:RegisterChatEvents()
	self:RegisterEvent("CHAT_MSG_SYSTEM", function(...) self:RollCallback(...) end)
	self:RegisterEvent(self.chat.channel.callback, function(...) self:ChatChannelCallback(...) end)
	if (self.chat.channel.callback_leader) then
		self:RegisterEvent(self.chat.channel.callback_leader, function(...) self:ChatChannelCallback(...) end)
	end
end

function AztecGambling:UnregisterChatEvents()
	-- Cancels everything still scheduled: the TimedStart from LastCall and,
	-- defensively, the roll countdown updater. Roll timers themselves are
	-- stopped via StopRollTimer on every path that gets here first
	self:CancelAllTimers()
	self:HideRollCountdown()
	self:UnregisterEvent("CHAT_MSG_SYSTEM")
	self:UnregisterEvent(self.chat.channel.callback)
	if (self.chat.channel.callback_leader) then
		self:UnregisterEvent(self.chat.channel.callback_leader)
	end
end

-- Game Modes
-- ================
function AztecGambling:SetGameMode()
	-- Loaded from external File
	GAME_MODES = { AG_HILO, AG_INVERSE, AG_BIGTWOS, AG_LILONES, AG_YAHTZEE, AG_CURLING, AG_COUNTDOWN, AG_BLACKJACK }
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


function AztecGambling:SelectGameMode(mode_id)
	self.game.mode_id = mode_id
	self.db.global.game_mode_index = mode_id
	self:SetGameMode()
end


-- Game Stages
-- =====================
function AztecGambling:SetGameStage() 
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

function AztecGambling:ResetGameStage()
	self.game.stage_id = 1
	self:SetGameStage()
end


function AztecGambling:ToggleGameStage()
	self.game.stage.callback()
	if self.game.stage_id < self.game.num_stages then 
		self.game.stage_id = self.game.stage_id + 1 
		self:SetGameStage()
	end
end

-- Stage Callbacks
-- (stage_id = 1) Game will always start here in start game
function AztecGambling:StartGame()
	-- Reset & Init Current GAME
	self.game.data = nil
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
		SendChatMessage(AG_MESSAGES.CUSTOM_CHANNEL_ANNOUNCE(self.db.global.custom_channel.name), "GUILD")
	end

	-- Welcome Message!
	local welcome_msg = AG_MESSAGES.WELCOME(self.game.mode.label, self.game.data.gold_amount)
	self:MessageChat(welcome_msg)
	if (self.game.mode.custom_intro ~= nil) then self:MessageChat(self.game.mode.custom_intro()) end
	self:MessageChat(AG_MESSAGES.PRESS_TO_JOIN)

	-- TODO: Why is this BS different?
	if (self.chat.channel.const == "CHANNEL") then
		self:MessageChat(AG_MESSAGES.TELL_FRIENDS(self.db.global.custom_channel.name))
	end
	
	-- Notify Clients of New GAME
	local start_args = self.game.data.roll_lower.." "..self.game.data.roll_upper.." "..self.game.data.gold_amount.." "..self.chat.channel.const
	self:MessageAddon("AG_NEW_GAME", start_args)
	self:PrintDebug(start_args)
end

-- (stage_id = 2) Count Down to Game Start
function AztecGambling:LastCall()
	self:MessageChat(AG_MESSAGES.LAST_CALL)
	self:ScheduleTimer("TimedStart", 10)
end

-- (stage_id = 3) After accepting entries via chat callbacks, start the rolls
function AztecGambling:StartRolls()
	-- Cancel the countdown to start if its there, and drop any live roll
	-- timer/bar so a below-quorum early return can't leave a frozen countdown
	self:CancelAllTimers()
	self:StopRollTimer()

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
		self:MessageChat(AG_MESSAGES.NOT_ENOUGH_PLAYERS)
		self.game.stage_id = self.game.stage_id - 1
		self:SetGameStage()
		return
	end

	-- Allow roll callbacks
	self.game.data.accepting_rolls = true
	self.game.data.accepting_players = false

	-- Every roll phase, tiebreakers included, gets its own time limit
	self:StartRollTimer()

	-- Tell Tiebreakers Who Has to Roll
	local roll_msg = ""
	if self.game.data.high_tiebreaker then
		self:MessageChat(AG_MESSAGES.HIGH_TIEBREAKER)
		self:PrintTieBreakerPlayers(self.game.data.player_rolls)
	elseif self.game.data.low_tiebreaker then
		self:MessageChat(AG_MESSAGES.LOW_TIEBREAKER)
		self:PrintTieBreakerPlayers(self.game.data.player_rolls)
	end

	-- Off to the races!
	self:MessageChat(roll_msg)
	self:MessageChat(AG_MESSAGES.ROLL_GOODLUCK(self.game.data.roll_range, ROLL_TIME_LIMIT))
end

-- (Countdown) Kick off a turn-based game: settle who goes first with a 1-100 roll-off
function AztecGambling:StartCountdownTurn()
	local required = self.game.mode.max_players or 2

	if (self:TableLength(self.game.data.player_rolls) ~= required) then
		self:MessageChat(AG_MESSAGES.COUNTDOWN_NEEDS_PLAYERS(required))
		self.game.stage_id = self.game.stage_id - 1
		self:SetGameStage()
		return
	end

	self.game.data.accepting_rolls = true
	self.game.data.accepting_players = false
	self:StartCountdownStarterRoll()
end

-- (Countdown) Roll-off to decide who goes first - ties reroll
function AztecGambling:StartCountdownStarterRoll()
	self.game.data.determining_starter = true
	self.game.data.roll_range = "(1-100)"
	self.game.data.player_rolls[self.game.data.turn_order[1]] = -1
	self.game.data.player_rolls[self.game.data.turn_order[2]] = -1

	self:MessageChat(AG_MESSAGES.ROLL_OFF_FIRST)
	self:MessageAddon("AG_TURN_UPDATE", "RollOff 1 100")
	self:UpdateRollStatusUI()
	self:StartRollTimer()
end

-- (Countdown) Handle one player's roll-off roll; once both are in, higher starts (tie = reroll)
function AztecGambling:CountdownStarterRollCallback(player, roll, roll_range)
	if (roll_range ~= self.game.data.roll_range) then return end
	if (self.game.data.player_rolls[player] ~= -1) then return end

	self.game.data.player_rolls[player] = tonumber(roll)
	self:UpdateRollStatusUI()

	local p1, p2 = self.game.data.turn_order[1], self.game.data.turn_order[2]
	if (self.game.data.player_rolls[p1] == -1) or (self.game.data.player_rolls[p2] == -1) then
		return -- still waiting on the other player
	end

	if (self.game.data.player_rolls[p1] == self.game.data.player_rolls[p2]) then
		self:MessageChat(AG_MESSAGES.ROLL_OFF_TIE)
		self:StartCountdownStarterRoll()
		return
	end

	local starter = (self.game.data.player_rolls[p1] > self.game.data.player_rolls[p2]) and p1 or p2
	self.game.data.determining_starter = false
	self.game.mode.init_game(self.game) -- restore the real bet range after the roll-off
	self.game.data.player_rolls[p1] = -1
	self.game.data.player_rolls[p2] = -1
	self.game.data.turn_player = starter

	self:MessageChat(AG_MESSAGES.ROLL_OFF_WINNER(starter, self.game.data.roll_range))
	self:MessageAddon("AG_TURN_UPDATE", starter.." "..self.game.data.roll_lower.." "..self.game.data.roll_upper)
	self:StartRollTimer() -- the time limit applies to each turn
end

-- (Countdown) Handle one player's roll, pass the turn, or end the game on a 1
function AztecGambling:CountdownRollCallback(player, roll, roll_range)
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
	self:MessageChat(AG_MESSAGES.OPPONENT_TURN(opponent, self.game.data.roll_range))
	self:MessageAddon("AG_TURN_UPDATE", opponent.." "..self.game.data.roll_lower.." "..self.game.data.roll_upper)
	self:StartRollTimer()
end

function AztecGambling:PrintTieBreakerPlayers(players)
	tiebreaker_list = ""
	for player, roll in pairs(players) do
		-- TODO - Figure out how to use this for Yahtzee self.game.mode.fmt_score(roll)
		tiebreaker_list = tiebreaker_list..player..AG_MESSAGES.TIEBREAKER_VS
	end
	tiebreaker_list = tiebreaker_list:sub(1, -5)
	self:MessageChat(tiebreaker_list)
end

-- (stage_id =4) Poll for Roll Status
function AztecGambling:RollStatus()
	self:CheckRollsComplete(true)
end

function AztecGambling:CheckRollsComplete(print_players)

	local rolls_complete = true

	self:PrintDebug("CheckRollsComplete() Called")

	if print_players and self.game.data.roll_deadline then
		local seconds_left = math.max(0, math.floor(self.game.data.roll_deadline - GetTime()))
		self:MessageChat(AG_MESSAGES.TIME_LEFT(seconds_left))
	end

	-- Once Blackjack is past the deal, completion is tracked via
	-- blackjack_active/CheckBlackjackHandsComplete, not raw rolls
	if self.game.mode.hit_stand and self.game.data.dealt then
		if print_players then
			for player, active in pairs(self.game.data.blackjack_active) do
				if active then
					self:MessageChat(AG_MESSAGES.PLAYER_NEEDS_HIT_OR_STAND(player))
				end
			end
		end
		return
	end

	for player, roll in pairs(self.game.data.player_rolls) do
		if (roll == -1) then
			rolls_complete = false
			if print_players then
				self:MessageChat(AG_MESSAGES.PLAYER_NEEDS_ROLL(player))
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
function AztecGambling:StartBlackjackHitPhase()
	self.game.data.dealt = true
	self.game.data.roll_lower = self.game.mode.hit_lower
	self.game.data.roll_upper = self.game.mode.hit_upper
	self.game.data.roll_range = self.game.mode.hit_range

	for player, total in pairs(self.game.data.player_rolls) do
		if (tonumber(total) == 21) then
			self.game.data.blackjack_active[player] = false
			self:MessageChat(AG_MESSAGES.NATURAL_BLACKJACK(player))
		else
			self.game.data.blackjack_active[player] = true
		end
	end

	self:MessageChat(AG_MESSAGES.DEALT)
	self:UpdateRollStatusUI()
	self:StartRollTimer() -- the hit/stand phase gets its own time limit
	self:CheckBlackjackHandsComplete()
end

-- (Blackjack) Once every player has stood or busted, hand off to scoring
function AztecGambling:CheckBlackjackHandsComplete()
	for player, active in pairs(self.game.data.blackjack_active) do
		if active then return end
	end
	self:GameLoop()
end

-- Roll Time Limit
-- =================
-- Every roll phase (each round, each tiebreaker, each Countdown roll and the
-- Blackjack hit phase) gets ROLL_TIME_LIMIT seconds, with a warning in chat
-- ROLL_WARNING_SECONDS before the end
function AztecGambling:StartRollTimer()
	self:StopRollTimer()
	self.game.data.roll_deadline = GetTime() + ROLL_TIME_LIMIT
	self.roll_warning_timer = self:ScheduleTimer("RollTimeWarning", ROLL_TIME_LIMIT - ROLL_WARNING_SECONDS)
	self.roll_timeout_timer = self:ScheduleTimer("RollTimeExpired", ROLL_TIME_LIMIT)
	self:ShowRollCountdown()
end

function AztecGambling:StopRollTimer()
	if self.roll_warning_timer then self:CancelTimer(self.roll_warning_timer) end
	if self.roll_timeout_timer then self:CancelTimer(self.roll_timeout_timer) end
	self.roll_warning_timer = nil
	self.roll_timeout_timer = nil
	self:HideRollCountdown()
	if (self.game.data ~= nil) then
		self.game.data.roll_deadline = nil
	end
end

-- Roll Countdown UI
-- =================
-- The in-window mirror of the roll deadline: a progress bar with a caption and
-- the seconds left, shown only while a timed roll phase is live. Called from
-- StartRollTimer/StopRollTimer only, so every phase updates it automatically.
-- Visibility uses frame alpha because the Flow layout force-shows every child
-- frame on each layout pass - Hide() on an AG_Frame child would not stick
function AztecGambling:ShowRollCountdown()
	if (self.ui.roll_countdown == nil) then return end
	-- Idempotent: a phase restarting while the bar is live (tiebreakers,
	-- Countdown rerolls/turns) must never stack repeating timers
	self:HideRollCountdown()
	self.ui.roll_countdown.frame:SetAlpha(1)
	self.countdown_timer = self:ScheduleRepeatingTimer("UpdateRollCountdown", 0.2)
	self:UpdateRollCountdown()
end

function AztecGambling:HideRollCountdown()
	if self.countdown_timer then self:CancelTimer(self.countdown_timer) end
	self.countdown_timer = nil
	if (self.ui.roll_countdown ~= nil) then
		self.ui.roll_countdown.frame:SetAlpha(0)
	end
	-- NOTE: deliberately does NOT clear roll_deadline - ShowRollCountdown
	-- re-hides first for idempotency, right after StartRollTimer set it.
	-- StopRollTimer owns clearing it.
end

-- Refresh bar + texts from the roll deadline; the sole periodic caller is
-- countdown_timer, started/stopped by Show/HideRollCountdown
function AztecGambling:UpdateRollCountdown()
	local bar = self.ui.roll_countdown
	if (bar == nil) or (self.game.data == nil) or (self.game.data.roll_deadline == nil) then return end

	local left = math.max(0, self.game.data.roll_deadline - GetTime())
	bar:SetFraction(left / ROLL_TIME_LIMIT)

	-- Red during the final seconds, mirroring the chat warning window
	if (left <= ROLL_WARNING_SECONDS) then
		bar:SetBarColor(1.0, 0.2, 0.2)
		bar:SetSecondsColor(1.0, 0.2, 0.2)
	else
		bar:SetBarColor(0.2, 1.0, 0.2)
		bar:SetSecondsColor(1.0, 0.82, 0.0)
	end

	if (left > 0) then
		bar:SetCaption("Rolls close in")
		bar:SetSecondsText(math.ceil(left) .. "s")
	else
		-- RollTimeExpired fires at 0; the 0.2s updater may land here first
		bar:SetCaption("Time's up!")
		bar:SetSecondsText("")
	end
end

-- Players the current roll phase is still waiting on, sorted by name
function AztecGambling:GetPendingRollers()
	local pending = {}
	if self.game.mode.hit_stand and self.game.data.dealt then
		for player, active in pairs(self.game.data.blackjack_active) do
			if active then table.insert(pending, player) end
		end
	elseif self.game.mode.turn_based and (not self.game.data.determining_starter) then
		table.insert(pending, self.game.data.turn_player)
	else
		for player, roll in pairs(self.game.data.player_rolls) do
			if (roll == -1) then table.insert(pending, player) end
		end
	end
	table.sort(pending)
	return pending
end

function AztecGambling:RollTimeWarning()
	if (self.game.data == nil) then return end

	local pending = self:GetPendingRollers()
	if (#pending > 0) then
		self:MessageChat(AG_MESSAGES.ROLL_TIME_WARNING(ROLL_WARNING_SECONDS, pending))
	end
end

function AztecGambling:RollTimeExpired()
	if (self.game.data == nil) then return end

	local pending = self:GetPendingRollers()
	if (#pending == 0) then return end

	if self.game.mode.hit_stand and self.game.data.dealt then
		self:TimeoutAutoStand(pending)
	elseif self.game.mode.turn_based then
		self:TimeoutCountdown(pending)
	elseif self.game.data.low_tiebreaker then
		self:TimeoutLowTiebreaker(pending)
	elseif self.game.data.high_tiebreaker and (self.game.data.loser == nil) then
		-- Only happens when everyone tied in the first round
		if self.game.mode.everyone_tied_removes then
			self:TimeoutRemovePlayers(pending)
		else
			self:TimeoutEveryoneTied(pending)
		end
	elseif self.game.data.high_tiebreaker then
		self:TimeoutHighTiebreaker(pending)
	else
		self:TimeoutRemovePlayers(pending)
	end
end

function AztecGambling:RemoveFromRolls(players)
	for _, player in ipairs(players) do
		self.game.data.player_rolls[player] = nil
	end
end

-- Normal round: players who didn't roll are out, the rest are scored as usual
function AztecGambling:TimeoutRemovePlayers(pending)
	self:RemoveFromRolls(pending)
	if (self:TableLength(self.game.data.player_rolls) < 2) then
		self:CancelRound()
		return
	end

	self:MessageChat(AG_MESSAGES.TIMEOUT_REMOVED(pending))
	self:UpdateRollStatusUI()
	self:CheckRollsComplete(false)
end

-- Winners' tiebreaker: players who didn't roll give up the win (the loser is already decided)
function AztecGambling:TimeoutHighTiebreaker(pending)
	self:RemoveFromRolls(pending)
	local remaining = self:TableLength(self.game.data.player_rolls)
	if (remaining == 0) then
		self:CancelRound()
		return
	end

	self:MessageChat(AG_MESSAGES.TIMEOUT_GAVE_UP_WIN(pending))
	if (remaining == 1) then
		self.game.data.winner = next(self.game.data.player_rolls)
		self:FinishGame()
	else
		self:UpdateRollStatusUI()
		self:CheckRollsComplete(false)
	end
end

-- Losers' tiebreaker: a player who didn't roll loses. If several didn't roll,
-- they go to a new losers' tiebreaker among themselves
function AztecGambling:TimeoutLowTiebreaker(pending)
	if (#pending > 1) then
		self:MessageChat(AG_MESSAGES.TIMEOUT_TIED_LAST(pending))
		self.game.data.player_rolls = {}
		for _, player in ipairs(pending) do
			self.game.data.player_rolls[player] = -1
		end
		self:StartRolls()
		return
	end

	self:RemoveFromRolls(pending)
	self:MessageChat(AG_MESSAGES.TIMEOUT_LOSES(pending[1]))
	self.game.data.loser = pending[1]
	self.game.data.low_tiebreaker = false
	self.game.data.low_roller_playoff = {}

	-- Same hand-off as EvaluateScores once the loser is found: settle a tied win first, if there is one
	if (self:TableLength(self.game.data.high_roller_playoff) > 1) then
		self.game.data.high_tiebreaker = true
		self.game.data.player_rolls = self:CopyTable(self.game.data.high_roller_playoff)
		self:StartRolls()
	else
		self:FinishGame()
	end
end

-- Everyone tied, so this tiebreaker decides both the winner and the loser: players
-- who didn't roll give up the win and lose, same as in a losers' tiebreaker
function AztecGambling:TimeoutEveryoneTied(pending)
	self:RemoveFromRolls(pending)
	if (self:TableLength(self.game.data.player_rolls) == 0) then
		self:CancelRound()
		return
	end

	-- Everyone rolled the same score in the first round, so that is also the losing roll.
	-- The loser won't have a tiebreaker roll to take it from
	if (self.game.data.losing_roll == nil) then
		self.game.data.losing_roll = self.game.data.winning_roll
	end

	if (#pending == 1) then
		self:MessageChat(AG_MESSAGES.TIMEOUT_LOSES(pending[1]))
		self.game.data.loser = pending[1]
	else
		-- EvaluateScores starts a losers' tiebreaker among these players once the winner is decided
		self:MessageChat(AG_MESSAGES.TIMEOUT_TIED_LAST(pending))
		self.game.data.low_roller_playoff = {}
		for _, player in ipairs(pending) do
			self.game.data.low_roller_playoff[player] = -1
		end
	end

	-- The players who rolled settle the win among themselves
	self:UpdateRollStatusUI()
	self:CheckRollsComplete(false)
end

-- Countdown: a player who doesn't roll loses. If neither rolled the roll-off, the round is cancelled
function AztecGambling:TimeoutCountdown(pending)
	if (#pending > 1) then
		self:CancelRound()
		return
	end

	local p1, p2 = self.game.data.turn_order[1], self.game.data.turn_order[2]
	self.game.data.accepting_rolls = false
	self.game.data.loser = pending[1]
	self.game.data.winner = (pending[1] == p1) and p2 or p1
	self:MessageChat(AG_MESSAGES.TIMEOUT_LOSES(pending[1]))
	self:FinishGame()
end

-- (Blackjack) Hit/stand phase: players who haven't finished stand on their current total
function AztecGambling:TimeoutAutoStand(pending)
	for _, player in ipairs(pending) do
		self.game.data.blackjack_active[player] = false
		self.game.data.awaiting_hit[player] = nil
	end
	self:MessageChat(AG_MESSAGES.TIMEOUT_AUTO_STAND(pending))
	self:UpdateRollStatusUI()
	self:CheckBlackjackHandsComplete()
end

-- End the round with no payout, ex: not enough players rolled in time
function AztecGambling:CancelRound()
	self:MessageChat(AG_MESSAGES.TIMEOUT_CANCELLED)
	self:CloseRollStatusUI()
	-- Stop the roll timers/countdown explicitly before nil'ing the game data,
	-- so the bar can't linger on a frame with no deadline behind it
	self:StopRollTimer()
	self:UnregisterChatEvents()
	self.game.data = nil
	self:ResetGameStage()
end

function AztecGambling:FinishGame()
	self.game.mode.payout(self.game)
	local payout_msg = AG_MESSAGES.PAYOUT(self.game.data.loser, self.game.data.winner, self.game.data.cash_winnings)
	self.last_payout = payout_msg
	self:MessageChat(payout_msg)
	self:LogResults()
	self:EndGame()
end

-- Re-announce the last payout, in case people missed it or started a new round before paying up
function AztecGambling:RepeatLastPayout()
	if (self.last_payout == nil) then
		self:MessageChat(AG_MESSAGES.NO_PAYOUT_YET)
		return
	end
	self:MessageChat(self.last_payout)
end

function AztecGambling:GameLoop()
	if (AztecGambling:EvaluateScores()) then
		self:FinishGame()
	end
end


function AztecGambling:EndGame()
	-- The roll timers are usually still live when everyone finished early -
	-- stop them (and the countdown bar) before archiving the game data
	self:StopRollTimer()

	-- Tell  the clients and UI were done
	local end_args = self.game.data.winner.." "..self.game.data.loser.." "..self.game.data.cash_winnings
	self:MessageAddon("AG_END_GAME", end_args)
	self.ui.AG_Frame:SetStatusText(self.game.data.cash_winnings.."g  "..self.game.data.loser.." => "..self.game.data.winner)
	
	-- Clear the Roll Status UI
	self:CloseRollStatusUI()

	-- Reset Game Hooks and Data
	self:UnregisterChatEvents()
	self:ResetGameStage()
	self.previous_gameData = self:deepcopy(self.game.data)
end


function AztecGambling:ResetGame()
	self:StopRollTimer()
	self:UnregisterChatEvents()
	self.game.data = nil
	self:ResetGameStage()
	self:MessageChat(AG_MESSAGES.GAME_RESET)
end

-- Utils
-- ========
function AztecGambling:GameResultsCallback(...)
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

function AztecGambling:LogResults() 
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

function AztecGambling:SetGoldAmount() 

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
function AztecGambling:EvaluateScores()
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

function AztecGambling:UpdateRollStatusUI()
	if ((self.ui ~= nil) and (self.game.data ~= nil)) then

		if (self.ui.AG_RollFrame == nil) then

			-- Create the Rolling Frame and attach it to the casino frame
			-- *THIS IS STUPID DO IT IN XML TODODODODO*TODO -- 
			self.ui.AG_RollFrame = AceGUI:Create("Frame")
			self.ui.AG_RollFrame:SetWidth(200)
			self.ui.AG_RollFrame:SetHeight(self.ui.AG_Frame.frame:GetHeight() * 2)
			self.ui.AG_RollFrame:ClearAllPoints()
			self.ui.AG_RollFrame:SetPoint("BOTTOMLEFT", self.ui.AG_Frame.frame, "BOTTOMRIGHT", 0, 0)
			self.ui.AG_RollFrame:SetTitle("Roll Status")
			

			-- Boiler plat code for a container object
			self.ui.AG_RollFrameScrollcontainer = AceGUI:Create("SimpleGroup") 
			self.ui.AG_RollFrameScrollcontainer:SetFullWidth(true)
			self.ui.AG_RollFrameScrollcontainer:SetHeight(self.ui.AG_RollFrame.frame:GetHeight() - 75)
			self.ui.AG_RollFrameScrollcontainer:SetLayout("Fill") 
			self.ui.AG_RollFrame:AddChild(self.ui.AG_RollFrameScrollcontainer)

			-- Attach a scrollbar to the container 
			self.ui.AG_RollFrameScroll = AceGUI:Create("ScrollFrame")
			self.ui.AG_RollFrameScroll:SetLayout("Flow") 
			self.ui.AG_RollFrameScrollcontainer:AddChild(self.ui.AG_RollFrameScroll)

		end

		-- Refresh the list of players and their rolls
		self.ui.AG_RollFrameScroll:ReleaseChildren()	
		for player, roll in self:sortedpairs(self.game.data.player_rolls, self.game.mode.sort_rolls) do

			label = AceGUI:Create("Label")
			if (roll ~= tonumber(-1)) then 
				label:SetText(roll.." : "..player)
			else 
				label:SetText(" - : "..player)
			end
			label:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE, MONOCHROME")
			label:SetColor(255, 255, 0)
			self.ui.AG_RollFrameScroll:AddChild(label)
		end

	end
end

function AztecGambling:CloseRollStatusUI()
	if (self.ui.AG_RollFrame == nil) then return end
	self.ui.AG_RollFrame:ReleaseChildren()
	self.ui.AG_RollFrame:Release()
	self.ui.AG_RollFrame = nil
end


function AztecGambling:RollCallback(...)
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
				self:MessageChat(AG_MESSAGES.HIT_DRAW_BUST(player, roll, new_total))
			elseif (new_total == 21) then
				self.game.data.blackjack_active[player] = false
				self:MessageChat(AG_MESSAGES.HIT_DRAW_BLACKJACK(player, roll))
			else
				self:MessageChat(AG_MESSAGES.HIT_DRAW_CONTINUE(player, roll, new_total))
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
			-- TODO: Only in NONGROUP channels if channel == "AG_ROLL_DICE" then SendSystemMessage(roll_text) end
			self.game.data.player_rolls[player] = tonumber(roll)

			-- Update the UI and Check for the game end 
			self:UpdateRollStatusUI()			
			self:CheckRollsComplete(false)
		end
	end
	
end

function AztecGambling:ChatChannelCallback(...)
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
			self:MessageChat(AG_MESSAGES.HITS(sender, self.game.data.roll_range))
			self:MessageAddon("AG_TURN_UPDATE", sender.." "..self.game.data.roll_lower.." "..self.game.data.roll_upper)
			return
		elseif (choice == "stand") then
			self.game.data.blackjack_active[sender] = false
			self.game.data.awaiting_hit[sender] = nil
			self:MessageChat(AG_MESSAGES.STANDS(sender, self.game.data.player_rolls[sender]))
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
function AztecGambling:PrintBanlist()
	self:MessageChat(AG_MESSAGES.HALL_OF_GTFO)
	for player, _ in pairs(self.db.global.ban_list) do
		self:MessageChat(player)
    end
end

function AztecGambling:PrintRanklist()

	self:MessageChat(AG_MESSAGES.HALL_OF_FAME)
	local index = 1
	local sort_descending = function(t,a,b) return t[b] < t[a] end
	for player, gold in self:sortedpairs(self.db.global.rankings, sort_descending) do
		if gold <= 0 then break end

		self:MessageChat(AG_MESSAGES.RANK_WON(index, player, gold))
		index = index + 1
	end

	self:MessageChat(AG_MESSAGES.RANK_SEPARATOR)

	self:MessageChat(AG_MESSAGES.HALL_OF_SHAME)
	index = 1
	local sort_ascending = function(t,a,b) return t[b] > t[a] end
	for player, gold in self:sortedpairs(self.db.global.rankings, sort_ascending) do
		if gold >= 0 then break end

		self:MessageChat(AG_MESSAGES.RANK_LOST(index, player, gold))
		index = index + 1
	end

end

function AztecGambling:RollForMe()
	if self.game.data == nil then
		SendSystemMessage(AG_MESSAGES.NO_ACTIVE_GAME_TO_ROLL)
		return
	end
	RandomRoll(self.game.data.roll_lower, self.game.data.roll_upper)
end

function AztecGambling:EnterForMe()
	self:MessageChat(AG_MESSAGES.JOIN_SIGNAL)
end

function AztecGambling:TimedStart() 
	if (self.game.data ~= nil) then
		if not self.game.data.accepting_rolls then 
			self.game.stage_id = 4 -- 4 is the final stage
			self:SetGameStage()
			self:StartRolls()
		end
	end
end

-- NEEDS TO BE COMMON WITH AGCLIENT! TODO!
function AztecGambling:OpenTradeWinner()
	InitiateTrade(self.game.data.winner)
end

-- UI ELEMENTS 
-- ======================================================
function AztecGambling:ShowUI()
	self.ui.AG_Frame:Show()
	self.db.global.window_shown = true
end

function AztecGambling:HideUI()
	self.ui.AG_Frame:Hide()
	self.db.global.window_shown = false
	self:SaveFrameState()
end

function AztecGambling:SaveFrameState()
	self.db.global.ui_frame = self:CopyTable(self.ui.AG_Frame.status)
end

function AztecGambling:ConstructUI()

	-- Settings to be used --
	local ag_ui_elements = {
		-- Main Box Frame --
		main_frame = {
			width = 400,
			-- Extra ~25px below the Casino group for the roll-countdown row
			height = 220
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
			-- TODO : Make this common with AGClient
			open_trade = {
				width = 100,
				label = "Trade",
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
	
	-- AG_Frame - Represents the window frame of the addon
	self.ui.AG_Frame = AceGUI:Create("Frame")
	self.ui.AG_Frame:SetTitle("Aztec Gambling")
	self.ui.AG_Frame:SetStatusText("")
	self.ui.AG_Frame:SetLayout("Flow")
	self.ui.AG_Frame:SetStatusTable(ag_ui_elements.main_frame)
	self.ui.AG_Frame:EnableResize(false)
	self.ui.AG_Frame:SetCallback("OnClose", function() self:HideUI() end)
	self.ui.AG_Frame.frame:EnableMouse(true)
	self.ui.AG_Frame.frame:SetUserPlaced(true)

	-- Mouse callbacks 
	on_mouse_down = function(w, button) 
		if (button == "RightButton") then 
			self:ToggleCasino() 
		end 
	end
	self.ui.AG_Frame.frame:SetScript("OnMouseDown", on_mouse_down)
	
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
			table.insert(columns, ag_ui_elements.buttons[name].width)
		end
		table.insert(columns, {weight = 1, alignH = "fill"})
		row:SetUserData("table", { columns = columns, space = 4 })

		local left_spacer = AceGUI:Create("Button")
		left_spacer.frame:SetAlpha(0)
		row:AddChild(left_spacer)

		for _, name in ipairs(control_names) do
			local control_settings = ag_ui_elements.buttons[name]

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
	self.ui.AG_PlayFrame = BuildRow(ag_ui_elements.row1_index, ag_ui_elements.main_frame.width)
	self.ui.AG_Frame:AddChild(self.ui.AG_PlayFrame)

	-- AG_CasinoGroup - Bordered, titled "Casino" box wrapping rows 2 and 3
	-- ====================================================
	self.ui.AG_CasinoGroup = AceGUI:Create("InlineGroup")
	self.ui.AG_CasinoGroup:SetTitle("Casino")
	self.ui.AG_CasinoGroup:SetLayout("Flow")
	self.ui.AG_CasinoGroup:SetWidth(ag_ui_elements.main_frame.width)

	-- InlineGroup insets its content by 20px (10px on each side) - rows inside
	-- it need to be built to that narrower width, not the full frame width
	local casino_row_width = ag_ui_elements.main_frame.width - 20

	-- Row 2: chat channel, gold entry, game mode, new game, reset
	self.ui.AG_CasinoFrame = BuildRow(ag_ui_elements.row2_index, casino_row_width)
	self.ui.AG_CasinoGroup:AddChild(self.ui.AG_CasinoFrame)

	-- Row 3: PAY!
	self.ui.AG_ModeFrame = BuildRow(ag_ui_elements.row3_index, casino_row_width)
	self.ui.AG_CasinoGroup:AddChild(self.ui.AG_ModeFrame)

	self.ui.AG_Frame:AddChild(self.ui.AG_CasinoGroup)

	-- Countdown bar: shown only while a timed roll phase is live (StartRollTimer/
	-- StopRollTimer). Stock AceGUI-3.0 has no ProgressBar widget, so a private
	-- "RollCountdown" widget type is registered at the bottom of this file -
	-- the bundled libs\Ace3 stays untouched. Caption and seconds text live
	-- inside the widget; it starts alpha-hidden since the Flow layout of
	-- AG_Frame would force-show it otherwise
	self.ui.roll_countdown = AceGUI:Create("RollCountdown")
	self.ui.roll_countdown:SetWidth(ag_ui_elements.main_frame.width)
	self.ui.AG_Frame:AddChild(self.ui.roll_countdown)
	self.ui.roll_countdown.frame:SetAlpha(0)

	if (self.db.global.ui_frame ~= nil) then
		-- Restore the saved position, but always keep the width/height defined above -
		-- otherwise a size saved by an older layout (fewer rows) keeps overriding it forever
		self.ui.AG_Frame:SetStatusTable(self.db.global.ui_frame)
		self.ui.AG_Frame:SetWidth(ag_ui_elements.main_frame.width)
		self.ui.AG_Frame:SetHeight(ag_ui_elements.main_frame.height)
	end
	
	if not self.db.global.window_shown then
		self.ui.AG_Frame:Hide()
	end
	
	-- Register for UI Events
	self:RegisterEvent("PLAYER_LEAVING_WORLD", function(...) self:SaveFrameState(...) end)
end

-- AceGUI "RollCountdown" Widget
-- ============================
-- A minimal read-only progress bar: fixed-width caption on the left, the bar
-- in the middle, a right-aligned seconds text at the end. Stock AceGUI-3.0 has
-- no ProgressBar, and registering it here (instead of under libs\Ace3) keeps
-- the bundled libraries untouched. Built for the roll-phase countdown and
-- driven by AztecGambling:UpdateRollCountdown
do
	local Type, Version = "RollCountdown", 1

	if (AceGUI:GetWidgetVersion(Type) or 0) < Version then
		-- How much of the widget's width the caption and seconds text get
		local CAPTION_WIDTH = 150
		local TEXT_WIDTH = 44
		local INSET = 4

		local function UpdateBar(self)
			-- Compute the track width from the widget's own width and the fixed
			-- caption/text columns - anchored texture widths may not be resolved
			-- yet during layout, the arithmetic always is
			local width = self.frame:GetWidth() or self.width or 200
			local track_width = math.max(0, width - CAPTION_WIDTH - TEXT_WIDTH - INSET * 2)
			local frac = self.fraction or 0
			if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
			self.fill:SetWidth(frac * track_width)
		end

		local methods = {
			["OnAcquire"] = function(self)
				self:SetWidth(200)
				self:SetHeight(22)
				self:SetCaption("")
				self:SetSecondsText("")
				self:SetBarColor(1, 1, 1)
				self:SetSecondsColor(1, 0.82, 0)
				self:SetFraction(0)
			end,

			-- Progress on a 0-1 scale
			["SetFraction"] = function(self, value)
				self.fraction = value
				UpdateBar(self)
			end,

			["SetCaption"] = function(self, text)
				self.caption:SetText(text or "")
			end,

			["SetSecondsText"] = function(self, text)
				self.seconds:SetText(text or "")
			end,

			["SetSecondsColor"] = function(self, r, g, b)
				self.seconds:SetTextColor(r or 1, g or 1, b or 1, 1)
			end,

			["SetBarColor"] = function(self, r, g, b)
				self.fill:SetColorTexture(r or 1, g or 1, b or 1, 1)
			end,

			["OnWidthSet"] = function(self)
				-- The track spans between the anchored caption/seconds, so its
				-- width already follows ours - just redraw the bar against it
				UpdateBar(self)
			end,
		}

		local function Constructor()
			local frame = CreateFrame("Frame", nil, UIParent)
			frame:SetHeight(22)

			local caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			caption:SetPoint("TOPLEFT", frame, "TOPLEFT")
			caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
			caption:SetWidth(CAPTION_WIDTH)
			caption:SetJustifyH("LEFT")

			local track = frame:CreateTexture(nil, "BACKGROUND")
			track:SetColorTexture(0, 0, 0, 0.5)
			-- Both offsets moved -2 vs the caption/frame so the bar keeps its
			-- height but sits 2px higher inside the row (the fill follows it)
			track:SetPoint("TOPLEFT", caption, "TOPRIGHT", INSET, -4)
			track:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(TEXT_WIDTH + INSET), 6)

			local fill = frame:CreateTexture(nil, "ARTWORK")
			fill:SetColorTexture(1, 1, 1, 1)
			fill:SetPoint("TOPLEFT", track, "TOPLEFT")
			fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
			fill:SetWidth(0)

			local seconds = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			seconds:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
			seconds:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
			seconds:SetWidth(TEXT_WIDTH)
			seconds:SetJustifyH("RIGHT")

			local widget = {
				frame   = frame,
				caption = caption,
				track   = track,
				fill    = fill,
				seconds = seconds,
				type    = Type,
			}
			for method, func in pairs(methods) do
				widget[method] = func
			end

			return AceGUI:RegisterAsWidget(widget)
		end

		AceGUI:RegisterWidgetType(Type, Constructor, Version)
	end
end