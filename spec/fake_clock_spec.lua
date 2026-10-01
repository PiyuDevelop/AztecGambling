-- The fake clock behind GetTime() and the timers. Every roll time limit test
-- depends on it, so its own behavior is checked here.
local Clock = require("spec.support.clock")

describe("the fake clock", function()
	local clock, ran

	before_each(function()
		clock = Clock.new()
		ran = {}
	end)

	local function record(label)
		return function() table.insert(ran, { label = label, at = clock:time() }) end
	end

	it("starts at 0 and only moves when advanced", function()
		assert.are.equal(0, clock:time())
		clock:advance(2.5)
		assert.are.equal(2.5, clock:time())
	end)

	it("runs a timer when it comes due, not before", function()
		clock:schedule(10, record("timer"))
		clock:advance(9.9)
		assert.are.equal(0, #ran)
		clock:advance(0.1)
		assert.are.equal(1, #ran)
	end)

	it("runs due timers in order, with the clock at each one's due time", function()
		clock:schedule(30, record("second"))
		clock:schedule(10, record("first"))
		clock:advance(60)
		assert.are.same({ { label = "first", at = 10 }, { label = "second", at = 30 } }, ran)
		assert.are.equal(60, clock:time())
	end)

	it("runs timers due at the same moment in the order they were scheduled", function()
		clock:schedule(5, record("a"))
		clock:schedule(5, record("b"))
		clock:advance(5)
		assert.are.same({ "a", "b" }, { ran[1].label, ran[2].label })
	end)

	it("repeats a repeating timer until it's cancelled", function()
		local handle = clock:schedule(1, record("tick"), true)
		clock:advance(3)
		assert.are.equal(3, #ran)
		assert.is_true(clock:cancel(handle))
		clock:advance(3)
		assert.are.equal(3, #ran)
	end)

	it("never runs a cancelled timer", function()
		local handle = clock:schedule(5, record("timer"))
		assert.is_true(clock:cancel(handle))
		assert.is_false(clock:cancel(handle))
		clock:advance(10)
		assert.are.equal(0, #ran)
	end)

	it("runs a timer scheduled by another one if it comes due in the same advance", function()
		clock:schedule(5, function()
			record("first")()
			clock:schedule(2, record("second"))
		end)
		clock:advance(10)
		assert.are.same({ { label = "first", at = 5 }, { label = "second", at = 7 } }, ran)
	end)

	it("reports the time left on a timer", function()
		local handle = clock:schedule(45, record("timer"))
		clock:advance(40)
		assert.are.equal(5, clock:time_left(handle))
		assert.are.equal(1, clock:pending_count())
	end)
end)
