-- Loads the addon outside the game: installs the stand-ins, runs the addon's
-- files in .toc order, then calls OnInitialize (and OnEnable, if defined) on
-- each addon, as the game does when the addon loads.
--
--   local env = loader.load()   -- fresh addon, database, clock and logs
--   env.clock:advance(10)
--   env.chat                    -- what was sent to chat
--
-- Every load starts clean: globals left by a previous load are removed first.
local Clock = require("spec.support.clock")
local WowApi = require("spec.support.wow_api")
local AceStubs = require("spec.support.ace_stubs")

local Loader = {}

local ADDON_NAME = "AztecGambling"
local DEFAULT_TOC = "AztecGambling.toc"

-- Globals that exist before any load (Lua's own and busted's). Anything else
-- was left by the addon or the stand-ins, and gets removed before the next load.
local baseline = {}
for name in pairs(_G) do baseline[name] = true end

local function reset_globals()
	for name in pairs(_G) do
		if not baseline[name] then _G[name] = nil end
	end
end

-- The addon's own .lua files listed in a .toc, in order (libraries left out)
function Loader.addon_files(toc)
	local files = {}
	for line in io.lines(toc or DEFAULT_TOC) do
		line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
		local is_file = line ~= "" and not line:match("^#")
		if is_file and line:match("%.lua$") and not line:match("^libs[\\/]") then
			table.insert(files, (line:gsub("\\", "/")))
		end
	end
	return files
end

-- The stand-ins alone, without the addon: for testing the stand-ins themselves.
-- opts.player_name: the logged-in character (default "Host")
function Loader.stubs_only(opts)
	opts = opts or {}
	reset_globals()
	local env = { clock = Clock.new(), player_name = opts.player_name }
	WowApi.install(env)
	AceStubs.install(env)
	return env
end

-- opts.player_name: the logged-in character (default "Host")
-- opts.saved: SavedVariables from a previous session, e.g.
--   { AztecGamblingDB = { global = { game_mode_index = 8 } } }
function Loader.load(opts)
	opts = opts or {}
	local env = Loader.stubs_only(opts)

	for name, data in pairs(opts.saved or {}) do
		_G[name] = data
	end

	-- In the game, every file of an addon receives its name and a table shared by all of them
	local shared = {}
	for _, file in ipairs(Loader.addon_files()) do
		local chunk = assert(loadfile(file))
		chunk(ADDON_NAME, shared)
	end

	for _, addon in ipairs(env.addon_order) do
		if addon.OnInitialize then addon:OnInitialize() end
	end
	for _, addon in ipairs(env.addon_order) do
		if addon.OnEnable then addon:OnEnable() end
	end

	env.host = _G.AztecGambling
	env.client = _G.AGClient
	return env
end

return Loader
