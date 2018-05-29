local client = {}
client.__index = client

local channel = require("lumble.client.channel")
local user = require("lumble.client.user")

local permission = require("lumble.permission")
local packet = require("lumble.packet")
local proto = require("lumble.proto")
local event = require("lumble.event")

local opus = require("lumble.opus")
local stream = require("lumble.client.audiostream")

local buffer = require("buffer")
--local copas = require("copas")
local socket = require("socket")
local ssl = require("ssl")
local bit = require("bit")
local log = require("log")
local util = require("util")

local ffi = require("ffi")

require("extensions.string")

local CHANNELS = 1
local SAMPLE_RATE = 48000

local FRAME_DURATION = 10 -- ms
local FRAME_SIZE = SAMPLE_RATE * FRAME_DURATION / 1000
local PCM_SIZE = FRAME_SIZE * CHANNELS * 2
local PCM_LEN = PCM_SIZE / 2

function client.new(host, port, params)	
	local tcp = socket.tcp()
	tcp:settimeout(5)

	local status, err = tcp:connect(host, port)
	if not status then return false, err end
	tcp = ssl.wrap(tcp, params)
	if not tcp then return false, err end

	status, err = tcp:dohandshake()
	if not status then return false, err end
	tcp:settimeout(0)

	local encoder = opus.Encoder(SAMPLE_RATE, CHANNELS)
	encoder:set("vbr", 0)
	encoder:set("bitrate", 40000)

	local meta = {
		encoder = encoder,
		tcp = tcp,
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
		crypt = {
			key = {},
			client_nonce = {},
			server_nonce = {},
		},
		hooks = {},
		commands = {},
		start = socket.gettime(),
		volume = 0.4,
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

function client:createOggStream(file)
	local ogg, err = stream(file)
	return ogg, err
end

function client:playOggStream(stream)
	self.playing = stream
end

function client:playOgg(file, count)
	local ogg, err = stream(file)
	if ogg then
		ogg:setVolume(self.volume)
		ogg:loop(count)
		self.playing = ogg
		return ogg
	end
	return ogg, err
end

function client:setVolume(volume)
	self.volume = volume
	if self.playing then
		self.playing:setVolume(volume)
	end
end

function client:getVolume()
	return self.volume
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
		else
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
	log.trace("Send %s to server", packet)
	return self.tcp:send(packet:toString())
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
	b:writeByte(0x20)
	b:writeMumbleVarInt(self:getTime() * 1000)
end

local next_ping = socket.gettime() + 5

local record = io.open("data.vorbis", "wba")

function client:update()
	local now = socket.gettime()

	if not next_ping or next_ping <= now then
		next_ping = now + 5
		self:pingTCP()
		self:pingUDP()
	end

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

				local session = voice:readMumbleVarInt()
				local sequence = voice:readMumbleVarInt()

				local voice_header = voice:readByte()

				local b = self:createAudioPacket(4, target, sequence)

				local all = voice:readAll()

				b:writeByte(voice_header)
				b:write(all)

				b:seek("set", 2)
				b:writeInt(b.length - 6) -- Set size of payload

				--record:write(all)

				--self.tcp:send(b:toString())
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
			log.error("connection error %q", err)
			self.tcp:close()
			return false, err
		end
	end

	return false
end

local sequence = 1

local bor = bit.bor
local lshift = bit.lshift

function client:createAudioPacket(mode, target, seq)
	local b = buffer()
	b:writeShort(1) -- Type UDPTunnel
	b:writeInt(0) -- Size of payload
	local header = bor(lshift(mode, 5), target)
	b:writeByte(header)
	b:writeMumbleVarInt(seq, 2)
	return b
end

function client:getPlaying()
	return self.playing
end

function client:isPlaying()
	return self.playing ~= nil
end

function client:stopStream()
	if not self.playing then return end
	self.playing = nil
	self:hookCall("AudioFinish")
end

function client:streamAudio()
	if not self.playing then return end

	local b = self:createAudioPacket(4, 0, sequence)

	local pcm, pcm_size = self.playing:streamSamples(FRAME_DURATION)
	if not pcm or pcm_size <= 0 then self:stopStream() return end

	local encoded, encoded_len = self.encoder:encode(pcm, FRAME_SIZE, FRAME_SIZE, 0x1FFF)
	if not encoded or encoded_len <= 0 then self:stopStream() return end

	if pcm_size < FRAME_SIZE then
		encoded_len = bor(lshift(1, 13), encoded_len)
	end

	b:writeMumbleVarInt(encoded_len, 2)
	b:write(ffi.string(encoded, encoded_len))

	b:seek("set", 2)
	b:writeInt(b.length - 6) -- Set size of payload

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
		self.crypt[desc.name] = string.tohex(value)
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
		callback = callback,
		client = self,
		cmd = cmd,
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