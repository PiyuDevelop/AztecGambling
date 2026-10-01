-- Smoke tests: the whole addon loads outside the game and starts in the
-- state a player sees when logging in.
local loader = require("spec.support.loader")

describe("loading the addon", function()
	local env

	before_each(function()
		env = loader.load()
	end)

	it("creates the host and companion addons, in .toc order", function()
		assert.is_table(AztecGambling)
		assert.is_table(AGClient)
		assert.are.same({ "AztecGambling", "AGClient" }, env.addon_names())
	end)

	it("registers the /ag and /agm slash commands", function()
		assert.are.equal(AztecGambling, env.slash_commands.ag.owner)
		assert.are.equal("SlashCommandHandler", env.slash_commands.ag.func)
		assert.are.equal("ShowUI", env.slash_commands.agm.func)
	end)

	it("creates both databases with their default values", function()
		local host = AztecGambling.db.global
		assert.are.same({}, host.rankings)
		assert.are.same({}, host.ban_list)
		assert.are.equal(1, host.chat_index)
		assert.are.equal(1, host.game_mode_index)
		assert.is_false(host.window_shown)
		assert.is_false(host.minimap.hide)
		assert.are.equal(AztecGamblingDB.global, host)

		assert.is_true(AGClient.db.global.auto_pop)
		assert.is_false(AGClient.db.global.window_shown)
		assert.are.equal(AGClientDB.global, AGClient.db.global)
	end)

	it("starts with no round in progress, in HiLo mode, on Raid chat, at the New Game stage", function()
		assert.is_nil(AztecGambling.game.data)
		assert.are.equal("HiLo", AztecGambling.game.mode.label)
		assert.are.equal("Raid", AztecGambling.chat.channel.label)
		assert.are.equal("NewGame", AztecGambling.game.stage.label)
	end)

	it("restores the chat channel and game mode saved in the last session", function()
		env = loader.load({ saved = { AztecGamblingDB = { global = { chat_index = 2, game_mode_index = 8 } } } })
		assert.are.equal("Party", AztecGambling.chat.channel.label)
		assert.are.equal("Blackjack", AztecGambling.game.mode.label)
		assert.are.same({}, AztecGambling.db.global.rankings)
	end)

	it("registers the minimap button with its saved visibility", function()
		local icon = env.minimap_icons.AztecGamblingIcon
		assert.is_table(icon)
		assert.are.equal(AztecGambling.db.global.minimap, icon.db)
		assert.are.equal("Interface\\Icons\\INV_Misc_Coin_02", icon.data.icon)
	end)

	it("has the companion window listen for the host's addon messages and for rolls", function()
		for _, prefix in ipairs({ "AG_NEW_GAME", "AG_END_GAME", "AG_GUILD_ROLL", "AG_TURN_UPDATE" }) do
			assert.is_true(env.is_comm_registered(prefix, AGClient), prefix)
		end
		assert.is_true(env.is_event_registered("CHAT_MSG_SYSTEM", AGClient))
	end)

	it("doesn't listen to chat or rolls on the host until a round starts", function()
		assert.is_false(env.is_event_registered("CHAT_MSG_SYSTEM", AztecGambling))
		assert.is_false(env.is_event_registered("CHAT_MSG_RAID", AztecGambling))
	end)

	it("sends nothing to chat or to other players while loading", function()
		assert.are.equal(0, #env.chat)
		assert.are.equal(0, #env.comm_sent)
	end)

	it("starts every load from a clean slate", function()
		local first_host = AztecGambling
		AztecGambling.db.global.rankings.Jayred = 500
		_G.left_over_by_a_test = true

		env = loader.load()

		assert.are_not.equal(first_host, AztecGambling)
		assert.are.same({}, AztecGambling.db.global.rankings)
		assert.is_nil(_G.left_over_by_a_test)
	end)
end)

describe("the .toc files", function()
	it("load the same addon files, in the same order, for every game version", function()
		local retail = loader.addon_files("AztecGambling.toc")
		assert.is_true(#retail > 0)
		assert.are.same(retail, loader.addon_files("AztecGambling_Vanilla.toc"))
		assert.are.same(retail, loader.addon_files("AztecGambling_Wrath.toc"))
	end)
end)
