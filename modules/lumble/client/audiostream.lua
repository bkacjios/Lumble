local ffi = require("ffi")
local stb = require("lumble.vorbis")
local socket = require("socket")

local new = ffi.new
local copy = ffi.copy
local sizeof = ffi.sizeof

local STREAM = {}
STREAM.__index = STREAM

local CHANNELS = 2
local SAMPLE_RATE = 48000

local MAX_FRAMES = 6
local MAX_BUFFER_SIZE = MAX_FRAMES * SAMPLE_RATE * CHANNELS / 100

ffi.cdef[[
typedef struct AudioFrame {
	float l, r;
} AudioFrame;
]]

local function AudioStream(path, volume, count)
	local err = new('int[1]')
	local vorbis = stb.stb_vorbis_open_filename(path, err, nil)

	if err[0] > 0 then return nil, err[0] end

	return setmetatable({
		vorbis = vorbis,
		samples = stb.stb_vorbis_stream_length_in_samples(vorbis),
		info = stb.stb_vorbis_get_info(vorbis),
		buffer = new('AudioFrame[?]', MAX_BUFFER_SIZE),
		rebuffer = new('AudioFrame[?]', MAX_BUFFER_SIZE),
		volume = volume or 1,
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
		-- When people are talking, mark the audio as ducked, and abruptly fade the volume to 25%
		self.ducked = true
		self:duckTo(0.25, 0.2)
	else
		-- When no one is talking, unmark and raise volume back to 100% gradually over a second.
		self.ducked = false
		self:duckTo(1, 1)
	end
end

local ceil = math.ceil
local floor = math.floor

local m_time = 0
local m_phase = 0

function STREAM:streamSamples(duration, sample_rate)
	local channels = self.info.channels
	
	local source_rate = self.info.sample_rate
	local sample_size = source_rate * duration / 1000

	local num_samples = stb.stb_vorbis_get_samples_float_interleaved(self.vorbis, 2, ffi.cast("float*", self.buffer), sample_size * 2)

	--[[for i=0, num_samples do
		self.buffer[i].r = 0.2 * math.sin(2 * (math.pi*2) * 500 * m_time + m_phase);
		m_time = m_time + (1/48000)
	end]]

	if channels == 1 and num_samples > 0 then
		-- mix mono to stereo
		for i=0, num_samples do
			self.buffer[i].l = self.buffer[i].l / 2
			self.buffer[i].r = self.buffer[i].l
		end
	end

	if source_rate ~= sample_rate then
		-- Clear the rebuffer so we can use it again
		ffi.fill(self.rebuffer, ffi.sizeof(self.rebuffer))

		-- Resample the audio
		local scale = num_samples / sample_size

		sample_size = sample_size * sample_rate / source_rate
		num_samples = ceil(sample_size * scale)

		for t=0,num_samples/2 do
			-- Resample the audio to fit within the requested sample_rate
			local idx = floor(t / sample_rate * source_rate) * 2
			self.rebuffer[t * 2].l = self.buffer[idx].l * 2
			self.rebuffer[t * 2].r = self.buffer[idx].r * 2
		end

		-- Copy resampled audio back into the main buffer
		copy(self.buffer, self.rebuffer, sizeof(self.rebuffer))
	end

	local fade_percent = 1 -- How much fade has been applied.
	local duck_percent = 1 -- How much secondary fade has been applied.

	-- If it's the end of the audio stream, and we still have a loop counter..
	if num_samples < sample_size and self.loop_count > 1 then
		-- Subtract from loop counter and go back to the start
		self.loop_count = self.loop_count - 1
		self:seek("start")
	end

	local volume = 1

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

		volume = self.volume * self.fade_volume * self.duck_volume

		self.buffer[i].l = self.buffer[i].l * volume
		self.buffer[i].r = self.buffer[i].r * volume
		-- * 0.5 * (1+math.sin(2 * math.pi * 0.1 * socket.gettime()))
	end

	return self.buffer, num_samples
end

-- Set the volume
function STREAM:setVolume(volume)
	self.volume = volume
end

function STREAM:getVolume()
	return self.volume
end

-- Fade the audio to 0 over time, then stop the stream.
function STREAM:fadeOut(time)
	self:fadeTo(0, time)
	self.fade_stop = true
end

-- A method for fading audio to a specified volume over a duration.
function STREAM:fadeTo(volume, time)
	self.fade_frames = self.info.sample_rate * (time or 1)
	self.fade_frames_left = self.fade_frames
	self.fade_from_volume = self.fade_volume
	self.fade_to_volume = volume
end

-- A method for fading audio to a specified volume over a duration.
-- This is mostly used as a secondary fade for a music stream when someone is talking.
function STREAM:duckTo(volume, time)
	self.duck_frames = self.info.sample_rate * (time or 1)
	self.duck_frames_left = self.duck_frames
	self.duck_from_volume = self.duck_volume
	self.duck_to_volume = volume
end

-- Loop the stream a specified number of times.
function STREAM:loop(count)
	self.loop_count = count or 0
end

-- Seek to a position within the audio track.
function STREAM:seek(pos)
	if pos == "start" then
		stb.stb_vorbis_seek_start(self.vorbis)
	elseif pos == "end" then
		stb.stb_vorbis_seek(self.vorbis, self.samples)
	else
		stb.stb_vorbis_seek(self.vorbis, pos)
	end
end

-- Close the audio stream cleanly.
function STREAM:close()
	stb.stb_vorbis_close(self.vorbis)
end
STREAM.__gc = STREAM.close

return AudioStream