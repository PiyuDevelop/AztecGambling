-- Stand-in for AceGUI widgets and native frames. It accepts any field or
-- method call, including nested ones such as widget.frame:SetAlpha(1), and
-- records every call so tests can check what the addon asked the UI to do.
--
-- Calls return nil, except the getters in DEFAULT_RETURNS. A test can replace
-- any method on a widget:
--   host.ui.gold_amount_entry.GetText = function() return "500" end
local UIStub = {}

-- What an untouched widget's getters return: an empty text box and a frame
-- with no size, so the addon's arithmetic on them still works
local DEFAULT_RETURNS = {
	GetText = "",
	GetWidth = 0,
	GetHeight = 0,
}

-- stub -> { name, parent, calls }. Kept outside the stubs, because any field
-- looked up on a stub becomes a new child stub.
local info = setmetatable({}, { __mode = "k" })

local metatable = {
	__index = function(stub, key)
		local child = UIStub.new(key, stub)
		rawset(stub, key, child)
		return child
	end,

	__call = function(stub, ...)
		local data = info[stub]
		local args = { n = select("#", ...), ... }
		-- Called as a method (parent:Method(...)): leave the parent out of the record
		if args.n > 0 and args[1] == data.parent then
			args = { n = args.n - 1, select(2, ...) }
		end
		table.insert(data.calls, args)
		return DEFAULT_RETURNS[data.name]
	end,

	__tostring = function(stub)
		return "UIStub(" .. tostring(info[stub] and info[stub].name) .. ")"
	end,
}

function UIStub.new(name, parent)
	local stub = setmetatable({}, metatable)
	info[stub] = { name = name or "widget", parent = parent, calls = {} }
	return stub
end

function UIStub.is_stub(value)
	return info[value] ~= nil
end

-- Every call made to widget:<method>(...), oldest first. Each entry holds the
-- arguments (without the widget itself) and their count in .n
function UIStub.calls(widget, method)
	local method_stub = rawget(widget, method)
	local data = method_stub and info[method_stub]
	return data and data.calls or {}
end

function UIStub.last_call(widget, method)
	local calls = UIStub.calls(widget, method)
	return calls[#calls]
end

return UIStub
