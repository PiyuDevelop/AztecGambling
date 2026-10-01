-- Minimal stand-ins for LibStub, the Ace3 libraries, LibDataBroker and
-- LibDBIcon, covering only what the addon uses. The real libraries need too
-- much of the game client to load outside it.
--
-- Callbacks get their arguments in the same order and shape as with the real
-- libraries, because the addon reads them by position (select(2, ...), ...):
--   events         method name: self[method](self, event, ...)   function: fn(event, ...)
--   addon messages method name: self[method](self, prefix, message, distribution, sender)
--   timers         method name: self[method](self, ...)          function: fn(...)
-- Each object keeps one handler per event: registering the same event again
-- replaces the first handler, as AceEvent does.
local UIStub = require("spec.support.ui_stub")

local AceStubs = {}

local function pack(...)
	return { n = select("#", ...), ... }
end

-- A library whose Embed copies its methods onto the addon, like the real ones
local function mixin(methods)
	return {
		Embed = function(_, target)
			for name, method in pairs(methods) do target[name] = method end
			return target
		end,
	}
end

-- Wraps a callback given as a method name or a function, with an optional
-- extra argument placed first, the way CallbackHandler does
local function bind(owner, callback, ...)
	local extra = pack(...)
	if type(callback) == "string" then
		return function(...)
			local method = owner[callback]
			assert(type(method) == "function", "no method named " .. callback)
			if extra.n > 0 then return method(owner, extra[1], ...) end
			return method(owner, ...)
		end
	end
	assert(type(callback) == "function", "callback must be a method name or a function")
	if extra.n > 0 then
		return function(...) return callback(extra[1], ...) end
	end
	return callback
end

-- Handler lists keyed by event, message or prefix, in registration order
local function register(registry, key, owner, handler)
	local list = registry[key]
	if list == nil then
		list = {}
		registry[key] = list
	end
	for _, entry in ipairs(list) do
		if entry.owner == owner then
			entry.handler = handler
			return
		end
	end
	table.insert(list, { owner = owner, handler = handler, active = true })
end

local function unregister(registry, key, owner)
	local list = registry[key]
	if list == nil then return end
	for index, entry in ipairs(list) do
		if entry.owner == owner then
			entry.active = false
			table.remove(list, index)
			return
		end
	end
end

local function unregister_all(registry, owner)
	for key in pairs(registry) do unregister(registry, key, owner) end
end

local function is_registered(registry, key, owner)
	for _, entry in ipairs(registry[key] or {}) do
		if owner == nil or entry.owner == owner then return true end
	end
	return false
end

-- Calls every handler registered for key. A handler removed by an earlier
-- one during the same dispatch isn't called. Returns how many were called.
local function dispatch(registry, key, ...)
	local snapshot = {}
	for index, entry in ipairs(registry[key] or {}) do snapshot[index] = entry end
	local called = 0
	for _, entry in ipairs(snapshot) do
		if entry.active then
			entry.handler(...)
			called = called + 1
		end
	end
	return called
end

