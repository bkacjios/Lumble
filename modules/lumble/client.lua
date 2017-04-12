local client = {}
client.__index = client

local proto = require("lumble.proto")
local user = require("lumble.user")

local buffer = require("buffer")
local socket = require("socket")
local ssl = require("ssl")
local bit = require("bit")
local log = require("log")

require("extensions.string")

log.level = "debug"

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
	}, client)
end

local function getID(name)
	return proto.MESSAGE_IDS[name]
end

local function getName(id)
	return proto.MESSAGE_TYPES[id + 1]
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

function client:hookCall(name, ...)
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

function client:packet(name)
	local packet = proto[name]()
	return getID(name), packet
end

function client:auth(username, password, tokens)
	local id, version = self:packet("Version")

	local low, med, high = string.match(string.format("%06d", jit.version_num), "(%d%d)(%d%d)(%d%d)")

	version.version = bit.lshift(tonumber(low), 16) + bit.lshift(tonumber(med), 8) + tonumber(high)
	version.release = _VERSION

	local file = assert(io.popen('uname -s', 'r'))
	version.os = file:read('*line')
	file:close()

	local file = assert(io.popen('uname -r', 'r'))
	version.os_version = file:read('*line')
	file:close()

	self:send(id, version)

	local id, auth = self:packet("Authenticate")
	auth.opus = true
	auth.username = username
	auth.password = password or ""

	for k,v in pairs(tokens or {}) do
		table.insert(auth.tokens, v)
	end

	self:send(id, auth)
end

