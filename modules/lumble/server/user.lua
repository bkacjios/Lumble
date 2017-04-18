local user = {}
user.__index = user

local proto = require("lumble.proto")
local packet = require("lumble.packet")
local log = require("log")

function user.new(server, socket, session)
	local user = setmetatable({
		state	= proto.UserState(),
		server	= server,
		socket	= socket,
	}, user)

	if session then
		user:set("session", session)
	end

	user:set("name", "unknown")
	user:set("user_id", 0)
	user:set("channel_id", 0)
	user:set("mute", false)
	user:set("deaf", false)
	return user
end

function user:__index(key)
	return rawget(self, "state")[key] or rawget(self, key) or user[key]
end

function user:__tostring()
	return ("%s[%d][%s]"):format(self:getName(), self:getSession(), self:getID() == 0 and "Unregistered" or "Registered")
end

function user:send(packet)
	log.trace("Send %s to %s", packet, self)
	return self.socket:send(packet:getRaw())
end

function user:onPacket(packet)
	local name = packet:getType()
	local func = self["on" .. name]

	if not func then
		log.warn("Unimplemented packet: %s", packet)
		return
	end

	log.trace("Received %s", packet)
	func(self, packet)
end

function user:getState()
	return self.state
end

function user:getStatePacket()
	return packet.new("UserState", self.state)
end

function user:getID()
	return self.user_id
end

function user:getSession()
	return self.session
end

function user:getServer()
	return self.server
end

function user:getName()
	return self.name
end

function user:updateFrom(proto, key)
	user:set(key, proto[key])
end

function user:set(key, value)
	self.state[key] = value
end

function user:onAuthenticate(packet)
	self:set("name", packet.username)
	self.server:syncUser(self)
end

function user:onVersion(packet)

end

function user:onUserState(packet)
	self.server:checkUserState(packet)
end

function user:onPing(packet)
	self:send(packet)
end

function user:onUDPTunnel(packet)
	print(packet)
	-- Voice data
end

return user