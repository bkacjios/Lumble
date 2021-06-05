local client = {}
client.__index = client

local channel = require("lumble.client.channel")
local cuser = require("lumble.client.user")
local target = require("lumble.client.target")

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

local socket = require("socket")

local stream = require("lumble.client.audiostream")

local ocbaes128 = require("ocb.aes128")

require("extensions.string")

local SAMPLE_RATE = 48000
local ENCODED_BITRATE = 96000 --57000 --41100

local DEFAULT_FRAMES = 1
local MAX_FRAMES = 6
local MAX_BUFFER_SIZE = MAX_FRAMES * SAMPLE_RATE / 100

local UDP_CELT_ALPHA = 0
local UDP_PING = 1
local UDP_SPEEX = 2
local UDP_CELT_BETA = 3
local UDP_OPUS = 4

local MAX_UDP_BUFFER = 1024

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

function client.new(host, port, params)	
	local tcp = socket.tcp()
	tcp:settimeout(5)

	local udp = socket.udp()
	local status, err = udp:setpeername(host, port)
	if not status then return false, err end
	udp:settimeout(0)

	local status, err = tcp:connect(host, port)
	if not status then return false, err end
	tcp, err = ssl.wrap(tcp, params)
	if not tcp then return false, err end

	status, err = tcp:dohandshake()
	if not status then return false, err end
	tcp:settimeout(0)

	local encoder = opus.Encoder(SAMPLE_RATE, 2)
	encoder:set("vbr", 0)
	encoder:set("bitrate", 96000)

	local object = {
		crypt = ocbaes128.new(),
		encoder = encoder,
		tcp = tcp,
		udp = udp,
		host = host,
		port = port,
		params = params,
		ping = {
			resync = 0,
			udp_packets = 0,
			udp_ping_acc = 0,
			udp_ping_avg = 0,
			udp_ping_var = 0,
			tcp_packets = 0,
			tcp_ping_acc = 0,
			tcp_ping_avg = 0,
			tcp_ping_var = 0,
		},
		tunnel_udp = true, -- Use TCP for audio until the server confirms a successful UDP connection
		version = {},
		channels = {},
		users = {},
		num_users = 0,
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
		audio_volume = 0.35,
		audio_frames = DEFAULT_FRAMES,
		audio_buffer = ffi.new('AudioFrame[?]', MAX_BUFFER_SIZE),
		audio_debuffer = ffi.new('AudioFrame[?]', MAX_BUFFER_SIZE),
		audio_sequence = 0,
		audio_target = 0,
	}

	-- Create an event using the sockets file desciptor for when client is ready to read data
	object.onreadtcp = ev.IO.new(function()
		-- Read the request safely using xpcall
		local succ, err = xpcall(object.readtcp, debug.traceback, object)
		if not succ then log.error(err) end
	end, tcp:getfd(), ev.READ)

	-- Create an event using the sockets file desciptor for when client is ready to read data
	object.onreadudp = ev.IO.new(function()
		-- Read the request safely using xpcall
		local succ, err = xpcall(object.readudp, debug.traceback, object)
		if not succ then log.error(err) end
	end, udp:getfd(), ev.READ)

	object.ping_timer = ev.Timer.new(function()
		local succ, err = xpcall(object.doping, debug.traceback, object)
		if not succ then log.error(err) end
	end, 30, 30)

	-- Register the event
	object.onreadtcp:start(ev.Loop.default)
	object.onreadudp:start(ev.Loop.default)
	object.ping_timer:start(ev.Loop.default)

	return setmetatable(object, client)
end

function client:__tostring()
	return ("lumble.client[\"%s:%d\"]"):format(self.host, self.port)
end

function client:close()
	self.tcp:close()
	self.udp:close()

	self.onreadtcp:stop(ev.Loop.default)
	self.onreadudp:stop(ev.Loop.default)
	self.ping_timer:stop(ev.Loop.default)
	
	if self.audio_timer then
		self.audio_timer:stop(ev.Loop.default)
	end

	if self:isSynced() then
		self:hookCall("OnDisconnect")
	end
end

function client:isSynced()
	return self.synced
end

