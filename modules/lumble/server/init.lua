local server = {}
server.__index = server

local user = require("lumble.server.user")
local packet = require("lumble.packet")
local proto = require("lumble.proto")

local permission = require("lumble.permission")

local buffer = require("buffer")
local socket = require("socket")
local ssl = require("ssl")
local bit = require("bit")
local log = require("log")

require("extensions.string")

function server.new(host, port, params)
	local conn = socket.try(socket.bind(host, port))
	conn:settimeout(0)

	local ip, port = conn:getsockname()
	log.info("server started on %s:%i", ip, port)

	return setmetatable({
		socket = conn,
		host = host,
		port = port,
		start = socket.gettime(),
		ssl_ctx = assert(ssl.newcontext(params)),
		channels = {
			[0] = "Lua Mumble!",
			[1] = "Huehueheuehuehu"
		},
		users = {},
		permissions = {},
		config = {
			max_users = 10,
			max_bandwidth = 48000,
			welcome_text = "This is a Lua based Mumble server!",
		},
		hooks = {},
	}, server)
end

local function argerr(arg, num, expected)
	local typeName = type(arg)
	if typeName ~= expected then
		local funcName = debug.getinfo(2, "n").name
		return error(("bad argument #%d to '%s' %s expected, got %s "):format(num, funcName, expected, typeName), 2)
	end
end

function server:sleep(t)
	socket.sleep(t)
end

function server:getFreeSession()
	for i=1, self.config.max_users do
		if not self.users[i] then
			return i
		end
	end
end

function server:isSynced()
	return self.synced
end

function server:hook(name, desc, callback)
	local funcArg = 3

	if type(desc) == "function" then
		callback = desc
		desc = "hook"
		funcArg = 2
	end

	argerr(desc, funcArg - 1, "string")
	argerr(callback, funcArg, "function")

	self.hooks[name] = self.hooks[name] or {}
	self.hooks[name][desc] = callback
end

function server:hookCall(name, ...)
	if not self.hooks[name] then return end
	for desc, callback in pairs(self.hooks[name]) do
		local succ, ret = pcall(callback, ...)
		if not succ then
			log.error("hook error: %s (%s)", desc, ret)
		else
			return ret
		end
	end
end

function server:update()
	local peer, err = self.socket:accept()

	if peer then
		self:onUserConnect(peer)
	end

	for id, user in pairs(self.users) do
		local read = true
		local err

		while read do
			read, err = user.socket:receive(6)

			if read then
				local buff = buffer(read)

				local id = buff:readShort()
				local len = buff:readInt()

				read, err = user.socket:receive(len)

				local packet = packet.new(id, read)
				user:onPacket(packet)
			elseif err == "closed" then
				self:onUserDisconnect(user, err)
			elseif err ~= "wantread" and err ~= "timeout" then
				log.error("receive error %q", err)
			end
		end
	end

	return true
end

function server:onUserConnect(peer)
	local ip, port = peer:getpeername()
	log.info("peer %s:%i connected", ip, port)
	
	peer = socket.try(ssl.wrap(peer, self.ssl_ctx))
	local status, err = peer:dohandshake()

	if not status then
		log.error("peer %s:%i failed to handshake: %s", ip, port, err)
		local state = packet.new("Reject")
		state:set("reason", "A certificate is required to connect to this server")
		state:set("type", proto.REJECT_REJECTTYPE_NOCERTIFICATE_ENUM)
		peer:send(state:toString())
		peer:close()
		return
	end

	peer:settimeout(0)

	local session = self:getFreeSession()

	if not session then
		local state = packet.new("Reject")
		state:set("reason", ("Server is full (max %d users)"):format(self.config.max_users))
		state:set("type", proto.REJECT_REJECTTYPE_SERVERFULL_ENUM)
		peer:send(state:toString())
		peer:close()
		return
	end

	self.users[session] = user.new(self, peer, session)
end

function server:onUserDisconnect(user, err)
	log.info("user %s disconnected: %s", user, err)
	if self.users[user.session] then
		self.users[user.session] = nil
	end
end

function server:updateUserState(user)
	for session, other in pairs(self.users) do
		other:send(user:getStatePacket())
	end
end

function server:syncUser(user)
	for id, channel in pairs(self.channels) do
		local state = packet.new("ChannelState")
		state:set("channel_id", id)
		state:set("parent", 0)
		state:set("name", channel)
		state:set("description", "huehueheu")
		state:set("max_users", 10)
		user:send(state)
	end
	for session, other in pairs(self.users) do
		user:send(other:getStatePacket())
	end
	local sync = packet.new("ServerSync")
	sync:set("session", user:getSession())
	sync:set("max_bandwidth", self.config.max_bandwidth)
	sync:set("welcome_text", self.config.welcome_text)
	sync:set("permissions", permission.enum.ALL)
	user:send(sync)
end

function server:checkUserState(user, packet)
	table.foreach(packet, print)
	if packet.self_mute ~= nil then
		user:set("self_mute", packet.self_mute)
	end
	if packet.self_deaf ~= nil then
		user:set("self_deaf", packet.self_deaf)
	end
	if packet.channel_id then
		if user:hasPermission(permission.enum.MOVE) and self.channels[packet.channel_id] then
			user:set("channel_id", packet.channel_id)
			user:set("actor", user.session)
		end
	end
	self:updateUserState(user)
end

function server:checkTextMessage(user, packet)
	print(user, "checkTextMessage", packet)
	table.foreach(packet, print)
	if packet.channel_id then
		
	elseif packet.session then

	end
end

function server:checkPermissionQuery(user, packet)
	print(user, "checkPermissionQuery", packet)
	table.foreach(packet, print)
end

function server:getHooks()
	return self.hooks
end

function server:getUsers()
	return self.users
end

function server:getChannels()
	return self.channels
end

function server:getChannel(path)
	if type(path) == "string" then
		return self.channels[0](path)
	elseif type(path) == "number" then
		return self.channels[path]
	end
end

return server