-- luacheck configuration (https://luacheck.readthedocs.io). Run it with scripts/lint.ps1.
-- Static analysis finds what the tests can't: leaked globals and unused
-- variables in code the tests never run.

std = "lua51c"
exclude_files = { "libs/" }

-- Looking for bugs, not style: whitespace and line length are left alone
max_line_length = false
ignore = { "61.", "62." }

-- WoW callbacks often receive arguments they don't need
unused_args = false

-- Created by the addon on purpose: the AceAddon objects, their SavedVariables
-- and the tables its files share (the same list as INTENDED in spec/globals_spec.lua)
globals = {
	"AztecGambling", "AGClient", "AztecGamblingDB", "AGClientDB", "AG_MESSAGES",
	"AG_HILO", "AG_MYSTERY", "AG_BIGTWOS", "AG_LILONES", "AG_INVERSE", "AG_ROULETTE",
	"AG_YAHTZEE", "AG_CURLING", "AG_COUNTDOWN", "AG_BLACKJACK",
}

-- The WoW API and libraries the addon uses
read_globals = {
	"LibStub", "CreateFrame", "UIParent", "GetTime", "SendChatMessage", "SendSystemMessage",
	"RandomRoll", "InitiateTrade", "UnitName", "Ambiguate", "GetGuildInfo", "GetChannelName",
	"LeaveChannelByName", "SlashCmdList",
}

-- The tests set up a fake game: they write WoW globals and stub math.random
files["spec/"] = {
	std = "+busted",
	globals = { "_G", "math", "RANDOM_ROLL_RESULT", "GAME_MODES" },
}
