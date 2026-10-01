-- The /ag slash commands, the window toggling they share with the minimap
-- button, and the custom gambling channel.
local loader = require("spec.support.loader")
local known_bug = require("spec.support.known_bug")

describe("/ag", function()
	local env

	before_each(function()
		env = loader.load()
	end)

	local function prints()
		local texts = {}
		for index, line in ipairs(env.prints) do texts[index] = line.text end
		return texts
	end

	local function printed(text)
		for _, line in ipairs(prints()) do
			if line:find(text, 1, true) then return true end
		end
		return false
	end

	describe("ban list", function()
		it("bans and unbans a player", function()
			env.run_slash("ag", "ban Zed")
			assert.is_true(AztecGambling.db.global.ban_list.Zed)
			env.run_slash("ag", "unban Zed")
			assert.is_nil(AztecGambling.db.global.ban_list.Zed)
		end)

		it("clears every ban with resetBans", function()
			env.run_slash("ag", "ban Zed")
			env.run_slash("ag", "ban Kal")
			env.run_slash("ag", "resetBans")
			assert.are.same({}, AztecGambling.db.global.ban_list)
		end)
	end)

	describe("stats", function()
		it("posts the Hall of Fame and the Hall of Shame in chat, leaving out players who broke even", function()
			AztecGambling.db.global.rankings = { Jayred = 500, Piyu = -300, Zed = 200, Kal = 0 }
			env.run_slash("ag", "stats")
			local texts = {}
			for index, message in ipairs(env.chat) do texts[index] = message.text end
			assert.are.same({
				"Hall of Fame: ",
				"1. Jayred won 500 gold.",
				"2. Zed won 200 gold.",
				"~~~~~~",
				"Hall of Shame: ",
				"1. Piyu lost 300 gold.",
			}, texts)
		end)

		it("clears the rankings with resetStats", function()
			AztecGambling.db.global.rankings = { Jayred = 500 }
			env.run_slash("ag", "resetStats")
			assert.are.same({}, AztecGambling.db.global.rankings)
		end)
	end)

	describe("settings", function()
		it("turns the companion window's auto-show off and back on with auto", function()
			env.run_slash("ag", "auto")
			assert.is_false(AGClient.db.global.auto_pop)
			assert.is_true(printed("Disabled auto show of rolling UI."))

			env.run_slash("ag", "auto")
			assert.is_true(AGClient.db.global.auto_pop)
			assert.is_true(printed("Enabled auto show of rolling UI."))
		end)

		it("turns debug messages on with debug", function()
			env.run_slash("ag", "debug")
			AztecGambling:PrintDebug("checking")
			assert.is_true(printed("[AG_DEBUG] checking"))
		end)
	end)

	describe("help", function()
		it("lists the commands with help", function()
			env.run_slash("ag", "help")
			assert.is_true(printed("Aztec Gambling Slash Commands:"))
			assert.is_true(printed("ban <player>"))
		end)

		it("points to help after an unknown command", function()
			env.run_slash("ag", "dance")
			assert.is_true(printed("Unrecognized AG Slash Command:"))
			assert.is_true(printed("Use /ag help for more information."))
		end)
	end)

	describe("windows", function()
		local function shown()
			return { client = AGClient.db.global.window_shown, casino = AztecGambling.db.global.window_shown }
		end

		it("cycles companion window, casino and hidden with /ag alone", function()
			env.run_slash("ag", "")
			assert.are.same({ client = true, casino = false }, shown())
			env.run_slash("ag", "")
			assert.are.same({ client = false, casino = true }, shown())
			env.run_slash("ag", "")
			assert.are.same({ client = false, casino = false }, shown())
		end)

		it("opens the casino with /agm", function()
			env.run_slash("agm", "")
			assert.is_true(AztecGambling.db.global.window_shown)
		end)

		it("saves the casino window's position on the way out of the world", function()
			env.fire_event("PLAYER_LEAVING_WORLD")
			assert.is_table(AztecGambling.db.global.ui_frame)
		end)
	end)

	describe("custom gambling channel", function()
		it("joins a channel by name with join, and leaves it with leave", function()
			env.run_slash("ag", "join AztecNight")
			assert.are.same({ index = env.channels.AztecNight, name = "AztecNight" }, AztecGambling.db.global.custom_channel)
			assert.is_number(env.channels.AztecNight)

			env.run_slash("ag", "leave")
			assert.are.same({ "AztecNight" }, env.channels_left)
			assert.are.same({ name = "" }, AztecGambling.db.global.custom_channel)
		end)

		it("names the channel after the guild when no name is given", function()
			env = loader.load({ guild_name = "Aztec Tribe" })
			env.run_slash("ag", "join")
			assert.are.equal("AztecTribeGambling", AztecGambling.db.global.custom_channel.name)
		end)

		-- Bug #7 in docs/improvements.md
		known_bug("doesn't fail for a player without a guild (bug #7)", function()
			assert.has_no.errors(function() env.run_slash("ag", "join") end)
		end)

		known_bug("stays in the channel through loading screens, leaving it only on logout (bug #7)", function()
			env.run_slash("ag", "join AztecNight")
			env.fire_event("PLAYER_LEAVING_WORLD")
			assert.are.same({}, env.channels_left)
			env.fire_event("PLAYER_LOGOUT")
			assert.are.same({ "AztecNight" }, env.channels_left)
		end)

		-- Bug #12 in docs/improvements.md
		known_bug("keeps saving the casino window's position after joining (bug #12)", function()
			env.run_slash("ag", "join AztecNight")
			env.fire_event("PLAYER_LEAVING_WORLD")
			assert.is_table(AztecGambling.db.global.ui_frame)
		end)
	end)
end)
