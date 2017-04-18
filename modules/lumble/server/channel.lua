local channel = {}
channel.__index = channel

local proto = require("lumble.proto")

function channel.new(server, name)
	return setmetatable({
		proto	= proto.ChannelState(),
		server	= server,
		name	= name,
	}, channel)
end

function channel:getState()
	return self.proto
end

function channel:__tostring()
	return ("Channel [%s][%d]"):format(self.name, self.channel_id)
end

function channel:__call(path)
	return self:get(path)
end

function channel:get(path)
	assert(self ~= nil, "self cannot be nil")

	if path == nil then
		return self
	end

	local channel = self

	for k in path:gmatch("([^/]+)") do
		local current
		if k == "." then
			current = channel
		elseif k == ".." then
			current = channel:getParent()
		else
			for id, chan in pairs(self.client.channels) do
				if chan.channel_id ~= chan.parent and chan.parent == channel.channel_id and k == chan.name then
					current = chan
				end
			end
		end
		if current == nil then
			return nil
		end
		channel = current
	end
	return channel
end

function channel:getUsers()
	local users = {}
	for session, user in pairs(self.client.users) do
		if self.channel_id == user.channel_id then
			users[user.session] = user
		end
	end
	return users
end

function channel:getChildren()
	local children = {}
	for id, channel in pairs(self.client.channels) do
		if self == channel.parent then
			children[channel.channel_id] = channel
		end
	end
	return children
end

function channel:getClient()
	return self.client
end

function channel:message(text)
	log.trace("[CLIENT] TextMessage [%d][channel]: %s", self.channel_id, text)

	local id, msg = self.client:packet("TextMessage")
	table.insert(msg.channel_id, self.channel_id)
	msg.message = text
	self.client:send(id, msg)
end

function channel:setDescription(desc)
	log.trace("[CLIENT] ChannelState [%d][description]: %s", self.channel_id, text)

	local id, msg = self.client:packet("ChannelState")
	msg.channel_id = self.channel_id
	msg.description = desc
	self.client:send(id, msg)
end

function channel:remove()
	log.trace("[CLIENT] ChannelRemove [%d]", self.channel_id)

	local id, msg = self.client:packet("ChannelRemove")
	msg.channel_id = self.channel_id
	self.client:send(id, msg)
end

function channel:getID()
	return self.channel_id
end

function channel:getParent()
	return self.client.channels[self.parent]
end

function channel:getName()
	return self.name
end

function channel:getLinks()
	return self.links
end

function channel:getDescription()
	return self.description
end

function channel:isTemporary()
	return self.temporary
end

function channel:getPosition()
	return self.position
end

function channel:getDescriptionHash()
	return self.description_hash
end

function channel:getMaxUsers()
	return self.max_users
end