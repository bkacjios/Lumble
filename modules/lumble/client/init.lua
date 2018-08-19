local client = {}
client.__index = client

local channel = require("lumble.client.channel")
local user = require("lumble.client.user")

local permission = require("lumble.permission")
local packet = require("lumble.packet")
local proto = require("lumble.proto")
local event = require("lumble.event")

local opus = require("lumble.opus")

local buffer = require("buffer")
local ssl = require("ssl")
local log = require("log")
local util = require("util")

local bit = require("bit")
local ffi = require("ffi")
local ev = require("ev")
--local copas = require("copas")
local socket = require("socket")

local stream = require("lumble.client.audiostream")

local ocbaes128 = require("ocb.aes128")

require("extensions.string")

local CHANNELS = 1
local SAMPLE_RATE = 48000

local FRAME_DURATION = 10 -- ms
local FRAME_SIZE = SAMPLE_RATE * FRAME_DURATION / 1000

local UDP_CELT_ALPHA = 0
local UDP_PING = 1
local UDP_SPEEX = 2
local UDP_CELT_BETA = 3
local UDP_OPUS = 4

function client.new(host, port, params)	
	local tcp = socket.tcp()
	tcp:settimeout(5)

	local udp = socket.udp()
	local status, err = udp:setpeername(host, port)
	if not status then return false, err end
	udp:settimeout(0)

	local status, err = tcp:connect(host, port)
	if not status then return false, err end
	tcp = ssl.wrap(tcp, params)
	if not tcp then return false, err end

	status, err = tcp:dohandshake()
	if not status then return false, err end
	tcp:settimeout(0)

	local encoder = opus.Encoder(SAMPLE_RATE, CHANNELS)
	encoder:set("vbr", 0)
	encoder:set("bitrate", 41100)

	local meta = {
		crypt = ocbaes128.new(),
		encoder = encoder,
		tcp = tcp,
		udp = udp,
		host = host,
		port = port,
		params = params,
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
		config = {
			max_bandwidth = 0,
			welcome_text = "",
			allow_html = false,
			message_length = 0,
			image_message_length = 0,
			max_users = 0,
		},
		crypt_keys = {
			key = {},
			client_nonce = {},
			server_nonce = {},
		},
		hooks = {},
		commands = {},
		start = socket.gettime(),
		audio_streams = {},
		audio_volume = 0.15,
		audio_buffer = ffi.new('float[?]', FRAME_SIZE),
	}
	return setmetatable(meta, client)
end

function client:__tostring()
	return ("lumble.client[\"%s:%d\"]"):format(self.host, self.port)
end

function client:close()
	self.tcp:close()
end

function client:isSynced()
	return self.synced
end

function client:createOggStream(file, volume)
	local ogg, err = stream(file, volume)
	return ogg, err
end

function client:playOggStream(stream, channel)
	self.audio_streams[channel or 1] = stream
end

function client:playOgg(file, channel, volume, count)
	local ogg, err = stream(file, volume or self.audio_volume, count)
	if ogg then
		self.audio_streams[channel or 1] = ogg
		return ogg
	end
	return ogg, err
end

function client:setVolume(volume, channel)
	channel = channel or 1
	self.audio_volume = volume
	if self.audio_streams[channel] then
		self.audio_streams[channel]:setVolume(volume)
	end
end

function client:getVolume()
	return self.audio_volume
end

function client:hook(name, desc, callback)
	local funcArg = 3

	if type(desc) == "function" then
		callback = desc
		desc = "hook"
		funcArg = 2
	end

	util.argerr(desc, funcArg - 1, "string")
	util.argerr(callback, funcArg, "function")

	self.hooks[name] = self.hooks[name] or {}
	self.hooks[name][desc] = callback
end

local function onError(err)
	print(debug.traceback(err, 4))
end

function client:hookCall(name, ...)
	log.trace("Call hook %q", name)
	if not self.hooks[name] then return end
	for desc, callback in pairs(self.hooks[name]) do
		local succ, ret = xpcall(callback, onError, self, ...)
		if not succ then
			log.error("%s error: %s", name, desc)
		elseif ret then
			return ret
		end
	end
end

