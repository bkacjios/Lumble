local event = {}

function event.new(instance, packet, all)
	local event = {}

	for desc, value in packet:list() do
		local name = desc.name
		local tp = type(value)

		if name == "session" then
			if tp == "table" then
				event["users"] = event["users"] or {}
				for i, session in ipairs(value) do
					table.insert(event["users"], instance:getUser(session))
				end
			else
				event["user"] = instance:getUser(value)
			end
		elseif name == "actor" then
			event["actor"] = instance:getUser(value)
		elseif name == "channel_id" then
			if tp == "table" then
				event["channels"] = event["channels"] or {}
				for i, channel_id in ipairs(value) do
					table.insert(event["channels"], instance:getChannel(channel_id))
				end
			else
				event["channel"] = instance:getChannel(value)
			end
		elseif all then
			event[name] = value
		end
	end

	return event
end

return event