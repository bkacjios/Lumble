local ffi = require("ffi")
local stb = require("lumble.vorbis")
local socket = require("socket")

local new = ffi.new
local copy = ffi.copy
local sizeof = ffi.sizeof

local STREAM = {}
STREAM.__index = STREAM

local function AudioStream(path, volume, count)
	local err = new('int[1]')
	local vorbis = stb.stb_vorbis_open_filename(path, err, nil)

	if err[0] > 0 then return nil, err[0] end

	return setmetatable({
		vorbis = vorbis,
		samples = stb.stb_vorbis_stream_length_in_samples(vorbis),
		info = stb.stb_vorbis_get_info(vorbis),
		buffer = new('float[?]', 1024),
		rebuffer = new('float[?]', 1024),
		volume = volume or 0.25,
		loop_count = count or 0,
		talking_count = 0,
		fade_volume = 1,
		fade_frames = 0,
		fade_frames_left = 0,
		duck_volume = 1,
		duck_frames = 0,
		duck_frames_left = 0,
		ducked = false,
	}, STREAM)
end

function STREAM:getSampleCount()
	return self.samples
end

function STREAM:getInfo()
	return self.info
end

function STREAM:setUserTalking(talking)
	self.talking_count = self.talking_count + (talking and 1 or -1)
	if self.talking_count >= 1 and not self.ducked then
		self.ducked = true
		--self.duck_volume = 0.25
		self:duckTo(0.25, 0.2)
	else
		self.ducked = false
		self:duckTo(1, 1)
	end
end

function STREAM:streamSamples(duration, sample_rate, channels)
	local sample_size = self.info.sample_rate * duration / 1000

	local num_samples = stb.stb_vorbis_get_samples_float_interleaved(self.vorbis, 1, self.buffer, sample_size)
	local source_rate = self.info.sample_rate

	if source_rate ~= sample_rate then
		-- Resample the audio
		local scale = num_samples/sample_size
		local original_size = sample_size

		sample_size = sample_size * sample_rate / source_rate
		num_samples = math.ceil(sample_size * scale)

		for t=0,num_samples/2 do
			self.rebuffer[t * 2] = self.buffer[math.floor(t / sample_rate * source_rate) * 2] * 2
		end

		-- Copy our new buffer into the original buffer
		copy(self.buffer, self.rebuffer, sizeof(self.rebuffer))
	end

	local fade_percent = 1
	local duck_percent = 1

	if num_samples < sample_size and self.loop_count > 1 then
		self.loop_count = self.loop_count - 1
		self:seek("start")
	end

	for i=0,num_samples-1 do
		if self.fade_frames > 0 then
			if self.fade_frames_left > 0 then
				self.fade_frames_left = self.fade_frames_left - 1
				fade_percent = self.fade_frames_left / self.fade_frames
				self.fade_volume = self.fade_to_volume + (self.fade_from_volume - self.fade_to_volume) * fade_percent
			elseif self.fade_stop then
				self:seek("end")
				return nil, 0
			end
		end

		if self.duck_frames > 0 and self.duck_frames_left > 0 then
			self.duck_frames_left = self.duck_frames_left - 1
			duck_percent = self.duck_frames_left / self.duck_frames
			self.duck_volume = self.duck_to_volume + (self.duck_from_volume - self.duck_to_volume) * duck_percent
		end

		self.buffer[i] = self.buffer[i] * self.volume * self.fade_volume * self.duck_volume
		-- * 0.5 * (1+math.sin(2 * math.pi * 0.1 * socket.gettime()))
	end

	return self.buffer, num_samples
end

function STREAM:setVolume(volume)
	self.volume = volume
end

function STREAM:fadeOut(time)
	self:fadeTo(0, time)
	self.fade_stop = true
end

function STREAM:fadeTo(volume, time)
	self.fade_frames = self.info.sample_rate * (time or 1)
	self.fade_frames_left = self.fade_frames
	self.fade_from_volume = self.fade_volume
	self.fade_to_volume = volume
end

function STREAM:duckTo(volume, time)
	self.duck_frames = self.info.sample_rate * (time or 1)
	self.duck_frames_left = self.duck_frames
	self.duck_from_volume = self.duck_volume
	self.duck_to_volume = volume
end

function STREAM:getVolume()
	return self.volume
end

function STREAM:loop(count)
	self.loop_count = count or 0
end

function STREAM:seek(pos)
	if pos == "start" then
		stb.stb_vorbis_seek_start(self.vorbis)
	elseif pos == "end" then
		stb.stb_vorbis_seek(self.vorbis, self.samples)
	else
		stb.stb_vorbis_seek(self.vorbis, pos)
	end
end

function STREAM:close()
	stb.stb_vorbis_close(self.vorbis)
end
STREAM.__gc = STREAM.close

return AudioStream