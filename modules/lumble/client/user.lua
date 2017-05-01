local user = {}
user.__index = user

local packet = require("lumble.packet")

function user.new(client, packet)
	local user = setmetatable({
		client = client,
		stats = {},
	}, user)

	for desc, value in packet:list() do
		user[desc.name] = value
	end
	
	return user
end

function user:__tostring()
	return ("%s[%d][%s]"):format(self.name, self.session, self.user_id == 0 and "Unregistered" or "Registered")
end

function user:updateStats(packet)

end

function user:getClient()
	return self.client
end

function user:send(packet)
	return self.client:send(packet)
end

function user:message(text, ...)
	local msg = packet.new("TextMessage")
	msg:add("session", self.session)
	msg:set("message", text:format(...):escapeHTML())
	self:send(msg)
end

function user:kick(reason, ...)
	local msg = packet.new("UserRemove")
	msg:set("session", self.session)
	msg:set("reason", reason:format(...))
	self:send(msg)
end

function user:ban(reason, ...)
	local msg = packet.new("UserRemove")
	msg:set("session", self.session)
	msg:set("reason", reason:format(...))
	msg:set("ban", true)
	self:send(msg)
end

function user:move(channel)
	local msg = packet.new("UserState")
	msg:set("session", self.session)
	msg:set("channel_id", channel:getID())
	self:send(msg)
end

function user:requestStats(stats_only)
	local msg = packet.new("UserStats")
	msg:set("session", self.session)
	msg:set("stats_only", stats_only and true or false)
	self:send(msg)
end

function user:getChannel()
	return self.client.channels[self.channel_id]
end

function user:getSession()
	return user.session
end

function user:getName()
	return self.name
end

function user:getID()
	return self.user_id
end

function user:isMute()
	return self.mute
end

function user:isDeaf()
	return self.deaf
end

function user:isSuppressed()
	return self.suppress
end

function user:isSelfMute()
	return self.self_mute
end

function user:isSelfDeaf()
	return self.self_deaf
end

function user:getTexture()
	return self.texture
end

function user:getTextureHash()
	return self.texture_hash
end

function user:getPluginContext()
	return self.plugin_context
end

function user:getPluginIdentity()
	return self.plugin_identity
end

function user:getComment()
	return self.comment
end

function user:getCommentHash()
	return self.comment_hash
end

function user:getHash()
	return self.hash
end

function user:isPrioritySpeaker()
	return self.priority_speaker
end

function user:isRecording()
	return self.recording
end

return user