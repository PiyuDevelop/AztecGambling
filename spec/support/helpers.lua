-- Plays rounds the way people do in the game: the host clicks the stage
-- button, players type in chat and /roll. Each action sends the addon the
-- same event the game would.
--
--   local env = loader.load()
--   local game = helpers.new(env)
--   game:start_round({ mode = "HiLo", bet = "500", players = { "Jayred", "Piyu" } })
--   game:roll("Jayred", 480)
--   game:roll("Piyu", 37)
--   assert.is_true(game:chat_contains("Piyu owes Jayred 443 gold!"))
local Helpers = {}
Helpers.__index = Helpers

-- Chat events carry "Name-Realm"; the addon strips the realm with Ambiguate
local REALM = "Tichondrius"

local CHANNEL_INDEX = { RAID = 1, PARTY = 2, GUILD = 3, SAY = 4 }

function Helpers.new(env)
	return setmetatable({ env = env, host = env.host }, Helpers)
end

-- Host actions
-- ============

-- What the host typed in the gold box
function Helpers:set_bet(text)
	self.host.ui.gold_amount_entry.GetText = function() return text end
end

-- "RAID", "PARTY", "GUILD" or "SAY", picked in the chat channel dropdown
function Helpers:set_channel(channel)
	local index = CHANNEL_INDEX[channel]
	assert(index, "unknown chat channel " .. tostring(channel))
	self.host:SelectChatChannel(index)
end

-- A mode label from the game mode dropdown, e.g. "Blackjack"
function Helpers:set_mode(label)
	for index, mode in ipairs(GAME_MODES) do
		if mode.label == label then
			self.host:SelectGameMode(index)
			return
		end
	end
	error("unknown game mode " .. tostring(label))
end

-- The stage button: New Game -> Last Call -> Start Rolling -> Status
function Helpers:click_stage()
	self.host:ToggleGameStage()
end

-- The label the stage button shows now
function Helpers:stage()
	return self.host.game.stage.label
end

-- Sets everything up and opens the rolls: picks the channel, mode and bet,
-- starts a new game, has each player type 1, then clicks through Last Call
-- and Start Rolling. opts: mode (default "HiLo"), bet (default "500"),
-- channel (default "PARTY"), players (list of names)
function Helpers:start_round(opts)
	self:set_channel(opts.channel or "PARTY")
	self:set_mode(opts.mode or "HiLo")
	self:set_bet(opts.bet or "500")
	self:click_stage() -- New Game
	for _, player in ipairs(opts.players or {}) do
		self:say(player, "1")
	end
	self:click_stage() -- Last Call
	self:click_stage() -- Start Rolling
end

-- Player actions
-- ==============

-- A chat line from a player in the game's chat channel
function Helpers:say(player, text)
	local sender = player:find("-", 1, true) and player or (player .. "-" .. REALM)
	return self.env.fire_event(self.host.chat.channel.callback, text, sender)
end

-- The text format of /roll system messages in the client's language, e.g.
-- "%s tira los dados y obtiene %d (%d-%d)" for Spanish. Set through _G:
-- busted gives each spec file its own globals, so a plain assignment in a
-- spec wouldn't reach the addon.
function Helpers:set_roll_format(format)
	_G.RANDOM_ROLL_RESULT = format
end

-- The /roll system message. Without low/high, rolls the range the round
-- currently tells players to roll. It's read from roll_range, which is the
-- only thing that changes during Countdown's 1-100 roll-off.
function Helpers:roll(player, roll, low, high)
	if low == nil then
		local data = self.host.game.data
		assert(data and data.roll_range, "no round is running: pass low and high")
		low, high = data.roll_range:match("^%((%d+)%-(%d+)%)$")
		low, high = tonumber(low), tonumber(high)
	end
	local text = string.format(_G.RANDOM_ROLL_RESULT, player, roll, low, high)
	return self.env.fire_event("CHAT_MSG_SYSTEM", text)
end

-- Time
-- ====

function Helpers:advance(seconds)
	self.env.clock:advance(seconds)
end

-- Seconds until the current roll phase times out
function Helpers:time_left()
	local data = self.host.game.data
	assert(data and data.roll_deadline, "no roll phase is running")
	return data.roll_deadline - self.env.clock:time()
end

function Helpers:wait_for_timeout()
	self:advance(self:time_left())
end

-- Seconds until the "seconds left!" warning of the current roll phase
function Helpers:time_until_warning()
	return self.env.clock:time_left(self.host.roll_warning_timer)
end

-- What the addon sent
-- ===================

function Helpers:chat_texts()
	local texts = {}
	for index, message in ipairs(self.env.chat) do texts[index] = message.text end
	return texts
end

-- A bookmark in the chat log, for looking only at what comes after it
function Helpers:mark()
	return #self.env.chat
end

function Helpers:chat_since(mark)
	local texts = {}
	for index = mark + 1, #self.env.chat do table.insert(texts, self.env.chat[index].text) end
	return texts
end

-- True if a chat message contains text (plain text, not a pattern)
function Helpers:chat_contains(text, since)
	for _, line in ipairs(self:chat_since(since or 0)) do
		if line:find(text, 1, true) then return true end
	end
	return false
end

function Helpers:count_chat(text, since)
	local count = 0
	for _, line in ipairs(self:chat_since(since or 0)) do
		if line:find(text, 1, true) then count = count + 1 end
	end
	return count
end

-- True if a chat line lists exactly these players as "A vs B vs C", in any
-- order: the addon lists tiebreaker players in no particular order
function Helpers:chat_lists_tiebreaker(players, since)
	local expected = {}
	for _, player in ipairs(players) do expected[player] = true end
	for _, line in ipairs(self:chat_since(since or 0)) do
		local names, count = {}, 0
		for name in (line .. " vs "):gmatch("(.-) vs ") do
			names[name] = true
			count = count + 1
		end
		local matches = count == #players
		for player in pairs(expected) do
			if not names[player] then matches = false end
		end
		if matches then return true end
	end
	return false
end

-- Texts of the addon messages sent with this prefix, oldest first
function Helpers:comm_texts(prefix)
	local texts = {}
	for _, message in ipairs(self.env.comm_sent) do
		if message.prefix == prefix then table.insert(texts, message.text) end
	end
	return texts
end

-- Host state
-- ==========

function Helpers:rankings()
	return self.host.db.global.rankings
end

function Helpers:joined_players()
	local players = {}
	for player in pairs(self.host.game.data.player_rolls) do table.insert(players, player) end
	table.sort(players)
	return players
end

-- Whether the host is listening to chat and rolls (only while a round runs)
function Helpers:is_listening()
	return self.env.is_event_registered("CHAT_MSG_SYSTEM", self.host)
end

return Helpers
