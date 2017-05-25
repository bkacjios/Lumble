local channel = {}
channel.__index = channel

local packet = require("lumble.packet")

function channel.new(client, packet)
	local channel = setmetatable({
		client = client
	}, channel)

	channel:update(packet)

	return channel
end

function channel:update(packet)
	for desc, value in packet:list() do
		local name = desc.name
		if self[name] ~= value then
			self[name] = value
		end
	end
end

function channel:__tostring()
	return ("channel[%d][%s]"):format(self.channel_id, self.name)
end

function channel:__call(path)
	return self:get(path)
end

function channel:get(path)
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
		if self.channel_id == channel.parent then
			children[channel.channel_id] = channel
		end
	end
	return children
end

function channel:getClient()
	return self.client
end

function channel:send(packet)
	return self.client:send(packet)
end

function channel:message(text, ...)
	local msg = packet.new("TextMessage")
	msg:add("channel_id", self.channel_id)
	msg:set("message", text:format(...))
	self:send(msg)
end

function channel:setDescription(desc)
	local msg = packet.new("ChannelState")
	msg:set("channel_id", self.channel_id)
	msg:set("description", desc)
	self:send(msg)
end

function channel:remove()
	local msg = packet.new("ChannelRemove")
	msg:set("channel_id", self.channel_id)
	self:send(msg)
end

function channel:getID()
	return self.channel_id
end

function channel:getParent()
	return self.client.channels[self.parent or 0]
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

function channel:hasPermission(flag)
	return self.client:hasPermission(self, flag)
end

return channel