local function getNetworkBandwidth(bitrate, frames)
	local overhead = 20 + 8 + 4 + 1 + 2 + 12 + frames
	overhead = overhead * (800 / frames)
	return overhead + bitrate
end

function client:createAudioStream(bitspersec)
	local frames = self.audio_frames
	local bitrate = self.encoder:get("bitrate")

	if (bitspersec == -1) then
		-- No limit
	elseif (getNetworkBandwidth(bitrate, frames) > bitspersec) then
		if ((frames <= 4) and (bitspersec <= 32000)) then
			frames = 4
		elseif ((frames == 1) and (bitspersec <= 64000)) then
			frames = 2
		elseif ((frames == 2) and (bitspersec <= 48000)) then
			frames = 4
		end
		if (getNetworkBandwidth(bitrate, frames) > bitspersec) then
			repeat
				bitrate = bitrate - 1000
			until not ((bitrate > 8000) and (getNetworkBandwidth(bitrate, frames) > bitspersec))
		end
	end
	if (bitrate < 8000) then
		bitrate = 8000
	end

	if bitrate ~= self.encoder:get("bitrate") then
		log.warn("Server maximum network bandwidth is only %d kbit/s.", bitspersec / 1000)
		log.warn("Audio quality auto-adjusted to %d kbit/s (%d ms)", bitrate / 1000, frames * 10)
		self.audio_frames = frames
		self.encoder:set("bitrate", bitrate)
		self.audio_buffer = ffi.new('AudioFrame[?]', frames * SAMPLE_RATE / 100)
	end

	-- Get the length of our timer for the audio stream..
	local time = frames / 100

	self.audio_timer = ev.Timer.new(function()
		local succ, err = xpcall(self.streamAudio, debug.traceback, self)
		if not succ then log.error(err) end
	end, time, time)

	self.audio_timer:start(ev.Loop.default)
end

function client:createOggStream(file, volume)
	local ogg, err = stream(file, volume)
	return ogg, err
end

function client:playOggStream(stream, channel)
	self.audio_streams[channel or 1] = stream
end

function client:playOgg(file, channel, volume, count)
	local ogg, err = stream(file, volume, count)
	if ogg then
		self.audio_streams[channel or 1] = ogg
		return ogg
	end
	return ogg, err
end

function client:setMasterVolume(volume)
	self.audio_volume = volume
end

function client:getMasterVolume()
	return self.audio_volume
end

function client:setVolume(volume, channel)
	channel = channel or 1
	if self.audio_streams[channel] then
		self.audio_streams[channel]:setVolume(volume)
	end
end

function client:getVolume(channel)
	return self.audio_streams[channel or 1]:getVolume()
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

function client:hookCall(name, ...)
	if log.level == "trace" then
		local args = {}
		for i=1, select("#", ...) do
			args[i] = tostring(select(i, ...))
		end
		log.trace("Call hook %s(%s)", name, table.concat(args, ", "))
	end
	if not self.hooks[name] then return end
	for desc, callback in pairs(self.hooks[name]) do
		local succ, ret = xpcall(callback, debug.traceback, self, ...)
		if not succ then
			log.error("%s (%s) error: %s", name, desc, ret)
		elseif ret then
			return ret
		end
	end
end

function client:auth(username, password, tokens)
	local version = packet.new("Version")

	local major, minor, patch = string.match(string.format("%06d", jit.version_num), "(%d%d)(%d%d)(%d%d)")

	version:set("version", lshift(tonumber(major), 16) + lshift(tonumber(minor), 8) + tonumber(patch))
	version:set("release", _VERSION)
	version:set("os", jit.os)
	version:set("os_version", jit.arch)

	self:sendTCP(version)

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

	self:sendTCP(auth)
end

function client:sendTCP(packet)
	log.trace("Send TCP %s to server", packet)
	return self.tcp:send(packet:toString())
end

function client:sendUDP(packet)
	local succ, encrypted = self.crypt:encrypt(packet:toString())
	if succ then
		log.trace("Send encrypted UDP %s to server", packet)
		return self.udp:send(encrypted)
	end
end

function client:sendAudioPacket(packet)
	if self.tunnel_udp then
		packet:seek("set", 2)
		packet:writeInt(packet.length - 6) -- Set size of payload
		self:sendTCP(packet)
	else
		self:sendUDP(packet)
	end
