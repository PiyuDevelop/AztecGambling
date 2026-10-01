-- Global variables the addon leaves behind. A variable assigned without
-- `local` becomes a game-wide global that can clash with other addons
-- (bug #8 in docs/improvements.md). After running as much of the addon as
-- possible, every global it created has to be on one of the two lists below.
local loader = require("spec.support.loader")
local helpers = require("spec.support.helpers")
local exercise = require("spec.support.exercise")

-- Created on purpose: the two AceAddon objects, their SavedVariables, and
-- the tables the addon's files share with each other
local INTENDED = {
	"AztecGambling", "AGClient", "AztecGamblingDB", "AGClientDB", "AG_MESSAGES",
	"AG_HILO", "AG_MYSTERY", "AG_BIGTWOS", "AG_LILONES", "AG_INVERSE", "AG_ROULETTE",
	"AG_YAHTZEE", "AG_CURLING", "AG_COUNTDOWN", "AG_BLACKJACK",
}

-- Bug #8: leaked by mistake. Remove each name once its `local` is fixed. A
-- new leak fails the first test; a name here that no longer leaks fails the
-- second, so the list stays accurate until it's empty.
local KNOWN_LEAKS = {
	"GAME_MODES", "GAME_STAGES", "on_mouse_down", "label", "tiebreaker_list", "player_score",
	"total", "hand", "score", "highroll", "new_score",
	"command", "command_args", "player",
	"guildName", "guildRankName", "guildRankIndex", "channel_name", "channel_number", "channel_string", "instanceID",
}

local function as_set(list)
	local set = {}
	for _, name in ipairs(list) do set[name] = true end
	return set
end

describe("global variables", function()
	local created

	setup(function()
		local env = loader.load({ guild_name = "Aztec Tribe" })
		exercise.everything(env, helpers.new(env))
		created = as_set(loader.addon_globals(env))
	end)

	it("are only the intended ones and the known leaks", function()
		local allowed = as_set(INTENDED)
		for name in pairs(as_set(KNOWN_LEAKS)) do allowed[name] = true end
		local unexpected = {}
		for name in pairs(created) do
			if not allowed[name] then table.insert(unexpected, name) end
		end
		table.sort(unexpected)
		assert.are.same({}, unexpected, "new globals leaked: add `local`, or list them if they're on purpose")
	end)

	it("still include every known leak (remove the fixed ones from the list)", function()
		local fixed = {}
		for _, name in ipairs(KNOWN_LEAKS) do
			if not created[name] then table.insert(fixed, name) end
		end
		assert.are.same({}, fixed, "these no longer leak: remove them from KNOWN_LEAKS")
	end)

	it("include every intended one", function()
		local missing = {}
		for _, name in ipairs(INTENDED) do
			if not created[name] then table.insert(missing, name) end
		end
		assert.are.same({}, missing)
	end)
end)
