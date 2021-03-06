local ffi = require("ffi")
local lib = ffi.load("opus")

local gc, new, typeof = ffi.gc, ffi.new, ffi.typeof
local cast = ffi.cast
ffi.cdef[[
typedef int16_t opus_int16;
typedef int32_t opus_int32;
typedef uint16_t opus_uint16;
typedef uint32_t opus_uint32;

typedef struct OpusEncoder OpusEncoder;
typedef struct OpusDecoder OpusDecoder;

OpusEncoder *opus_encoder_create(opus_int32 Fs, int channels, int application, int *error);
int opus_encoder_init(OpusEncoder *st, opus_int32 Fs, int channels, int application);
opus_int32 opus_encode(OpusEncoder *st, const opus_int16 *pcm, int frame_size, unsigned char *data, opus_int32 max_data_bytes);
opus_int32 opus_encode_float(OpusEncoder *st, const float *pcm, int frame_size, unsigned char *data, opus_int32 max_data_bytes);
void opus_encoder_destroy(OpusEncoder *st);
int opus_encoder_ctl(OpusEncoder *st, int request, ...);

OpusDecoder *opus_decoder_create(opus_int32 Fs, int channels, int *error);
int opus_decoder_init(OpusDecoder *st, opus_int32 Fs, int channels);
int opus_decode(OpusDecoder *st, const unsigned char *data, int len, opus_int16 *pcm, int frame_size, int decode_fec);
int opus_decode_float(OpusDecoder *st, const unsigned char *data, int len, float *pcm, int frame_size, int decode_fec);
void opus_decoder_destroy(OpusDecoder *st);
int opus_decoder_ctl(OpusDecoder *st, int request,...);

const char *opus_strerror(int error);
const char *opus_get_version_string(void);
]]

OPUS_APPLICATION_VOIP = 2048
OPUS_APPLICATION_AUDIO = 2049

local encoder_get = {
	bandwidth = 4009,
	sample_rate = 4029,
	final_range = 4031,
	application = 4001,
	bitrate = 4003,
	max_bandwidth = 4005,
	vbr = 4007,
	complexity = 4011,
	inband_fec = 4013,
	packet_loss_perc = 4015,
	dtx = 4017,
	vbr_constraint = 4021,
	force_channels = 4023,
	signal = 4025,
	lookahead = 4027,
	lsb_depth = 4037,
	expert_frame_duration = 4041,
	prediction_disabled = 4043,
}

local encoder_set = {
	application = 4000,
	bitrate = 4002,
	max_bandwidth = 4004,
	vbr = 4006,
	bandwidth = 4008,
	complexity = 4010,
	inband_fec = 4012,
	packet_loss_perc = 4014,
	dtx = 4016,
	vbr_constraint = 4020,
	force_channels = 4022,
	signal = 4024,
	lsb_depth = 4036,
	expert_frame_duration = 4040,
	prediction_disabled = 4042,
}

local function throw(code)
	local version = ffi.string(lib.opus_get_version_string())
	local message = ffi.string(lib.opus_strerror(code))
	return error(string.format("[%s] %s", version, message))
end

local int_ptr = typeof("int[1]")
local opus_int32 = typeof("opus_int32")
local opus_int32_ptr = typeof("opus_int32[1]")

local Encoder = {}
Encoder.__index = Encoder

function Encoder:__new(sample_rate, channels, app)
	app = app or OPUS_APPLICATION_AUDIO

	local err = int_ptr()
	local state = lib.opus_encoder_create(sample_rate, channels, app, err)
	if err[0] < 0 then return throw(err[0]) end

	err = lib.opus_encoder_init(state, sample_rate, channels, app)
	if err < 0 then return throw(err) end

	gc(state, lib.opus_encoder_destroy)

	return state
end

function Encoder:encode(input, input_len, max_data_bytes)
	local data = new("unsigned char[?]", max_data_bytes)
	local ret = lib.opus_encode_float(self, cast("float*", input), input_len, data, max_data_bytes)
	if ret < 0 then return throw(ret) end

	return data, ret
end

function Encoder:set(name, value)
	if type(value) ~= 'number' then return throw(-1) end
	local id = encoder_set[name]
	if not id then return error("invalid set name '" .. name .. "'") end
	local ret = lib.opus_encoder_ctl(self, id, opus_int32(value))
	if ret < 0 and ret ~= -1000 then return throw(ret) end
	return ret
end

function Encoder:get(name)
	local id = encoder_get[name]
	if not id then return error("invalid get name '" .. name .. "'") end
	local ret = opus_int32_ptr()
	lib.opus_encoder_ctl(self, id, ret)
	ret = ret[0]
	if ret < 0 and ret ~= -1000 then return throw(ret) end
	return ret
end

function Encoder:reset()
	local ret = lib.opus_encoder_ctl(self, 4028)
	if ret < 0 and ret ~= -1000 then return throw(ret) end
	return ret
end


local Decoder = {}
Decoder.__index = Decoder

function Decoder:__new(sample_rate, channels)
	local err = int_ptr()
	local state = lib.opus_decoder_create(sample_rate, channels, err)
	if err[0] < 0 then return throw(err[0]) end

	err = lib.opus_decoder_init(state, sample_rate, channels)
	if err < 0 then return throw(err) end

	gc(state, lib.opus_decoder_destroy)

	return state
end

function Decoder:decode(encoded, encoded_len, max_data_bytes)
	local data = new("float[?]", max_data_bytes)
	local ret = lib.opus_decode_float(self, encoded, encoded_len, data, max_data_bytes, 0)
	if ret < 0 then return throw(ret) end

	return data, ret
end

function Decoder:set(name, value)
	if type(value) ~= 'number' then return throw(-1) end
	local id = encoder_set[name]
	if not id then return error("invalid set name '" .. name .. "'") end
	local ret = lib.opus_decoder_ctl(self, id, opus_int32(value))
	if ret < 0 and ret ~= -1000 then return throw(ret) end
	return ret
end

function Decoder:get(name)
	local id = encoder_get[name]
	if not id then return error("invalid get name '" .. name .. "'") end
	local ret = opus_int32_ptr()
	lib.opus_decoder_ctl(self, id, ret)
	ret = ret[0]
	if ret < 0 and ret ~= -1000 then return throw(ret) end
	return ret
end

function Decoder:reset()
	local ret = lib.opus_decoder_ctl(self, 4028)
	if ret < 0 and ret ~= -1000 then return throw(ret) end
	return ret
end

return {
	Encoder = ffi.metatype("OpusEncoder", Encoder),
	Decoder = ffi.metatype("OpusDecoder", Decoder),
}