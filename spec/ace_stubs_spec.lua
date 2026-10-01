-- The Ace3 stand-ins have to call the addon back exactly like the real
-- libraries, because the addon reads callback arguments by position.
local loader = require("spec.support.loader")

describe("the Ace3 stand-ins", function()
	local env, addon

	before_each(function()
		env = loader.stubs_only()
		addon = LibStub("AceAddon-3.0"):NewAddon("TestAddon", "AceConsole-3.0", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0")
	end)

	describe("events", function()
		it("call a function handler with the event name first", function()
			local received
			addon:RegisterEvent("CHAT_MSG_PARTY", function(...) received = { ... } end)
			env.fire_event("CHAT_MSG_PARTY", "1", "Jayred")
			assert.are.same({ "CHAT_MSG_PARTY", "1", "Jayred" }, received)
		end)

		it("call a method handler with self, then the event name", function()
			local received
			function addon:OnRoll(...) received = { self = self, args = { ... } } end
			addon:RegisterEvent("CHAT_MSG_SYSTEM", "OnRoll")
			env.fire_event("CHAT_MSG_SYSTEM", "Jayred rolls 57 (1-100)")
			assert.are.equal(addon, received.self)
			assert.are.same({ "CHAT_MSG_SYSTEM", "Jayred rolls 57 (1-100)" }, received.args)
		end)

		it("keep only the last handler when one object registers the same event twice", function()
			local calls = {}
			addon:RegisterEvent("PLAYER_LEAVING_WORLD", function() table.insert(calls, "first") end)
			addon:RegisterEvent("PLAYER_LEAVING_WORLD", function() table.insert(calls, "second") end)
			env.fire_event("PLAYER_LEAVING_WORLD")
			assert.are.same({ "second" }, calls)
		end)

		it("reach every object listening to the same event", function()
			local other = LibStub("AceAddon-3.0"):NewAddon("OtherAddon", "AceEvent-3.0")
			local count = 0
			addon:RegisterEvent("CHAT_MSG_SYSTEM", function() count = count + 1 end)
			other:RegisterEvent("CHAT_MSG_SYSTEM", function() count = count + 1 end)
			assert.are.equal(2, env.fire_event("CHAT_MSG_SYSTEM", "text"))
			assert.are.equal(2, count)
		end)

		it("stop arriving once unregistered", function()
			local count = 0
			addon:RegisterEvent("CHAT_MSG_SAY", function() count = count + 1 end)
			addon:UnregisterEvent("CHAT_MSG_SAY")
			assert.are.equal(0, env.fire_event("CHAT_MSG_SAY", "1", "Jayred"))
			assert.is_false(env.is_event_registered("CHAT_MSG_SAY", addon))
		end)
	end)

	describe("addon messages", function()
		it("call the handler with prefix, message, distribution and sender", function()
			local received
			function addon:OnNewGame(...) received = { ... } end
			addon:RegisterComm("AG_NEW_GAME", "OnNewGame")
			env.deliver_comm("AG_NEW_GAME", "1 100 100 PARTY", "PARTY", "Host")
			assert.are.same({ "AG_NEW_GAME", "1 100 100 PARTY", "PARTY", "Host" }, received)
		end)

		it("record what is sent", function()
			addon:SendCommMessage("AG_END_GAME", "Jayred Piyu 43", "PARTY", "nil")
			assert.are.same({ sender = "TestAddon", prefix = "AG_END_GAME", text = "Jayred Piyu 43", distribution = "PARTY", target = "nil" }, env.comm_sent[1])
		end)
	end)

	describe("timers", function()
		it("call a method by name with its arguments when the fake clock reaches them", function()
			local received
			function addon:TimedStart(...) received = { n = select("#", ...), ... } end
			addon:ScheduleTimer("TimedStart", 10, "a", nil, "c")
			env.clock:advance(9)
			assert.is_nil(received)
			env.clock:advance(1)
			assert.are.same({ n = 3, "a", nil, "c" }, received)
		end)

		it("fail right away when the method doesn't exist", function()
			assert.has_error(function() addon:ScheduleTimer("NoSuchMethod", 1) end)
		end)

		it("cancel only the object's own timers with CancelAllTimers", function()
			local other = LibStub("AceAddon-3.0"):NewAddon("OtherAddon", "AceTimer-3.0")
			local ran = {}
			addon:ScheduleTimer(function() table.insert(ran, "mine") end, 5)
			other:ScheduleTimer(function() table.insert(ran, "other") end, 5)
			addon:CancelAllTimers()
			env.clock:advance(5)
			assert.are.same({ "other" }, ran)
		end)
	end)

	describe("slash commands and printing", function()
		it("run a method registered by name with the typed input", function()
			local received
			function addon:Handler(input) received = input end
			addon:RegisterChatCommand("ag", "Handler")
			env.run_slash("ag", "ban Jayred")
			assert.are.equal("ban Jayred", received)
		end)

		it("record printed lines with the addon's name", function()
			addon:Print("Unrecognized AG Slash Command:", 42)
			assert.are.same({ addon = "TestAddon", text = "Unrecognized AG Slash Command: 42" }, env.prints[1])
		end)
	end)

	describe("AceDB", function()
		it("fills in defaults without overwriting saved values", function()
			_G.TestDB = { global = { chat_index = 3, minimap = { hide = true } } }
			local db = LibStub("AceDB-3.0"):New("TestDB", { global = { chat_index = 1, rankings = {}, minimap = { hide = false } } })
			assert.are.equal(3, db.global.chat_index)
			assert.is_true(db.global.minimap.hide)
			assert.are.same({}, db.global.rankings)
			assert.are.equal(_G.TestDB.global, db.global)
		end)
	end)
end)
