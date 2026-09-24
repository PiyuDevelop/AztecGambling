
-- Util Functions -- Lua doesnt provide alot of basic functionality
-- =======================================================================
function AztecGambling:SplitString(str, pattern)
	local ret_list = {}
	local index = 1
	for token in string.gmatch(str, pattern) do
		ret_list[index] = token
		index = index + 1
	end
	return ret_list
end

function AztecGambling:CopyTable(T)
  local u = { }
  for k, v in pairs(T) do u[k] = v end
  return setmetatable(u, getmetatable(T))
end

function AztecGambling:TableLength(T)
  if (T == nil) then return 0 end
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function AztecGambling:PrintTable(T)
	for k, v in pairs(T) do
		AztecGambling:Print(k.."  "..v)
	end
end

function AztecGambling:sortedpairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function AztecGambling:deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[AztecGambling:deepcopy(orig_key)] = AztecGambling:deepcopy(orig_value)
        end
        setmetatable(copy, AztecGambling:deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end