local ffi = require("ffi")
local stb = require("lumble.vorbis")
local socket = require("socket")

local new = ffi.new

local STREAM = {}
STREAM.__index = STREAM

local function AudioStream(path, volume, count)
	local err = new('int[1]')
	local vorbis = stb.stb_vorbis_open_filename(path, err, nil)

	if err[0] > 0 then return nil, err[0] end

	return setmetatable({
		vorbis = vorbis,
		volume = volume or 0.25,
		fade_volume = 1,
		samples = stb.stb_vorbis_stream_length_in_samples(vorbis),
		info = stb.stb_vorbis_get_info(vorbis),
		buffer = {},
		loop_count = count or 0,
		frames_to_fade = 0,
		frames_faded_left = 0,
		is_user_talking = false,
		talking_count = 0,
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
	if self.talking_count >= 1 then
		self.fade_volume = 0.25
	else
		self:fadeTo(1, 1)
	end
end

function STREAM:streamSamples(duration)
	local frame_size = self.info.sample_rate * duration / 1000

	--[[if frame_size > 8191 then
		log.warn("frame too large for audio packet..", frame_size)
	end]]

	self.buffer[frame_size] = self.buffer[frame_size] or ffi.new('float[?]', frame_size)

	local samples = self.buffer[frame_size]

	local num_samples = stb.stb_vorbis_get_samples_float_interleaved(self.vorbis, 1, samples, frame_size)

	local fade_percent = 1

	if num_samples < frame_size and self.loop_count > 1 then
		self.loop_count = self.loop_count - 1
		self:seek("start")
	end

	for i=0,num_samples-1 do
		if self.frames_to_fade > 0 then
			if self.frames_faded_left > 0 then
				self.frames_faded_left = self.frames_faded_left - 1
				fade_percent = self.frames_faded_left / self.frames_to_fade
				self.fade_volume = self.fade_to_volume + (self.fade_from_volume - self.fade_to_volume) * fade_percent
			elseif self.fade_stop then
				self:seek("end")
				return nil, 0
			end
		end

		samples[i] = samples[i] * self.fade_volume * self.volume
		-- * 0.5 * (1+math.sin(2 * math.pi * 0.1 * socket.gettime()))
	end

	return samples, num_samples
end

function STREAM:setVolume(volume)
	self.volume = volume
end

function STREAM:fadeOut(time)
	self:fadeTo(0, time)
	self.fade_stop = true
end

function STREAM:fadeTo(volume, time)
	self.frames_to_fade = self.info.sample_rate * (time or 1)
	self.frames_faded_left = self.frames_to_fade
	self.fade_from_volume = self.fade_volume
	self.fade_to_volume = volume
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