end

function client:getTime()
	return socket.gettime() - self.start
end

function client:getTimestamp()
	return math.floor(self:getTime() * 1000)
end

function client:pingTCP()
	local ping = packet.new("Ping")

	ping:set("timestamp", self:getTimestamp())
	ping:set("tcp_packets", self.ping.tcp_packets)
	ping:set("tcp_ping_avg", self.ping.tcp_ping_avg)
	ping:set("tcp_ping_var", self.ping.tcp_ping_avg)
	ping:set("udp_packets", self.ping.udp_packets)
	ping:set("udp_ping_avg", self.ping.udp_ping_avg)
	ping:set("udp_ping_var", self.ping.udp_ping_var)
	ping:set("resync", self.ping.resync)

	if self.crypt:isValid() then
		ping:set("good", self.crypt:getGood())
		ping:set("lost", self.crypt:getLost())
		ping:set("late", self.crypt:getLate())
	end

	self:sendTCP(ping)
	self.ping.tcp_ping_acc = self.ping.tcp_ping_acc + 1
end

function client:pingUDP()
	local b = buffer()
	b:writeByte(lshift(UDP_PING, 5))
	b:writeMumbleVarInt(self:getTimestamp())
	self:sendUDP(b)
	self.ping.udp_ping_acc = self.ping.udp_ping_acc + 1
end

local speakingEvent = {}

local function writeShort(f, short)
	-- Convert our 16 bit number into two bytes
	local b1 = bit.band(bit.rshift(short, 8), 0xFF)
	local b2 = bit.band(short, 0xFF)
	f:write(string.char(b1, b2))
end

local playbackf = assert(io.open("playback.vorbis", "ab"))

function client:receiveVoiceData(packet, codec, target)
	local session = packet:readMumbleVarInt()
	local sequence = packet:readMumbleVarInt()

	local user = self.users[session]

	local talking = false

	local data = ""

	if codec == UDP_SPEEX or codec == UDP_CELT_ALPHA or codec == UDP_CELT_BETA then
		local header = packet:readByte()
		talking = band(header, 0x80) ~= 0x80

		data = packet:readAll()
	elseif codec == UDP_OPUS then
		local header = packet:readMumbleVarInt()

		local len = band(header, 0x1FFF)
		talking = band(header, 0x2000) ~= 0x2000

		data = packet:readAll()

		--[[local b = self:createAudioPacket(UDP_OPUS, target, sequence)

		local all = packet:readAll()

		b:writeMumbleVarInt(header)
		b:write(all)

		self:sendAudioPacket(b)]]
	end

	local state_change = false
	local oneframespeak = (user.talking == false and talking == false)

	if user.talking ~= talking then
		user.talking = talking
		state_change = true
		for i=1,2 do
			if self.audio_streams[i] then
				self.audio_streams[i]:setUserTalking(talking)
			end
		end
	end

	local t = self:getTime()

	if oneframespeak or state_change and user.talking then
		self:hookCall("OnUserStartSpeaking", user)
		speakingEvent.last_packet = t
	end

	speakingEvent.codec = codec
	speakingEvent.target = target
	speakingEvent.sequence = sequence
	speakingEvent.user = user
	speakingEvent.speaking = user.talking
	speakingEvent.data = data
	speakingEvent.delay = t - speakingEvent.last_packet
	speakingEvent.last_packet = t

	--print("asd", speakingEvent.delay * 100, math.floor(speakingEvent.delay * 100 + 0.5) / 100)

	self:hookCall("OnUserSpeak", speakingEvent)

	if oneframespeak or state_change and not user.talking then
		self:hookCall("OnUserStopSpeaking", user)
	end
end

function client:doping()
	-- Check if we recieved 3 or more pings without the server responding..
	if self.ping.tcp_ping_acc >= 3 then
		-- Disconnect from the server, since we seem to have lost connection
		log.error("No response from server..", err)
		self:close()
		return false
	end

	if self.ping.udp_ping_acc >= 3 and not self.tunnel_udp then
		log.warn("Server no longer responding to UDP pings, falling back to TCP..")
		self.tunnel_udp = true
	end

	-- Only ping if we are fully synced with the server
	if self.synced then
		self:pingTCP()
		self:pingUDP()
	end

	return true
