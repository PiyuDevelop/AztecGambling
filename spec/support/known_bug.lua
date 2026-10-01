-- known_bug(description, test): a test for the correct behavior that fails
-- today because of a known bug. Normally it's reported as pending, like
-- busted's pending(), so the suite stays green.
--
-- With the environment variable AG_CHECK_KNOWN_BUGS=1, each known bug runs
-- instead and must fail. One that passes means the bug was fixed (turn it
-- into an it()) or the test doesn't reproduce the bug. CI runs both ways.
local luassert = require("luassert")

local CHECK = os.getenv("AG_CHECK_KNOWN_BUGS") == "1"

local FIXED_OR_WRONG = "this known bug's test passes now: if the bug was fixed, turn it into an it(); "
	.. "otherwise the test doesn't reproduce the bug"

return function(description, test)
	-- it() and pending() live in the spec file's environment, not in _G
	local spec_env = getfenv(2)
	local it, pending = spec_env.it or _G.it, spec_env.pending or _G.pending
	if not CHECK then
		return pending(description, test)
	end
	it(description .. " [known bug: must fail]", function()
		local passed = pcall(test)
		luassert.is_false(passed, FIXED_OR_WRONG)
	end)
end