function client:auth(username, password, tokens)
	local version = packet.new("Version")

	local major, minor, patch = string.match(string.format("%06d", jit.version_num), "(%d%d)(%d%d)(%d%d)")

	version:set("version", bit.lshift(tonumber(major), 16) + bit.lshift(tonumber(minor), 8) + tonumber(patch))
	version:set("release", _VERSION)
	version:set("os", jit.os)
	version:set("os_version", jit.arch)

	self:send(version)

	local auth = packet.new("Authenticate")
	auth:set("opus", true)
	auth:set("username", username)
	auth:set("password", password or "")

	self.username = username
	self.password = password
	self.tokens = tokens

	for k,v in pairs(tokens or {}) do
		auth:add("tokens", v)
	end

	self:send(auth)
end

function client:send(packet)
	log.trace("Send TCP %s to server", packet)
	return self.tcp:send(packet:toString())
end

function client:sendUDP(packet)
	log.trace("Send UDP %s to server", packet)
	local encryped = self.crypt:encrypt(packet:toString())
	return self.udp:send(encryped)
end

function client:getTime()
	return socket.gettime() - self.start
end

function client:pingTCP()
	local ping = packet.new("Ping")
	ping:set("timestamp", self:getTime() * 1000)
	ping:set("tcp_packets", self.ping.tcp_packets)
	ping:set("tcp_ping_avg", self.ping.tcp_ping_avg)
	self:send(ping)
end

function client:pingUDP()
	local b = buffer()
	b:writeByte(bit.lshift(UDP_PING, 5))
	b:writeString("test")
	self:sendUDP(b)
end

local next_ping = socket.gettime() + 5

local record = io.open("data.vorbis", "wba")

function client:receiveVoiceData(packet, codec, target)
	local session = packet:readMumbleVarInt()
	local sequence = packet:readMumbleVarInt()

	local talking = false

	if codec == UDP_SPEEX or codec == UDP_CELT_ALPHA or codec == UDP_CELT_BETA then
		local header = packet:readByte()
		talking = bit.band(header, 0x80) ~= 0x80
	elseif codec == UDP_OPUS then 
		local header = packet:readMumbleVarInt()

		local len = bit.band(header, 0x1FFF)
		talking = bit.band(header, 0x2000) ~= 0x2000

		--[[local b = self:createAudioPacket(UDP_OPUS, target, sequence)

		local all = packet:readAll()

		b:writeMumbleVarInt(header)
		b:write(all)

		b:seek("set", 2)
		b:writeInt(b.length - 6) -- Set size of payload

		--record:write(all)

		self.tcp:send(b:toString())]]
	end

	if self.users[session].talking ~= talking then
		self.users[session].talking = talking
		for i=1,2 do
			if self.audio_streams[i] then
				self.audio_streams[i]:setUserTalking(talking)
			end
		end
	end
end

function client:readUDP()
	local read = true
	local err

	while read do
		read, err = self.udp:receive(100)
		if read then
			local b = buffer(read)

			local id = b:readByte()
			local stuff = b:readAll()

			print(self.crypt:decrypt(stuff))

		elseif err == "timeout" then
			return true
		else
			log.error("UDP connection error %q", err)
			return false, err
		end
	end
end

function client:update()
	local now = socket.gettime()

	if not next_ping or next_ping <= now then
		next_ping = now + 5
		self:pingTCP()
		--self:pingUDP()
	end

	--self:readUDP()

	local read = true
	local err

	while read do
		read, err = self.tcp:receive(6)

		if read then
			local buff = buffer(read)

			local id = buff:readShort()
			local len = buff:readInt()
			
			if not id or not len then
				log.warn("Bad backet: %q", read)
				return true
			end

			read, err = self.tcp:receive(len)

			if id == 1 then
				local voice = buffer(read)
				local header = voice:readByte()

				local codec = bit.rshift(header, 5)
				local target = bit.band(header, 31)

				self:receiveVoiceData(voice, codec, target)
			else
				local packet = packet.new(id, read)
				self:onPacket(packet)
			end
		elseif err == "wantread" then
			return true
		elseif err == "wantwrite" then
			return true
		elseif err == "timeout" then
			return true
		else
			log.error("TCP connection error %q", err)
			self.tcp:close()
			return false, err
		end
	end

	return false
end

local sequence = 1

local bor = bit.bor
local lshift = bit.lshift

function client:createAudioStream()
	if self.audio_timer then return end

	-- Get the length of our timer..
	-- We have a 10ms frame delay, but we're going to send 6 every 6ms
	local count = 4
	local time = FRAME_DURATION * count / 1000

	self.audio_timer = ev.Timer.new(function()
		-- Send our multiple audio packets at once
		for i=1,count do
			self:streamAudio()
		end
	end, time, time)
	self.audio_timer:start(ev.Loop.default)
end