end

function client:readudp()
	local read, err = self.udp:receive(MAX_UDP_BUFFER)

	if read then
		local success, decrypted = self.crypt:decrypt(read)

		if success then
			local b = buffer(decrypted)

			local header = b:readByte()
			local id = rshift(header, 5)

			if id == UDP_PING then
				local timestamp = b:readMumbleVarInt()
				local time = self:getTimestamp()
				local ms = (time - timestamp)

				local n = self.ping.udp_packets + 1
				self.ping.udp_packets = n
				self.ping.udp_ping_avg = self.ping.udp_ping_avg * (n-1)/n + ms/n
				self.ping.udp_ping_var = math.abs(ms - self.ping.udp_ping_avg) ^ 2
				self.ping.udp_ping_acc = 0

				-- We have a UDP connection, do not tunnel through UDP
				self.tunnel_udp = false

				log.trace("Ping UDP: %0.2f ms", ms)
			elseif id == UDP_OPUS or id == UDP_SPEEX or id == UDP_CELT_ALPHA or id == UDP_CELT_BETA then
				-- UDP Voice data
				local target = band(header, 31)
				self:receiveVoiceData(b, id, target)
			end
		end
	elseif err == "wantread" then
	elseif err == "wantwrite" then
	elseif err == "timeout" then
	else
		log.error("UDP connection error %q", err)
		--self:close()
	end
end

function client:readtcp()
	local read = true
	local err

	-- Read everything the server has sent us
	while read do
		read, err = self.tcp:receive(6) -- Read the protobuf header information

		if read then
			local buff = buffer(read)

			local id = buff:readShort() -- 2 bytes
			local len = buff:readInt() -- 4 bytes
			
			if not id or not len then
				log.warn("malformed packet: %q", read)
			else
				read, err = self.tcp:receive(len) -- Read the remaining bytes in the packet

				if id == 1 then -- UDP Tunnel
					-- Handle voice data
					local voice = buffer(read)
					local header = voice:readByte()

					local codec = rshift(header, 5)
					local target = band(header, 31)

					self:receiveVoiceData(voice, codec, target)
				else
					-- Handle command packets
					local packet = packet.new(id, read)
					self:onPacketTCP(packet)
				end
			end
		elseif err == "wantread" then
		elseif err == "wantwrite" then
		elseif err == "timeout" then
		else
			-- Anything else is a connection error
			log.error("TCP connection error %q", err)
			self:close()
		end
	end
end

function client:createAudioPacket(codec, target, seq)
	local b = buffer()

	if self.tunnel_udp then
		-- Only needed for TCP packets
		b:writeShort(1) -- Type UDPTunnel
		b:writeInt(0) -- Size of payload
	end

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

local function readShort(f)
	local short = f:read(2) -- Read two characters from the file
	if not short or short == "" then return end -- End of file
	local b1, b2 = string.byte(short, 2, 1) -- Convert the two characters to bytes
	return bit.bor(bit.lshift(b1, 8), bit.lshift(b2, 0)) -- Combine the two bytes into a number
end

local function readShort(f)
	local short = f:read(2) -- Read two characters from the file
	if not short or short == "" then return end -- End of file
	local b1, b2 = string.byte(short, 1, 2) -- Convert the two characters to bytes
	return bit.bor(bit.lshift(b1, 8), bit.lshift(b2, 0)) -- Combine the two bytes into a number
end

--[[local function to16bitFloat(b1, b2)
	local intVal = BitConverter.ToInt32(new byte[] { HO, LO, 0, 0 }, 0);

	local mant = intVal & 0x03ff
	local exp = intVal & 0x7c00
	if (exp == 0x7c00) then
		exp = 0x3fc00
	elseif (exp != 0) then
		exp += 0x1c000;
		if (mant == 0 && exp > 0x1c400) then
			return BitConverter.ToSingle(BitConverter.GetBytes((intVal & 0x8000) << 16 | exp << 13 | 0x3ff), 0);
		end
	elseif (mant != 0) then
		exp = 0x1c400
		do
		{
			mant <<= 1;
			exp -= 0x400;
		} while ((mant & 0x400) == 0);
		mant &= 0x3ff;
	end
	return BitConverter.ToSingle(BitConverter.GetBytes((intVal & 0x8000) << 16 | (exp | mant) << 13), 0);
end]]

