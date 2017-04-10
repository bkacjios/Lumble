local client = {}
client.__index = client

local buffer = require("buffer")
local proto = require("lumble.proto")
local hook = require("lumble.hook")
local socket = require("socket")
local ssl = require("ssl")
local bit = require("bit")

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
		}
	}, client)
end

local function getID(name)
	return proto.MESSAGE_IDS[name]
end

local function getName(id)
	return proto.MESSAGE_TYPES[id + 1]
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

		if type ~= "UDPTunnel" then
			local proto = proto[type]()
			proto:ParseFromString(data)
			self:onPacket(id, type, proto)
		end
	end

	return true
end

function client:onPacket(id, type, proto)
	if type == "Ping" then
		local time = (socket.gettime() % 5) * 10000
		local ms = (time - proto.timestamp) / 10
		self.ping.tcp_packets = self.ping.tcp_packets + 1
		self.ping.tcp_ping_avg = ms
	end
	hook.run(type, proto)
end

return client