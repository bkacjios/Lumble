local user = {}
user.__index = user

local packet = require("lumble.packet")
local util = require("util")
local config = require("config")

local buffer = require("buffer")

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
	return ("%s[%d][%s]"):format(self.name, self.session, self:getID() == 0 and "Unregistered" or "Registered")
end

function user:updateStats(packet)
	for desc, value in packet:list() do
		if desc.name == "address" then
			local b = buffer(value)

			self.stats[desc.name] = self.stats[desc.name] or {}
			self.stats[desc.name].data = value

			if b:readInt() == 0 and b:readInt() == 0 and b:readShort() == 0 then
				-- ipv4
				self.stats[desc.name].ipv6 = false
				self.stats[desc.name].ipv4 = true
				self.stats[desc.name].string = ("%d.%d.%d.%d"):format(b[13], b[14], b[15], b[16])
			else
				-- ipv6
				self.stats[desc.name].ipv6 = true
				self.stats[desc.name].ipv4 = false
				self.stats[desc.name].string = ("%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x"):format(
					b[1], b[2], b[3], b[4],
					b[5], b[6], b[7], b[8],
					b[9], b[10], b[11], b[12],
					b[13], b[14], b[15], b[16]
				)
			end
		else
			self.stats[desc.name] = value
		end
	end
end

function user:getAddress()
	return self.stats["address"].string
end

function user:getClient()
	return self.client
end

function user:send(packet)
	return self.client:send(packet)
end

function user:setRecording(bool)
	local msg = packet.new("UserState")
	msg:set("recording", bool and true or false)
	self:send(msg)
end

function user:setPrioritySpeaker(bool)
	local msg = packet.new("UserState")
	msg:set("priority_speaker", bool and true or false)
	self:send(msg)
end

function user:setSelfMuted(bool)
	if self.client.me ~= self then return end
	local msg = packet.new("UserState")
	msg:set("self_mute", bool and true or false)
	self:send(msg)
end

function user:setSelfDeafened(bool)
	if self.client.me ~= self then return end
	local msg = packet.new("UserState")
	msg:set("self_deaf", bool and true or false)
	self:send(msg)
end

function user:message(text, ...)
	text = text or ""
	text = text:format(...)
	if #text > self.client.config.message_length then
		text = string.ellipse(text, self.client.config.message_length)
	end
	local msg = packet.new("TextMessage")
	msg:add("session", self.session)
	msg:set("message", text)
	self:send(msg)
end

function user:kick(reason, ...)
	reason = reason or ""
	local msg = packet.new("UserRemove")
	msg:set("session", self.session)
	msg:set("reason", reason:format(...))
	self:send(msg)
end

function user:ban(reason, ...)
	reason = reason or ""
	local msg = packet.new("UserRemove")
	msg:set("session", self.session)
	msg:set("reason", reason:format(...))
	msg:set("ban", true)
	self:send(msg)
end

function user:move(channel)
	local msg = packet.new("UserState")
	msg:set("session", self.session)
	if type(channel) == "string" then
		msg:set("channel_id", self:getChannel(channel):getID())
	else
		msg:set("channel_id", channel:getID())
	end
	self:send(msg)
end

function user:requestStats(stats_only)
	local msg = packet.new("UserStats")
	msg:set("session", self.session)
	msg:set("stats_only", stats_only and true or false)
	self:send(msg)
end

function user:getChannel(path)
	return self.client.channels[self.channel_id or 0](path)
end

function user:getSession()
	return self.session
end

function user:getName()
	return self.name
end

function user:getID()
	return self.user_id or 0
end

function user:isTalking()
	return self.talking or false
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

function user:getStats()
	return self.stats
end

function user:getStat(stat)
	return self.stats[stat]
end

function user:isMaster()
	-- Allow the superuser or masters to control the bot
	return self:getName() == config.superuser or config.masters[self:getHash()]
end

return user