local floatconversion = ffi.new("union { char b[4]; float f; }")

function client:streamAudio()
	local biggest_pcm_size = 0

	-- Reset the buffer to all 0's
	ffi.fill(self.audio_buffer, ffi.sizeof(self.audio_buffer))

	-- Loop through each channel of audio and mix them together with simple addition.
	for channel, stream in pairs(self.audio_streams) do
		-- Get the PCM samples for our stream

		-- Get PCM data for a x * 10ms chunk
		local pcm, pcm_size = stream:streamSamples(self.audio_frames * 10, SAMPLE_RATE)

		if not pcm or not pcm_size or pcm_size <= 0 then
			-- If we have no PCM data, or the size is too small, we end the audio stream
			self.audio_streams[channel] = nil
			self:hookCall("AudioStreamFinish", channel)
		else
			if pcm_size > biggest_pcm_size then
				-- We need to save the biggest PCM data for later.
				-- If we didn't do this, we could be cutting off some audio if one
				-- stream ends while another is still playing.
				biggest_pcm_size = pcm_size
			end
			for i=0,pcm_size-1 do
				-- Mix all virtual audio channels together in the buffer
				self.audio_buffer[i].l = self.audio_buffer[i].l + pcm[i].l * self.audio_volume
				self.audio_buffer[i].r = self.audio_buffer[i].r + pcm[i].r * self.audio_volume
			end
		end
	end

	-- If the biggest pcm size is 0 or smaller then every stream has ended.
	if biggest_pcm_size <= 0 then return end

	local frame_size = self.audio_frames * SAMPLE_RATE / 100

	-- Encode our mixed audio.
	local encoded, encoded_len = self.encoder:encode(self.audio_buffer, frame_size, 0x1FFF)

	-- If nothing was encoded, stop here..
	if not encoded or encoded_len <= 0 then return end

	-- Check if the audio packet is too big.
	if encoded_len > 0x1FFF then
		log.error("encoded frame too large for audio packet..", encoded_len)
		return
	end

	-- If our longest bit of audio is smaller than the normal frame size of audio, it's the end of the stream..
	if biggest_pcm_size < frame_size then
		-- Set 14th bit to 1 to signal end of stream.
		encoded_len = bor(lshift(1, 13), encoded_len)
	end

	--[[if band(encoded_len, 0x2000) == 0x2000 then
		print("end of stream")
	end]]

	local b = self:createAudioPacket(UDP_OPUS, 0, self.audio_sequence)

	b:writeMumbleVarInt(encoded_len) -- Write the length of the encoded data in the header
	b:write(ffi.string(encoded, band(encoded_len, 0x1FFF))) -- Write encoded data

	self:sendAudioPacket(b)

	self.audio_sequence = (self.audio_sequence + 1) % 10240
end

function client:onPacketTCP(packet)
	local func = self["on" .. packet:getType()]

	if not func then
		log.warn("unimplemented %s", packet)
		return
	end

	log.trace("Received %s", packet)

	local succ, err = xpcall(func, debug.traceback, self, packet)
	if not succ then log.error(err) end
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
	local time = self:getTimestamp()

	local ms = (time - packet.timestamp)

	local n = self.ping.tcp_packets + 1
	self.ping.tcp_packets = n
	self.ping.tcp_ping_avg = self.ping.tcp_ping_avg * (n-1)/n + ms/n
	self.ping.tcp_ping_var = math.abs(ms - self.ping.tcp_ping_avg) ^ 2
	self.ping.tcp_ping_acc = 0

	log.trace("Ping TCP: %0.2f ms", ms)

	self:hookCall("OnPing", ms)
end

function client:onReject(packet)
	log.warn("rejected [%s][%s]", packet.type, packet.reason)
	self:hookCall("OnReject")
end

