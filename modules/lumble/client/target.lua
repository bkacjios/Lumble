local target = {}
target.__index = target

function target.new()
	-- VoiceTarget.Target structure
	return setmetatable({
		session = {},
		channel_id = nil,
		group = nil,
		links = false,
		children = false,
	}, target)
end

function target:addUser(user)
	table.insert(self.session, user:getSession())
end

function target:getUsers()
	return self.session
end

function target:setChannel(channel)
	self.channel_id = channel:getID()
end

function target:getChannel()
	return self.channel_id
end

function target:setGroup(group)
	self.group = tostring(group)
end

function target:setLinks(links)
	self.links = links
end

function target:setChildren(children)
	self.children = children
end

return target
