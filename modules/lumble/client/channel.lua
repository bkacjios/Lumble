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

	for match in path:gmatch("([^/]+)") do
		local current
		if match == "." then
			-- Stay within the current path
			current = channel
		elseif match == ".." then
			-- Go back a channel
			current = channel:getParent()
		elseif match == "~" then
			-- Go to the root channel
			current = self.client.channels[0]
		else
			for id, chan in pairs(self.client.channels) do
				-- Only match if the channel is a parent of the current channel and the names match.
				if chan.parent == channel.channel_id and match == chan.name then
					current = chan
					break
				end
			end
		end
		if current == nil then
			return nil, ("Unknown channel %q"):format(path)
		end
		channel = current
	end
	return channel
end

-- Return a table of all the users in this channel and the number of entries in the table
function channel:getUsers()
	local users = {}
	local num = 0
	for session, user in pairs(self.client.users) do
		if self.channel_id == user.channel_id then
			users[user.session] = user
			num = num + 1
		end
	end
	return users, num
end

-- Check to see if anyone is talking within the channel
function channel:isUserTalking()
	for session, user in pairs(self.client.users) do
		if user:isTalking() then
			return true
		end
	end
	return false
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
	text = text or ""
	text = text:format(...)
	if #text > self.client.config.message_length and self.client.config.message_length > 0 then
		-- If the text is longer than the server limit, ellipse it to fit within the bounds.
		text = string.ellipse(text, self.client.config.message_length)
	end
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

function channel:getParent(noroot)
	if noroot then
		return self.client.channels[self.parent]
	else
		return self.client.channels[self.parent or 0]
	end
end

function channel:getName()
	return self.name
end

function channel:getPath()
	local path = {self:getName()}

	local parent = self:getParent(true)

	while parent do
		if parent:getID() ~= 0 then
			table.insert(path, 1, parent:getName())
		end
		parent = parent:getParent(true)
	end

	return "./" .. table.concat(path, "/")
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