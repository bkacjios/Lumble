local channel = {}
channel.__index = channel

local packet = require("lumble.packet")

function channel.new(client, packet)
	return setmetatable({
		client				= client,
		channel_id			= packet.channel_id,
		parent				= packet.parent,
		name				= packet.name,
		links				= packet.links,
		description			= packet.description,
		temporary			= packet.temporary,
		position			= packet.position,
		description_hash	= packet.description_hash,
		max_users			= packet.max_users,
	}, channel)
end

function channel:__tostring()
	return ("Channel [%s][%d]"):format(self.name, self.channel_id)
end

function channel:__call(path)
	return self:get(path)
end

function channel:update(packet, key)
	if packet[key] ~= nil and packet[key] ~= self[key] then
		self[key] = packet[key]
	end
end

function channel:updateAll(packet)
	self:update(packet, "channel_id")
	self:update(packet, "parent")
	self:update(packet, "name")
	self:update(packet, "links")
	self:update(packet, "description")
	self:update(packet, "temporary")
	self:update(packet, "position")
	self:update(packet, "description_hash")
	self:update(packet, "max_users")
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

function channel:send(packet)
	return self.client:send(packet)
end

function channel:message(text)
	local msg = packet.new("TextMessage")
	msg:add("channel_id", self.channel_id)
	msg:set("message", text)
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

function channel:hasPermission(flag)
	return self.client:hasPermission(self, flag)
end

return channel