function client:createAudioPacket(codec, target, seq)
	local b = buffer()
	b:writeShort(1) -- Type UDPTunnel
	b:writeInt(0) -- Size of payload

	-- Start of voice datagram
	local header = bor(lshift(codec, 5), target)
	b:writeByte(header)
	b:writeMumbleVarInt(seq)
	return b
end

function client:getPlaying(channel)
	return self.audio_streams[channel or 1]
end

function client:isPlaying(channel)
	return self.audio_streams[channel or 1] ~= nil
end

function client:streamAudio()
	local biggest_pcm_size = 0

	ffi.fill(self.audio_buffer, ffi.sizeof(self.audio_buffer))

	for channel, stream in pairs(self.audio_streams) do
		local pcm, pcm_size = stream:streamSamples(FRAME_DURATION, SAMPLE_RATE, CHANNELS)

		if not pcm or not pcm_size or pcm_size <= 0 then
			self.audio_streams[channel] = nil
			self:hookCall("AudioStreamFinish", channel)
		else
			if pcm_size > biggest_pcm_size then
				biggest_pcm_size = pcm_size
			end
			for i=0,pcm_size-1 do
				self.audio_buffer[i] = self.audio_buffer[i] + pcm[i]
			end
		end
	end

	if biggest_pcm_size <= 0 then return end

	local encoded, encoded_len = self.encoder:encode(self.audio_buffer, FRAME_SIZE, FRAME_SIZE, 0x1FFF)
	if not encoded or encoded_len <= 0 then self:hookCall("AudioFinish") return end

	if encoded_len > 8191 then
		log.error("encoded frame too large for audio packet..", encoded_len)
		return
	end

	if biggest_pcm_size < FRAME_SIZE then
		-- Set 14th bit to 1 to signal end of stream
		encoded_len = bor(lshift(1, 13), encoded_len)
	end

	--[[if bit.band(encoded_len, 0x2000) == 0x2000 then
		print("end of stream")
	end]]

	local b = self:createAudioPacket(UDP_OPUS, 0, sequence)

	b:writeMumbleVarInt(encoded_len)
	b:write(ffi.string(encoded, encoded_len))

	b:seek("set", 2)
	b:writeInt(b.length - 6) -- Set size of payload

	--self:sendUDP(b)
	self.tcp:send(b:toString())

	sequence = (sequence + 1) % 10000
end

function client:sleep(t)
	socket.sleep(t)
end

function client:onPacket(packet)
	local func = self["on" .. packet:getType()]

	if not func then
		log.warn("unimplemented %s", packet)
		return
	end

	log.trace("received %s", packet)
	func(self, packet)
end

function client:onVersion(packet)
	log.info("version: %s", packet.release)
	log.info("system : %s", packet.os_version)
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
	log.trace("ping: %0.2f", ms)
	self:hookCall("OnPing")
end

function client:onReject(packet)
	log.warn("rejected [%s][%s]", packet.type, packet.reason)
	self:hookCall("OnReject")
end

function client:onServerSync(packet)
	self.synced = true
	self.permissions[0] = packet.permissions
	self.session = packet.session
	self.config.max_bandwidth = packet.max_bandwidth
	self.me = self.users[self.session]
	log.info("message: %s", packet.welcome_text:stripHTML())
	self:createAudioStream()
	self:hookCall("OnServerSync", self.me)
end

function client:onChannelRemove(packet)
	self:hookCall("OnChannelRemove", event.new(self, packet.proto))
	self.channels[packet.channel_id] = nil
end

function client:onChannelState(packet)
	if not self.channels[packet.channel_id] then
		self.channels[packet.channel_id] = channel.new(self, packet)
		if self.synced then
			self:hookCall("OnChannelCreated", event.new(self, packet.proto))
		end
	else
		local channel = self.channels[packet.channel_id]
		channel:update(packet)
	end
	self:hookCall("OnChannelState", event.new(self, packet.proto))
end

function client:onUserRemove(packet)
	local user = packet.session and self.users[packet.session]
	local actor = packet.actor and self.users[packet.actor]

	local message = "disconnected"
	
	if user and actor then
		local reason = (packet.reason and packet.reason ~= "") and packet.reason or "No reason given"
		message = (packet.ban and "banned by %s (%q)" or "kicked by %s (%q)"):format(actor, reason)
	else
		self.users[packet.session] = nil
	end

	log[user == self.me and "warn" or "info"]("%s %s", user, message)
	self:hookCall("OnUserRemove", event.new(self, packet.proto, true))
end

