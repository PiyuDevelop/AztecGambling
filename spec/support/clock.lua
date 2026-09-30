-- Fake clock for tests. GetTime() reads it, and timers (the AceTimer stand-in)
-- only run when a test moves the clock forward with advance(), so a 45-second
-- roll phase takes no real time.
local Clock = {}
Clock.__index = Clock

function Clock.new()
	return setmetatable({ now = 0, timers = {}, next_id = 0 }, Clock)
end

function Clock:time()
	return self.now
end

-- Queues fn to run once delay seconds from now, or every delay seconds when
-- repeating. Returns a handle for cancel() and time_left().
function Clock:schedule(delay, fn, repeating)
	assert(type(delay) == "number" and delay >= 0, "timer delay must be a number >= 0")
	assert(not repeating or delay > 0, "a repeating timer needs a delay > 0")
	self.next_id = self.next_id + 1
	self.timers[self.next_id] = { id = self.next_id, due = self.now + delay, delay = delay, fn = fn, repeating = repeating }
	return self.next_id
end

-- Returns true when the timer was still pending
function Clock:cancel(id)
	if self.timers[id] == nil then return false end
	self.timers[id] = nil
	return true
end

function Clock:time_left(id)
	local timer = self.timers[id]
	return timer and (timer.due - self.now) or 0
end

function Clock:pending_count()
	local count = 0
	for _ in pairs(self.timers) do count = count + 1 end
	return count
end

-- The earliest timer due by limit; timers due at the same moment run in the
-- order they were scheduled
local function next_due(self, limit)
	local best
	for _, timer in pairs(self.timers) do
		if timer.due <= limit and (best == nil or timer.due < best.due or (timer.due == best.due and timer.id < best.id)) then
			best = timer
		end
	end
	return best
end

-- Moves the clock forward, running every timer that comes due on the way.
-- The clock reads each timer's due time while it runs, and timers scheduled
-- along the way also run if they come due before the end.
function Clock:advance(seconds)
	local target = self.now + seconds
	while true do
		local timer = next_due(self, target)
		if timer == nil then break end
		self.now = timer.due
		if timer.repeating then
			timer.due = timer.due + timer.delay
		else
			self.timers[timer.id] = nil
		end
		timer.fn()
	end
	self.now = target
end

return Clock