function client:send(id, pb)
	local buff = buffer()
	buff:writeShort(id)
	local data = pb:SerializeToString()
	buff:writeInt(#data)
	buff:write(data)
	return self.socket:send(buff:getRaw())
end

function client:doping()
	local id, ping = self:packet("Ping")
	ping.timestamp = (socket.gettime() % 5) * 10000
	ping.tcp_packets = self.ping.tcp_packets
	ping.tcp_ping_avg = self.ping.tcp_ping_avg
	self:send(id, ping)
	log.trace("[CLIENT] Ping")
end

local next_ping = socket.gettime() + 5

function client:update()
	local now = socket.gettime()

	if not next_ping or next_ping <= now then
		next_ping = now + 5
		self:doping()
	end

	local read, err = self.socket:receive(6)

	if read then
		local buff = buffer(read)

		local id = buff:readShort()
		local type = getName(id)
		local len = buff:readInt()

		local data, err = self.socket:receive(len)

		if type == "UDPTunnel" then
			self:onPacket(id, type, data)
		else
			local proto = proto[type]()
			proto:ParseFromString(data)
			self:onPacket(id, type, proto)
		end
	end

	return true
end

function client:onPacket(id, type, proto)
	local func = self["on" .. type]
	if not func then
		log.warn("[SERVER] Unimplemented packet:", type, id)
		return
	end
	func(self, proto)
end

function client:onVersion(proto)
	log.info("[SERVER] Version:", proto.release)
	log.info("[SERVER] System :", proto.os_version)
end

function client:onUDPTunnel(data)
	-- Voice data
end

function client:onAuthenticate(proto)
	-- Not ever sent to client?
end

function client:onPing(proto)
	local time = (socket.gettime() % 5) * 10000
	local ms = (time - proto.timestamp) / 10
	self.ping.tcp_packets = self.ping.tcp_packets + 1
	self.ping.tcp_ping_avg = ms
	log.trace("[SERVER] Ping")
	self:hookCall("OnPing")
end

function client:onReject(proto)
	log.warn("[SERVER]", proto.type.name .. ":", proto.reason)
	self:hookCall("OnReject")
end

function client:onServerSync(proto)
	log.info("[SERVER] ServerSync")
	self.synced = true
	self.permissions[0] = proto.permissions
	self.session = proto.session
	self.max_bandwith = proto.max_bandwith
	self.me = self.users[self.session]
	log.info("[SERVER] Welcome Message: %s" proto.welcome_text:StripHTML())
	self:hookCall("OnServerSync")
end

function client:onChannelRemove(proto)
	log.debug("[SERVER] ChannelRemove")
	self:hookCall("OnChannelRemove")
	self.channels[proto.channel_id] = nil
end

function client:onChannelState(proto)
	log.debug("[SERVER] ChannelState")
	if not self.channels[proto.channel_id] then
		self.channels[proto.channel_id] = user.new(self, proto)
		if self.synced then
			self:hookCall("OnChannelCreated", self.channels[proto.channel_id])
		end
	else
		self.channels[proto.channel_id]:updateFromProto(proto)
	end
	self:hookCall("OnChannelState")
end

function client:onUserRemove(proto)
	log.debug("[SERVER] UserRemove")
	self:hookCall("OnUserRemove")
	self.users[proto.session] = nil
end

function client:onUserState(proto)
	log.debug("[SERVER] UserState")
	if not self.users[proto.session] then
		self.users[proto.session] = user.new(self, proto)
		if self.synced then
			self:hookCall("OnUserConnected", self.users[proto.session])
		end
	else
		self.users[proto.session]:updateFromProto(proto)
	end
	self:hookCall("OnUserState")
end

function client:onBanList(proto)
	log.debug("[SERVER] BanList")
	self:hookCall("OnBanList")
end

function client:onTextMessage(proto)
	log.debug("[SERVER] TextMessage")
	self:hookCall("OnTextMessage")
end

function client:onPermissionDenied(proto)
	log.debug("[SERVER] PermissionDenied")
	self:hookCall("OnPermissionDenied")
end

function client:onACL(proto)
	log.debug("[SERVER] ACL")
	self:hookCall("OnACL")
end

function client:onQueryUsers(proto)
	log.debug("[SERVER] QueryUsers")
	self:hookCall("OnQueryUsers")
end

function client:onCryptSetup(proto)
	log.debug("[SERVER] CryptSetup")
	self:hookCall("OnCryptSetup")
end

function client:onContextActionModify(proto)
	log.debug("[SERVER] ContextActionModify")
	self:hookCall("OnContextActionModify")
end

function client:onContextAction(proto)
	log.debug("[SERVER] ContextAction")
	self:hookCall("OnContextAction")
end

function client:onUserList(proto)
	log.debug("[SERVER] UserList")
	self:hookCall("OnUserList")
end

function client:onVoiceTarget(proto)
	log.debug("[SERVER] VoiceTarget")
	self:hookCall("OnVoiceTarget")
end

function client:onPermissionQuery(proto)
	log.debug("[SERVER] PermissionQuery")
	if proto.flush then
		self.permissions = {}
	end
	self.permissions[proto.channel_id] = proto.permissions
	self:hookCall("OnPermissionQuery", self.permissions)
end

function client:onCodecVersion(proto)
	log.debug("[SERVER] CodecVersion")
	self:hookCall("OnCodecVersion")
end

function client:onUserStats(proto)
	log.debug("[SERVER] UserStats")
	self:hookCall("OnUserStats")
end

function client:onRequestBlob(proto)
	log.debug("[SERVER] RequestBlob")
	self:hookCall("OnRequestBlob")
end

function client:onServerConfig(proto)
	log.debug("[SERVER] ServerConfig")
	self.config.allow_html = proto.allow_html
	self.config.message_length = proto.message_length
	self.config.image_message_length = proto.image_message_length
	self:hookCall("OnServerConfig", self.config)
end

function client:onSuggestConfig(proto)
	log.debug("[SERVER] SuggestConfig")
	self:hookCall("OnSuggestConfig")
end

function client:getHooks()
	return self.hooks
end

function client:getUsers()
	return self.users
end

function client:getChannels()
	return self.channels
end

function client:getChannel(path)
	return self.channels[0](path)
end

return client