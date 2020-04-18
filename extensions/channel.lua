function ChannelPairs(t)
	local s = {}
	for n,c in pairs(t) do
		table.insert(s, c)
	end
	table.sort(s, function(a,b)
		return
			a:getParentID()<b:getParentID() or
			(a:getParentID()==b:getParentID() and a:getPosition()<b:getPosition()) or
			(a:getParentID()==b:getParentID() and a:getPosition()==b:getPosition() and a.name:lower()<b.name:lower())
	end)
	return pairs(s)
end