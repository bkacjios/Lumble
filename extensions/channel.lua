function ChannelPairs(t)
	local s = {}
	for n,c in pairs(t) do
		table.insert(s, c)
	end
	table.sort(s, function(a,b)
		if a:getPosition() ~= b:getPosition() then
			return a:getPosition() < b:getPosition()
		end
		return a:getName():lower() < b:getName():lower()
	end)
	return pairs(s)
end