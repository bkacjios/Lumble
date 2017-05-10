function UserPairsStatus(t)
	local s = {}
	for n,c in pairs(t) do
		table.insert(s, c)
	end
	table.sort(s, function(a,b)
		if a:getID() == b:getID() then
			return a:getSession() < b:getSession()
		elseif a:getID() <= 0 or b:getID() <= 0 then
			return a:getID() > b:getID()
		end
		return a:getID() < b:getID()
	end)
	return pairs(s)
end

function UserPairs(t)
	local s = {}
	for n,c in pairs(t) do
		table.insert(s, c)
	end
	table.sort(s, function(a,b)
		return a:getName():lower() < b:getName():lower()
	end)
	return pairs(s)
end