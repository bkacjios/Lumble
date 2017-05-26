local ffi = require("ffi")
local stb = require("lumble.vorbis")

local new = ffi.new

local STREAM = {}
STREAM.__index = STREAM

function AudioStream(file)
	local err = new('int[1]')
	local vorbis = stb.stb_vorbis_open_filename(file, err, nil)
	if err[0] < 0 then return nil, stb.stb_vorbis_get_error(vorbis) end

	return setmetatable({
		vorbis = vorbis,
		volume = 0.25,
		samples = stb.stb_vorbis_stream_length_in_samples(vorbis),
		info = stb.stb_vorbis_get_info(vorbis),
		buffer = {}
	}, STREAM)
end

function STREAM:getSampleCount()
	return self.samples
end

function STREAM:getInfo()
	return self.info
end

function STREAM:streamSamples(duration)
	local frame_size = self.info.sample_rate * duration / 1000
	self.buffer[frame_size] = self.buffer[frame_size] or ffi.new('float[?]', frame_size)

	local samples = self.buffer[frame_size]

	local num_samples = stb.stb_vorbis_get_samples_float_interleaved(self.vorbis, 1, samples, frame_size)

	for i=0,num_samples-1 do
		samples[i] = samples[i] * self.volume
	end

	return samples, num_samples
end

function STREAM:setVolume(volume)
	self.volume = volume
end

function STREAM:getVolume()
	return self.volume
end

function STREAM:close()
	stb.stb_vorbis_close(self.vorbis)
end
STREAM.__gc = STREAM.close

return AudioStream