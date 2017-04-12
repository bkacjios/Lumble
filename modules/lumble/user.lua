local user = {}
user.__index = user

require("extensions.table")

function user.new(client, proto)
	return setmetatable({
		client			= client,
		session			= proto.session,
		name			= proto.name,
		user_id			= proto.user_id,
		channel_id		= proto.channel_id,
		mute			= proto.mute,
		deaf			= proto.deaf,
		suppress		= proto.suppress,
		self_mute		= proto.self_mute,
		self_deaf		= proto.self_deaf,
		texture			= proto.texture,
		plugin_context	= proto.plugin_context,
		plugin_identity	= proto.plugin_identity,
		comment			= proto.comment,
		hash			= proto.hash,
		comment_hash	= proto.comment_hash,
		texture_hash	= proto.texture_hash,
		priority_speaker = proto.priority_speaker,
		recording		= proto.recording,
	}, user)
end

function user:update(proto, key)
	if proto[key] ~= nil and proto[key] ~= self[key] then
		self[key] = proto[key]
	end
end

function user:updateFromProto(proto)
	self:update(proto, "session")
	self:update(proto, "name")
	self:update(proto, "user_id")
	self:update(proto, "channel_id")
	self:update(proto, "mute")
	self:update(proto, "deaf")
	self:update(proto, "suppress")
	self:update(proto, "self_mute")
	self:update(proto, "self_deaf")
	self:update(proto, "texture")
	self:update(proto, "plugin_context")
	self:update(proto, "plugin_identity")
	self:update(proto, "comment")
	self:update(proto, "hash")
	self:update(proto, "comment_hash")
	self:update(proto, "texture_hash")
	self:update(proto, "priority_speaker")
	self:update(proto, "recording")
end

function user:getClient()
	return self.client
end

function user:send(id, proto)
	self.client:send(id, proto)
end

function user:message(text)
	log.trace("[CLIENT] TextMessage [all]: %s", text)

	local id, msg = self:packet("TextMessage")
	table.insert(msg.session, self.session)
	msg.message = text
	self:send(id, msg)
end

function user:kick(reason)
	log.trace("[CLIENT] UserRemove [%d][kick]: %s", self.session, reason)

	local id, msg = self:packet("UserRemove")
	msg.session = self.session
	msg.reason = reason
	self:send(id, msg)
end

function user:ban(reason)
	log.trace("[CLIENT] UserRemove [%d][ban]: %s", self.session, reason)

	local id, msg = self:packet("UserRemove")
	msg.session = self.session
	msg.reason = reason
	msg.ban = true
	self:send(id, msg)
end

function user:move(channel)
	log.trace("[CLIENT] UserState [%d][move]: %s", self.session, reason)

	local id, msg = self:packet("UserState")
	msg.session = self.session
	msg.channel_id = channel:getID()
	self:send(id, msg)
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