function client:onServerSync(packet)

	self.permissions[0] = packet.permissions
	self.session = packet.session
	self.config.max_bandwidth = packet.max_bandwidth

	self:createAudioStream(self.config.max_bandwidth)

	self.me = self.users[self.session]
	self.num_users = self.num_users + 1
	log.info("message: %s", packet.welcome_text:stripHTML())

	for session, user in pairs(self:getUsers()) do
		user:requestStats(true)
	end
	
	self.synced = true

	self:hookCall("OnServerSync", self.me)
end

function client:onChannelRemove(packet)
	local channel = self.channels[packet.channel_id]
	if channel.temporary then
		log.info("Temporary channel %s removed", channel)
	else
		log.info("Channel %s removed", channel)
	end
	self:hookCall("OnChannelRemove", event.new(self, packet))
	self.channels[packet.channel_id] = nil
end

function client:onChannelState(packet)
	if not self.channels[packet.channel_id] then
		local channel = channel.new(self, packet)
		self.channels[packet.channel_id] = channel
		if self.synced then
			if packet.temporary then
				log.info("Temporary channel %s created", channel)
			else
				log.info("Channel %s created", channel)
			end
			self:hookCall("OnChannelCreated", event.new(self, packet))
		end
	else
		local channel = self.channels[packet.channel_id]
		log.info("Channel %s updated", channel)
		channel:update(packet)
	end
	self:hookCall("OnChannelState", event.new(self, packet))
end

function client:onUserRemove(packet)
	local user = packet.session and self.users[packet.session]
	local actor = packet.actor and self.users[packet.actor]
	local event = event.new(self, packet, true)

	local message = "disconnected"
	
	if user and actor then
		local reason = (event.reason and event.reason ~= "") and event.reason or "No reason given"
		message = (event.ban and "banned by %s (Reason %q)" or "kicked by %s (Reason %q)"):format(actor, reason)
	else
		self.users[packet.session] = nil
		self.num_users = self.num_users - 1
	end
	log[user == self.me and "warn" or "info"]("%s %s", user, message)
	self:hookCall("OnUserRemove", event)
end

function client:onUserState(packet)
	local evnt
	local user

	if not self.users[packet.session] then
		user = cuser.new(self, packet)
		self.users[packet.session] = user
		self.num_users = self.num_users + 1
		user:requestStats(true)

		evnt = event.new(self, packet, true)

		if self.synced then
			local channel = self.channels[packet.channel_id or 0]
			log.info("%s connected to channel %s", user, channel)
			self:hookCall("OnUserConnected", evnt)
		end
	else
		user = self.users[packet.session]
		evnt = event.new(self, packet, true)
	end

	local channel = user:getChannel()

	if evnt.channel and evnt.channel ~= channel then
		evnt.channel_prev = channel
		user.channel_id_prev = user.channel_id

		if evnt.actor == user then
			log.info("%s moved to %s", user, evnt.channel)
		else
			log.info("%s moved to %s by %s", user, evnt.channel, evnt.actor or "the server")
		end

		self:hookCall("OnUserChannel", evnt)
	end

	user:update(packet)

	self:hookCall("OnUserState", evnt)
end

function client:onBanList(packet)
	self:hookCall("OnBanList")
end

function client:onTextMessage(packet)
	local event = event.new(self, packet, true)

	local msg = event.message:stripHTML():unescapeHTML()

	if msg[1] == "!" or msg[1] == "/" then
		local user = event.actor
		local args = msg:parseArgs()
		local cmd = table.remove(args,1):lower()
		local info = self.commands[cmd:sub(2)]
		local public = event.channel ~= nil or event.channels ~= nil
		
		if info then
			if info.master and not user:isMaster() then
				log.warn("%s: %s (PERMISSION DENIED)", user, msg)
				user:message("permission denied: %s", cmd)
			else
				local suc, err = pcall(info.callback, self, user, cmd, args, msg, public)
				if not suc then
					log.error("%s: %s (%q)", user, msg, err)
					user:message("congrats, you broke the <b>%s</b> command", cmd)
				end
			end
		else
			log.info("%s: %s (unknown command)", user, msg)
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
		log.warn("PermissionDenied: %s", permission.getType(packet.type))
	end
	self:hookCall("OnPermissionDenied")
end

