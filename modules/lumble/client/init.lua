local client = {}
client.__index = client

local channel = require("lumble.client.channel")
local user = require("lumble.client.user")

local permission = require("lumble.permission")
local packet = require("lumble.packet")
local proto = require("lumble.proto")

local buffer = require("buffer")
local socket = require("socket")
local ssl = require("ssl")
local bit = require("bit")
local log = require("log")

log.level = "trace"

require("extensions.string")
require("extensions.table")

function client.new(host, port, params)
	local conn = socket.tcp()
	conn:settimeout(5)
	assert(conn:connect(host, port))
	conn = assert(ssl.wrap(conn, params))
	assert(conn:dohandshake())
	conn:settimeout(0)

	return setmetatable({
		socket = conn,
		host = host,
		port = port,
		start = socket.gettime(),
		ping = {
			good = 0,
			late = 0,
			lost = 0,
			udp_packets = 0,
			tcp_packets = 0,
			udp_ping_avg = 0,
			udp_ping_var = 0,
			tcp_ping_total = 0,
			tcp_ping_avg = 0,
			tcp_ping_var = 0,
		},
		version = {},
		channels = {},
		users = {},
		permissions = {},
		synced = false,
		config = {},
		hooks = {},
		start = socket.gettime(),
	}, client)
end

local function argerr(arg, num, expected)
	local typeName = type(arg)
	if typeName ~= expected then
		local funcName = debug.getinfo(2, "n").name
		return error(("bad argument #%d to '%s' %s expected, got %s "):format(num, funcName, expected, typeName), 2)
	end
end

function client:isSynced()
	return self.synced
end

function client:hook(name, desc, callback)
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

local function onError(err)
	print(debug.traceback(err, 4))
end

function client:hookCall(name, ...)
	if not self.hooks[name] then return end
	for desc, callback in pairs(self.hooks[name]) do
		local succ, ret = xpcall(callback, onError, ...)
		if not succ then
			log.error("%s error: %s", name, desc)
		else
			return ret
		end
	end
end

function client:auth(username, password, tokens)
	local version = packet.new("Version")

	local low, med, high = string.match(string.format("%06d", jit.version_num), "(%d%d)(%d%d)(%d%d)")

	version:set("version", bit.lshift(tonumber(low), 16) + bit.lshift(tonumber(med), 8) + tonumber(high))
	version:set("release", _VERSION)

	local file = assert(io.popen('uname -s', 'r'))
	version:set("os", file:read('*line'))
	file:close()

	local file = assert(io.popen('uname -r', 'r'))
	version:set("os_version", file:read('*line'))
	file:close()

	self:send(version)

	local auth = packet.new("Authenticate")
	auth:set("opus", true)
	auth:set("username", username)
	auth:set("password", password or "")

	for k,v in pairs(tokens or {}) do
		auth:add("tokens", v)
	end

	self:send(auth)
end

function client:send(packet)
	log.trace("Send %s to server", packet)
	return self.socket:send(packet:getRaw())
end

function client:getTime()
	return socket.gettime() - self.start
end

function client:doping()
	local ping = packet.new("Ping")
	ping:set("timestamp", self:getTime() * 1000)
	ping:set("tcp_packets", self.ping.tcp_packets)
	ping:set("tcp_ping_avg", self.ping.tcp_ping_avg)
	self:send(ping)
end

local next_ping = socket.gettime() + 5

function client:update()
	local now = socket.gettime()

	if not next_ping or next_ping <= now then
		next_ping = now + 5
		self:doping()
	end

	local read = true
	local err

	while read do
		read, err = self.socket:receive(6)

		if read then
			local buff = buffer(read)

			local id = buff:readShort()
			local len = buff:readInt()

			read, err = self.socket:receive(len)

			if id == 1 then
				-- Ignore voice data for now..
			else
				local packet = packet.new(id, read)
				self:onPacket(packet)
			end
		elseif err ~= "wantread" and err ~= "timeout" then
			log.error("receive error %q", err)
			return false
		end
	end

	return true
end

function client:sleep(t)
	socket.sleep(t)
end

function client:onPacket(packet)
	local name = packet:getType()
	local func = self["on" .. name]

	if not func then
		log.warn("Unimplemented %s", packet)
		return
	end

	log.trace("Received %s", packet)
	func(self, packet)
end

function client:onVersion(packet)
	log.info("Version: %s", packet.release)
	log.info("System : %s", packet.os_version)
end

function client:onUDPTunnel(data)
	-- Voice data
end

function client:onAuthenticate(packet)
	-- Not ever sent to client?
end

