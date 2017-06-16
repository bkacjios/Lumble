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