local function apply_defaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then target[key] = {} end
			apply_defaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function AceStubs.install(env)
	env.addons = {}         -- name -> addon
	env.addon_order = {}    -- addons in creation order
	env.events = {}         -- game events: event -> handlers
	env.messages = {}       -- AceEvent internal messages: message -> handlers
	env.comm_handlers = {}  -- addon message prefix -> handlers
	env.comm_sent = {}      -- SendCommMessage calls: { sender, prefix, text, distribution, target }
	env.timer_owners = {}   -- timer handle -> addon
	env.prints = {}         -- Print calls: { addon, text }
	env.slash_commands = {} -- "ag" -> { owner, func }
	env.databases = {}      -- SavedVariables name -> db
	env.widgets = {}        -- AceGUI:Create calls: { type, widget }
	env.widget_types = {}   -- AceGUI:RegisterWidgetType calls: name -> { constructor, version }
	env.data_objects = {}   -- LibDataBroker objects: name -> data
	env.minimap_icons = {}  -- LibDBIcon buttons: name -> { data, db, shown }

	local libraries = {}

	local AceAddon = {}
	function AceAddon:NewAddon(name, ...)
		assert(env.addons[name] == nil, "addon already exists: " .. name)
		local addon = { name = name }
		addon.GetName = function(target) return target.name end
		for index = 1, select("#", ...) do
			_G.LibStub(select(index, ...)):Embed(addon)
		end
		env.addons[name] = addon
		table.insert(env.addon_order, addon)
		return addon
	end
	function AceAddon:GetAddon(name, silent)
		local addon = env.addons[name]
		if addon == nil and not silent then error("Cannot find an AceAddon '" .. tostring(name) .. "'.", 2) end
		return addon
	end
	libraries["AceAddon-3.0"] = AceAddon

	libraries["AceConsole-3.0"] = mixin({
		Print = function(self, ...)
			local parts = {}
			for index = 1, select("#", ...) do parts[index] = tostring((select(index, ...))) end
			table.insert(env.prints, { addon = self.name, text = table.concat(parts, " ") })
		end,
		RegisterChatCommand = function(self, command, func)
			env.slash_commands[command:lower()] = { owner = self, func = func }
			return true
		end,
	})

	libraries["AceEvent-3.0"] = mixin({
		RegisterEvent = function(self, event, callback, ...)
			register(env.events, event, self, bind(self, callback or event, ...))
		end,
		UnregisterEvent = function(self, event)
			unregister(env.events, event, self)
		end,
		UnregisterAllEvents = function(self)
			unregister_all(env.events, self)
		end,
		RegisterMessage = function(self, message, callback, ...)
			register(env.messages, message, self, bind(self, callback or message, ...))
		end,
		UnregisterMessage = function(self, message)
			unregister(env.messages, message, self)
		end,
		UnregisterAllMessages = function(self)
			unregister_all(env.messages, self)
		end,
		SendMessage = function(_, message, ...)
			dispatch(env.messages, message, message, ...)
		end,
	})

	libraries["AceComm-3.0"] = mixin({
		RegisterComm = function(self, prefix, method)
			register(env.comm_handlers, prefix, self, bind(self, method or "OnCommReceived"))
		end,
		UnregisterComm = function(self, prefix)
			unregister(env.comm_handlers, prefix, self)
		end,
		SendCommMessage = function(self, prefix, text, distribution, target)
			table.insert(env.comm_sent, { sender = self.name, prefix = prefix, text = text, distribution = distribution, target = target })
		end,
	})

	local function schedule(owner, callback, delay, repeating, ...)
		local args = pack(...)
		local run
		if type(callback) == "string" then
			assert(type(owner[callback]) == "function", "no method named " .. callback)
			run = function() owner[callback](owner, unpack(args, 1, args.n)) end
		else
			run = function() callback(unpack(args, 1, args.n)) end
		end
		local handle = env.clock:schedule(delay, run, repeating)
		env.timer_owners[handle] = owner
		return handle
	end

	libraries["AceTimer-3.0"] = mixin({
		ScheduleTimer = function(self, callback, delay, ...)
			return schedule(self, callback, delay, false, ...)
		end,
		ScheduleRepeatingTimer = function(self, callback, delay, ...)
			return schedule(self, callback, delay, true, ...)
		end,
		CancelTimer = function(_, handle)
			if handle == nil then return false end
			env.timer_owners[handle] = nil
			return env.clock:cancel(handle)
		end,
		CancelAllTimers = function(self)
			for handle, owner in pairs(env.timer_owners) do
				if owner == self then
					env.timer_owners[handle] = nil
					env.clock:cancel(handle)
				end
			end
		end,
		TimeLeft = function(_, handle)
			return env.clock:time_left(handle)
		end,
	})

	-- Listed in NewAddon but never called by the addon
	libraries["AceHook-3.0"] = mixin({})
	libraries["AceSerializer-3.0"] = mixin({})

	-- SavedVariables live in globals, as in the game: a test can set one before
	-- loading to simulate a previous session. Defaults fill in what's missing.
	libraries["AceDB-3.0"] = {
		New = function(_, saved_variable, defaults)
			local saved = _G[saved_variable]
			if type(saved) ~= "table" then
				saved = {}
				_G[saved_variable] = saved
			end
			local db = { sv = saved }
			for _, section in ipairs({ "global", "profile" }) do
				saved[section] = saved[section] or {}
				if defaults and defaults[section] then apply_defaults(saved[section], defaults[section]) end
				db[section] = saved[section]
			end
			env.databases[saved_variable] = db
			return db
		end,
	}

	libraries["AceGUI-3.0"] = {
		Create = function(_, widget_type)
			local widget = UIStub.new(widget_type)
			table.insert(env.widgets, { type = widget_type, widget = widget })
			return widget
		end,
		RegisterWidgetType = function(_, name, constructor, version)
			env.widget_types[name] = { constructor = constructor, version = version }
		end,
		GetWidgetVersion = function(_, name)
			return env.widget_types[name] and env.widget_types[name].version
		end,
		RegisterAsWidget = function(_, widget)
			return widget
		end,
		Release = function() end,
	}

	libraries["LibDataBroker-1.1"] = {
		NewDataObject = function(_, name, data)
			env.data_objects[name] = data
			return data
		end,
	}

	libraries["LibDBIcon-1.0"] = {
		Register = function(_, name, data, db)
			env.minimap_icons[name] = { data = data, db = db, shown = not (db and db.hide) }
		end,
		Show = function(_, name) env.minimap_icons[name].shown = true end,
		Hide = function(_, name) env.minimap_icons[name].shown = false end,
		IsRegistered = function(_, name) return env.minimap_icons[name] ~= nil end,
	}

	_G.LibStub = setmetatable({ libs = libraries }, {
		__call = function(_, major, silent)
			local library = libraries[major]
			if library == nil and not silent then error("Cannot find a library instance of " .. tostring(major) .. ".", 2) end
			return library
		end,
	})

	-- What the game would do: fire an event, deliver an addon message, run a slash command

	-- Fires a game event, e.g. env.fire_event("CHAT_MSG_PARTY", "1", "Jayred").
	-- Returns how many handlers got it.
	function env.fire_event(event, ...)
		return dispatch(env.events, event, event, ...)
	end

	function env.deliver_comm(prefix, text, distribution, sender)
		return dispatch(env.comm_handlers, prefix, prefix, text, distribution, sender)
	end

	-- env.run_slash("ag", "ban Jayred") is the same as typing /ag ban Jayred
	function env.run_slash(command, input)
		local entry = env.slash_commands[command:lower()]
		assert(entry, "no slash command /" .. command)
		if type(entry.func) == "string" then
			return entry.owner[entry.func](entry.owner, input or "")
		end
		return entry.func(input or "")
	end

	function env.is_event_registered(event, owner)
		return is_registered(env.events, event, owner)
	end

	function env.is_comm_registered(prefix, owner)
		return is_registered(env.comm_handlers, prefix, owner)
	end

	function env.addon_names()
		local names = {}
		for index, addon in ipairs(env.addon_order) do names[index] = addon.name end
		return names
	end
end

return AceStubs