function client:onPing(packet)
	local time = self:getTime() * 1000
	local ms = (time - packet.timestamp)
	self.ping.tcp_packets = self.ping.tcp_packets + 1
	self.ping.tcp_ping_avg = ms
	log.trace("Ping: %0.2f", ms)
	self:hookCall("OnPing")
end

function client:onReject(packet)
	log.warn("Reject [%s][%s]", packet.type.name, packet.reason)
	self:hookCall("OnReject")
end

function client:onServerSync(packet)
	self.synced = true
	self.permissions[0] = packet.permissions
	self.session = packet.session
	self.max_bandwith = packet.max_bandwith
	self.me = self.users[self.session]
	log.info("Welcome Message: %s", packet.welcome_text:StripHTML())
	self:hookCall("OnServerSync", self.me)
end

function client:onChannelRemove(packet)
	self:hookCall("OnChannelRemove", self.channels[packet.channel_id])
	self.channels[packet.channel_id] = nil
end

function client:onChannelState(packet)
	if not self.channels[packet.channel_id] then
		self.channels[packet.channel_id] = channel.new(self, packet)
		if self.synced then
			self:hookCall("OnChannelCreated", self.channels[packet.channel_id])
		end
	else
		self.channels[packet.channel_id]:updateAll(packet)
	end
	self:hookCall("OnChannelState", self.channels[packet.channel_id])
end

function client:onUserRemove(packet)
	local user = self.users[packet.session]
	local actor = packet.actor and self.users[packet.actor] or nil

	self:hookCall("OnUserRemove", user)

	local message = "disconnected"
	
	if actor then
		local reason = (packet.reason and packet.reason ~= "") and packet.reason or "No reason given"
		message = (packet.ban and "banned by %s (%q)" or "kicked by %s (%q)"):format(actor, reason)
	end

	log.info("%s %s", user, message)
	self:hookCall("OnUserDisconnected", user)

	self.users[packet.session] = nil
end

function client:onUserState(packet)
	if not self.users[packet.session] then
		local user = user.new(self, packet)
		if self.synced then
			log.info("%s connected", user)
			self:hookCall("OnUserConnected", self.users[packet.session])
		end
		user:requestStats()
		self.users[packet.session] = user
	else
		self.users[packet.session]:updateAll(packet)
	end
	self:hookCall("OnUserState", self.users[packet.session])
end

function client:onBanList(packet)
	self:hookCall("OnBanList")
end

function client:onTextMessage(packet)
	self:hookCall("OnTextMessage")
end

function client:onPermissionDenied(packet)
	log.warn("PermissionDenied %s", permission.getName(packet.permission))
	self:hookCall("OnPermissionDenied")
end

function client:onACL(packet)
	self:hookCall("OnACL")
end

function client:onQueryUsers(packet)
	self:hookCall("OnQueryUsers")
end

function client:onCryptSetup(packet)
	self:hookCall("OnCryptSetup")
end

function client:onContextActionModify(packet)
	self:hookCall("OnContextActionModify")
end

function client:onContextAction(packet)
	self:hookCall("OnContextAction")
end

function client:onUserList(packet)
	self:hookCall("OnUserList")
end

function client:onVoiceTarget(packet)
	self:hookCall("OnVoiceTarget")
end

function client:onPermissionQuery(packet)
	if packet.flush then
		self.permissions = {}
	end
	self.permissions[packet.channel_id] = packet.permissions
	self:hookCall("OnPermissionQuery", self.permissions)
end

function client:hasPermission(channel, flag)
	return bit.band(self.permissions[channel:getID()], flag) > 0
end

function client:onCodecVersion(packet)
	self:hookCall("OnCodecVersion")
end

function client:onUserStats(packet)
	local user = self.users[packet.session]
	user:updateStats(packet)
	self:hookCall("OnUserStats")
end

function client:onRequestBlob(packet)
	self:hookCall("OnRequestBlob")
end

function client:onServerConfig(packet)
	self.config.allow_html = packet.allow_html
	self.config.message_length = packet.message_length
	self.config.image_message_length = packet.image_message_length
	self:hookCall("OnServerConfig", self.config)
end

function client:onSuggestConfig(packet)
	self:hookCall("OnSuggestConfig")
end

function client:getHooks()
	return self.hooks
end

function client:getUsers()
	return self.users
end

function client:getUser(index)
	local tp = type(index)
	if tp == "number" then
		return self.users[index]
	elseif tp == "string" then
		for session, user in pairs(self.users) do
			if user:getName() == index then
				return user
			end
		end
	end
end

function client:getChannels()
	return self.channels
end

function client:getChannel(index)
	local tp = type(id)
	if tp == "string" then
		return self.channels[0](index)
	elseif tp == "number"
		return self.channels[index]
	end
end

return client