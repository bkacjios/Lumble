function table.Count(t)
	local i = 0
	for k,v in pairs(t) do
		i = i + 1
	end
	return i
end

function table.Random(t)
	return t[math.random(1,#t)]
end

function table.Shuffle(t)
	local n = #t
	while n > 2 do
		-- n is now the last pertinent index
		local k = math.random(1, n) -- 1 <= k <= n
		-- Quick swap
		t[n], t[k] = t[k], t[n]
		n = n - 1
	end
end

function table.ShuffleInto(t)
	local r = {}
	while #t > 0 do
		table.insert(r, table.remove(t, math.random(#t)))
	end
	return r
end

function table.ShuffleCopy(t)
	local r = {}

	local keys = {}

	for key in pairs(t) do
		table.insert(keys, key)
	end

	while #keys > 0 do
		table.insert(r, t[table.remove(keys, math.random(#keys))])
	end
	return r
end

function table.GetKeys( tab )
	local keys = {}
	local id = 1

	for k, v in pairs( tab ) do
		keys[ id ] = k
		id = id + 1
	end

	return keys
end

function table.print( t, indent, done )
	done = done or {}
	indent = indent or 0
	local keys = table.GetKeys( t )

	table.sort( keys, function( a, b )
		if type(a) == "number" and type(b) == "number" then return a < b end
		return tostring( a ) < tostring( b )
	end )

	for i = 1, #keys do
		local key = keys[ i ]
		local value = t[ key ]
		io.stdout:write( string.rep( "\t", indent ) )

		if type(value) == "table" and not done[ value ] then
			done[ value ] = true
			io.stdout:write( tostring( key ) .. ":" .. "\n" )
			table.print( value, indent + 2, done )
			done[ value ] = nil
		else
			io.stdout:write( tostring( key ) .. "\t=\t" )
			io.stdout:write( tostring( value ) .. "\n" )
		end
	end

	io.stdout:flush()
end

do
	local function val_to_str(v, stack, scope)
		if type(v) == "string" then
			v = string.gsub(v, "\n", "\\n" )
			if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
				return "'" .. v .. "'"
			end
			return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
		else
			return type(v) == "table" and table.tostring(v, stack, scope) or tostring(v)
		end
	end

	local function key_to_str(k, stack, scope)
		if type(k) == "string" and string.match(k, "^[_%a][_%a%d]*$") then
			return k
		else
			return "[" .. val_to_str(k, stack, scope) .. "]"
		end
	end

	function table.tostring(tbl, stack, scope)
		stack = stack or {}
		scope = scope or 0

		if stack[tbl] then return error("circular reference") end

		stack[tbl] = true
		scope = scope + 1

		local result = "{\n"

		for k, v in pairs(tbl) do
			local tabs = string.rep("\t", scope)
			if type(v) == "table" then
				result = result .. tabs .. key_to_str(k, stack, scope) .. " = " .. table.tostring(v, stack, scope) .. "\n"
			else
				result = result .. tabs .. key_to_str(k, stack, scope) .. " = " .. val_to_str(v, stack, scope) .. "\n"
			end
		end

		scope = scope - 1
		stack[tbl] = nil

		return result .. string.rep("\t", scope) .. "}"
	end
end

function table.concatList(table, oxford)
	local str = ""
	local num = #table
	for i=1,num do
		if i < num then
			str = str .. table[i] .. ((oxford or i < num - 1) and ", " or " ")
		elseif i > 1 then
			str = str .. "and " .. table[i]
		else
			str = str .. table[i]
		end
	end
	return str
end

function table.min(t)
	local min = nil
	for k,v in pairs(t) do
		if not min or v < min then
			min = v
		end
	end
	return min
end

function table.max(t)
	local max = nil
	for k,v in pairs(t) do
		if not max or v > max then
			max = v
		end
	end
	return max
end

function table.average(t)
	local total = 0
	local count = 0

	for k,v in pairs(t) do
		total = total + v
		count = count + 1
	end
	return total / count
end