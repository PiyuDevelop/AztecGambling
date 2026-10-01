-- Stand-ins for the WoW API functions the addon calls. Everything the addon
-- sends out (chat, system messages, rolls, trades) is recorded on env, so
-- tests can check it.
local UIStub = require("spec.support.ui_stub")

local WowApi = {}

-- The client's /roll system message (enUS). Tests for other client languages
-- replace the RANDOM_ROLL_RESULT global before building roll messages.
WowApi.ROLL_RESULT_ENUS = "%s rolls %d (%d-%d)"

-- Numbers 1-4 are the default channels (General, Trade, ...), so custom ones start at 5
local FIRST_CUSTOM_CHANNEL = 5

function WowApi.install(env)
	env.player_name = env.player_name or "Host"
	env.chat = {}          -- SendChatMessage calls: { text, chat_type, language, channel }
	env.system = {}        -- SendSystemMessage texts
	env.random_rolls = {}  -- RandomRoll calls: { low, high }
	env.trades = {}        -- InitiateTrade targets
	env.channels = {}      -- custom channels joined: name -> number
	env.channels_left = {} -- LeaveChannelByName names

	_G.RANDOM_ROLL_RESULT = WowApi.ROLL_RESULT_ENUS

	_G.GetTime = function()
		return env.clock:time()
	end

	_G.SendChatMessage = function(text, chat_type, language, channel)
		table.insert(env.chat, { text = text, chat_type = chat_type, language = language, channel = channel })
	end

	_G.SendSystemMessage = function(text)
		table.insert(env.system, text)
	end

	_G.RandomRoll = function(low, high)
		table.insert(env.random_rolls, { low = low, high = high })
	end

	_G.InitiateTrade = function(target)
		table.insert(env.trades, target)
	end

	_G.UnitName = function(unit)
		if unit == "player" then return env.player_name, nil end
		return nil
	end

	-- "Name-Realm" -> "Name" for every context except "none"
	_G.Ambiguate = function(full_name, context)
		if context == "none" then return full_name end
		return (full_name:gsub("%-.+$", ""))
	end

	_G.GetGuildInfo = function(unit)
		if unit == "player" and env.guild_name then return env.guild_name, "Member", 1 end
		return nil
	end

	-- Returns the channel's number, name and instance ID (0 for a custom
	-- channel), or 0 when not in that channel
	_G.GetChannelName = function(name)
		local number = env.channels[name]
		if number then return number, name, 0 end
		return 0
	end

	_G.LeaveChannelByName = function(name)
		env.channels[name] = nil
		table.insert(env.channels_left, name)
	end

	-- The addon joins its custom channel through the /join slash command
	_G.SlashCmdList = {
		JOIN = function(input)
			local name = input:match("^(%S+)")
			local number = FIRST_CUSTOM_CHANNEL
			for _, used in pairs(env.channels) do
				if used >= number then number = used + 1 end
			end
			env.channels[name] = number
		end,
	}

	_G.UIParent = UIStub.new("UIParent")

	_G.CreateFrame = function(frame_type, name)
		local frame = UIStub.new(name or frame_type)
		if name then _G[name] = frame end
		return frame
	end
end

return WowApi