function client:onACL(packet)
	local event = event.new(self, packet, true)
	self:hookCall("OnACL", event)
end

function client:onQueryUsers(packet)
	self:hookCall("OnQueryUsers")
end

function client:onCryptSetup(packet)
	for desc, value in packet:list() do
		self.crypt_keys[desc.name] = value
	end

	if packet.key and packet.client_nonce and packet.server_nonce then
		if not self.crypt:setKey(packet.key, packet.client_nonce, packet.server_nonce) then
			log.warn("CryptState: Cipher resync failed: Invalid key/nonce from the server")
		end
	elseif packet.server_nonce then
		self.ping.resync = self.ping.resync + 1
		if not self.crypt:setDecryptIV(packet.server_nonce) then
			log.warn("CryptState: Cipher resync failed: Invalid nonce from the server")
		end
	else
		local mpcs = packet.new("CryptSetup")
		mpcs:set("set_client_nonce", self.crypt:getEncryptIV())
		self:sendTCP(mpcs)
	end

	if self.crypt:isValid() then
		log.info("CryptState: \27[1;32m%s\27[0m", "VALID")
		-- Send a ping immediately to establish we have a UDP connection 
		self:pingUDP()
	else
		log.warn("CryptState: \27[38;5;208m%s\27[0m", "INVALID")
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
	self:hookCall("OnUserList", event.new(self, packet, true))
end

function client:onVoiceTarget(packet)
	self:hookCall("OnVoiceTarget")
end

function client:onPermissionQuery(packet)
	if packet.flush then
		self.permissions = {}
	end

	self.permissions[packet.channel_id] = packet.permissions

	local channel = self:getChannel(packet.channel_id)
	log.trace("Permissions for %s updated: %d", channel, packet.permissions)

	self:hookCall("OnPermissionQuery", self.permissions)
end

function client:hasPermission(channel, flag)
	local channel_id = channel:getID()

	if not self.permissions[channel_id] then
		local query = packet.new("PermissionQuery")
		query:set("channel_id", channel_id)
		self:sendTCP(query)
	end

	return band(self.permissions[channel_id] or 0, flag) > 0
end

function client:onCodecVersion(packet)
	self:hookCall("OnCodecVersion")
end

function client:onUserStats(packet)
	local user = self.users[packet.session]
	if not user then return end
	user:updateStats(packet)
	self:hookCall("OnUserStats", event.new(self, packet, true))
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

function client:onPluginDataTransmission(packet)
	self:hookCall("OnPluginData", event.new(self, packet, true))
end

function client:getHooks()
	return self.hooks
end

function client:getUsers()
	return self.users, self.num_users
end

function client:getUser(session)
	local tp = type(session)
	if tp == "number" then
		-- If the function is using a number as the argument, return user by session number
		return self.users[session]
	elseif tp == "string" then
		-- If the function is using a string as the argument, return user by their name
		for session, user in pairs(self.users) do
			if user:getName() == session then
				return user
			end
		end
	end
end

function client:getChannels()
	return self.channels
end

function client:getChannelRoot()
	-- Channel 0 is the root channel
	return self.channels[0]
end

function client:getChannel(index)
	local tp = type(index)
	if tp == "string" then
		-- Index channel by path name, starting from the root channel.
		return self.channels[0](index)
	elseif tp == "number" then
		-- Get channel by ID
		return self.channels[index]
	else
		-- Fallback to root as default
		return self.channels[0]
	end
end

function client:requestUserList()
	local msg = packet.new("UserList")
	self:sendTCP(msg)
end

function client:requestACL(channel_id)
	local channel_id = channel_id or 0 --default to root channel
	local query = packet.new("ACL")
	query:set("channel_id", channel_id)
	query:set("query", true)
	self:sendTCP(query)
end

function client:registerVoiceTarget(target_id, ...)
	local register = packet.new("VoiceTarget")
	register:set("id", target_id)
	for k,v in pairs({...}) do
		register:add("targets", targets)
	end
	self:sendTCP(register)
end

function client:createChannel(name, temporary)
	local chan = packet.new("ChannelState")
	chan:set("parent", 0)
	chan:set("name", name)
	chan:set("temporary", temporary)
	self:sendTCP(chan)
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