function client:onUserState(packet)
	if not self.users[packet.session] then
		local user = user.new(self, packet)
		if self.synced then
			log.info("%s connected", user)
			self:hookCall("OnUserConnected", event.new(self, packet.proto))
		end
		user:requestStats()
		self.users[packet.session] = user
	else
		local user = self.users[packet.session]
		for desc, value in packet:list() do
			local name = desc.name
			if user[name] ~= value then
				if name == "channel_id" then
					local event = event.new(self, packet.proto)
					event.channel_from = user:getChannel()
					self:hookCall("OnUserChannel", event)
				end
				user[name] = value
			end
		end
	end
	self:hookCall("OnUserState", event.new(self, packet.proto))
end

function client:onBanList(packet)
	self:hookCall("OnBanList")
end

function client:onTextMessage(packet)
	local event = event.new(self, packet.proto, true)

	local msg = event.message:stripHTML():unescapeHTML()

	if msg[1] == "!" or msg[1] == "/" then
		local user = event.actor
		local args = msg:parseArgs()
		local cmd = table.remove(args,1):lower()
		local info = self.commands[cmd:sub(2)]
		
		if info then
			if info.master and not user:isMaster() then
				log.warn("%s: %s (PERMISSION DENIED)", user, msg)
				user:message("permission denied: %s", cmd)
			else
				local suc, err = pcall(info.callback, self, user, cmd, args, msg)
				if not suc then
					log.error("%s: %s (%q)", user, msg, err)
					user:message("congrats, you broke the <b>%s</b> command", cmd)
				end
			end
		else
			log.info("%s: %s (unknown Command)", user, msg)
			user:message("unknown command: <b>%s</b>", cmd)
		end
		return
	end

	self:hookCall("OnTextMessage", event)
end

function client:onPermissionDenied(packet)
	if packet.type == permission.type.Permission then
		log.warn("PermissionDenied: %s", permission.getName(packet.id))
	else
		log.warn("PermissionDenied: %s", permission.getTypeName(packet.type))
	end
	self:hookCall("OnPermissionDenied")
end

function client:onACL(packet)
	self:hookCall("OnACL")
end

function client:onQueryUsers(packet)
	self:hookCall("OnQueryUsers")
end

function client:onCryptSetup(packet)
	for desc, value in packet:list() do
		self.crypt_keys[desc.name] = value
	end

	if packet.key and packet.client_nonce and packet.server_nonce then
		self.crypt:setKey(packet.key, packet.client_nonce, packet.server_nonce)
	elseif packet.server_nonce then
		self.crypt:setDecryptIV(packet.server_nonce)
	end
	
	self:hookCall("OnCryptSetup")
end

function client:onContextActionModify(packet)
	self:hookCall("OnContextActionModify")
end

function client:onContextAction(packet)
	self:hookCall("OnContextAction")
end

function client:onUserList(packet)
	self:hookCall("OnUserList", event.new(self, packet.proto, true))
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
	if not user then return end
	user:updateStats(packet)
	self:hookCall("OnUserStats", event.new(self, packet.proto, true))
end

function client:onRequestBlob(packet)
	self:hookCall("OnRequestBlob")
end

function client:onServerConfig(packet)
	for desc, value in packet:list() do
		self.config[desc.name] = value
	end
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
	local tp = type(index)
	if tp == "string" then
		return self.channels[0](index)
	elseif tp == "number" then
		return self.channels[index]
	else
		return self.channels[0]
	end
end

function client:requestUserList()
	local msg = packet.new("UserList")
	self:send(msg)
end

local COMMAND = {}
COMMAND.__index = COMMAND

function COMMAND:setHelp(text, ...)
	self.help = text:format(...)
	return self
end

function COMMAND:setUsage(text, ...)
	self.usage = text:format(...)
	return self
end

function COMMAND:setMaster()
	self.master = true
	return self
end

function COMMAND:alias(name)
	self.client.commands[name] = setmetatable({
		name = name,
		aliased = true,
		callback = self.callback,
		usage = self.usage,
		help = self.help,
		master = self.master,
		cmd = self.cmd,
	}, COMMAND)
	return self
end

function client:addCommand(cmd, callback)
	self.commands = self.commands or {}
	self.commands[cmd] = setmetatable({
		name = cmd,
		aliased = false,
		callback = callback,
		client = self,
		cmd = cmd,
		master = false,
		help = "",
		usage = "",
	}, COMMAND)
	return self.commands[cmd]
end

function client:getCommands()
	return self.commands
end

function client:getCommand(cmd)
	return self.commands[cmd]
end

return client