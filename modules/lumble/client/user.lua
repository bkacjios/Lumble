local user = {}
user.__index = user

local packet = require("lumble.packet")

function user.new(client, packet)
	return setmetatable({
		client			= client,
		session			= packet.session,
		name			= packet.name,
		user_id			= packet.user_id,
		channel_id		= packet.channel_id,
		mute			= packet.mute,
		deaf			= packet.deaf,
		suppress		= packet.suppress,
		self_mute		= packet.self_mute,
		self_deaf		= packet.self_deaf,
		texture			= packet.texture,
		plugin_context	= packet.plugin_context,
		plugin_identity	= packet.plugin_identity,
		comment			= packet.comment,
		hash			= packet.hash,
		comment_hash	= packet.comment_hash,
		texture_hash	= packet.texture_hash,
		priority_speaker = packet.priority_speaker,
		recording		= packet.recording,
		stats			= {},
	}, user)
end

function user:__tostring()
	return ("%s[%d][%s]"):format(self.name, self.session, self.user_id == 0 and "Unregistered" or "Registered")
end

function user:update(packet, key)
	if packet[key] ~= nil and packet[key] ~= self[key] then
		self[key] = packet[key]
	end
end

function user:updateAll(packet)
	self:update(packet, "session")
	self:update(packet, "name")
	self:update(packet, "user_id")
	self:update(packet, "channel_id")
	self:update(packet, "mute")
	self:update(packet, "deaf")
	self:update(packet, "suppress")
	self:update(packet, "self_mute")
	self:update(packet, "self_deaf")
	self:update(packet, "texture")
	self:update(packet, "plugin_context")
	self:update(packet, "plugin_identity")
	self:update(packet, "comment")
	self:update(packet, "hash")
	self:update(packet, "comment_hash")
	self:update(packet, "texture_hash")
	self:update(packet, "priority_speaker")
	self:update(packet, "recording")
end

function user:updateStats(packet)

end

function user:getClient()
	return self.client
end

function user:send(packet)
	return self.client:send(packet)
end

function user:message(text)
	local msg = packet.new("TextMessage")
	msg:add("session", self.session)
	msg:set("message", text)
	self:send(msg)
end

function user:kick(reason)
	local msg = packet.new("UserRemove")
	msg:set("session", self.session)
	msg:set("reason", reason)
	self:send(msg)
end

function user:ban(reason)
	local msg = packet.new("UserRemove")
	msg:set("session", self.session)
	msg:set("reason", reason)
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