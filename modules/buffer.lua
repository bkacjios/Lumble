local bit = require("bit")
local ffi = require('ffi')

local BUFFER = {}

local bor = bit.bor
local bnot = bit.bnot
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local byte = string.byte
local char = string.char

local new = ffi.new
local fill = ffi.fill
local copy = ffi.copy
local string = ffi.string

local min = math.min
local max = math.max
local ceil = math.ceil
local floor = math.floor
local frexp = math.frexp
local ldexp = math.ldexp

local insert = table.insert

local function Buffer(length)
	local string

	if type(length) == "string" then
		string = length
		length = #string
	elseif type(length) == "number" then
		length = max(length, 0)
	end

	local size = length or 32

	local meta = {
		position = 0,
		length = size,
	}

	if not length then
		meta.dynamic = true
		meta.capacity = meta.length * 2
		meta.length = 0
	else
		meta.capacity = meta.length
	end

	meta.buffer = new('unsigned char[?]', meta.capacity)

	if string then
		copy(meta.buffer, string, length)
	end

	return setmetatable(meta, BUFFER)
end

function BUFFER:setDynamic(b)
	self.dynamic = b
end

function BUFFER:getDynamic()
	return self.dynamic
end

function BUFFER:__tostring()
	return ("Buffer[%d/%d]"):format(self.length, self.capacity)
end

function BUFFER:getBuffer()
	return self.buffer
end

function BUFFER:__index(key)
	if type(key) == "number" then
		if key < 1 or key > self.length then return error("index out of bounds") end
		return self.buffer[key - 1]
	end
	return BUFFER[key]
end

function BUFFER:toString(pos, len)
	pos = pos and pos - 1 or 0
	len = len or (self.length - pos)
	return string(self.buffer + pos, len)
end

function BUFFER:clear()
	fill(self.buffer, self.length)
	self.position = 0
end

function BUFFER:__len()
	return self.length
end
BUFFER.len = BUFFER.__len

function BUFFER:write(str)
	local len = #str

	if self.length + len > self.capacity then
		if self.dynamic then
			local mult = (self.length + len) / self.capacity

			if ceil(mult) - mult < 0.5 then
				mult = mult + 1
			end

			self.capacity = self.capacity * ceil(mult)

			local new = new('unsigned char[?]', self.capacity)
			copy(new, self.buffer, self.length)
			self.buffer = new
		else
			len = self.length - self.position
		end
	end

	copy(self.buffer + self.position, str, len)
	self.position = self.position + len

	if self.dynamic and self.position >= self.length then
		self.length = self.length + len
	end
end

function BUFFER:peek(len)
	len = max(1, len or 1)
	len = min(self.length - self.position, len)
	return string(self.buffer + self.position, len)
end

function BUFFER:readLen(len)
	len = max(1, len or 1)
	len = min(self.length - self.position, len)
	local ret = self:peek(len)
	self.position = self.position + len
	return ret
end

function BUFFER:readAll()
	if self.position >= self.length then return nil end
	local ret = self:readLen(self.length - self.position)
	self.position = self.length
	return ret
end

function BUFFER:readLine()
	if self.position >= self.length then return nil end
	local startpos, endpos = self:toString(self.position + 1):find("\r?\n")
	if startpos and endpos then
		local ret = self:readLen(startpos - 1)
		self.position = endpos
		return ret
	else
		-- Read until EOF
		return self:readAll()
	end
end

function BUFFER:seek(whence, offset)
	whence = whence or "cur"
	offset = offset or 0
	if whence == "cur" then
		self.position = self.position + offset
	elseif whence == "set" then
		self.position = offset
	elseif whence == "end" then
		self.position = self.length + offset
	end
	return self.position
end

function BUFFER:read(...)
	local args = {...}

	if #args <= 0 then
		return self:readLine()
	end

	local returns = {}

	for n,arg in pairs(args) do
		local buffer = {}
		if type(arg) == "string" then
			if arg:sub(1,2) == "*a" then
				insert(returns, self:readAll())
			elseif arg:sub(1,2) == "*l" then
				insert(returns, self:readLine())
			else
				return error(format("bad argument #%i to 'read' (invalid format)",n))
			end
		elseif type(arg) == "number" then
			insert(returns, self:readLen(arg))
		end
	end

	if #returns > 0 then
		return unpack(returns)
	end

	return nil
end

function BUFFER:writeByte(...)
	self:write(char(...))
end
BUFFER.writeBytes = BUFFER.writeByte

function BUFFER:readChar()
	return self:readLen(1)
end

function BUFFER:readByte(len)
	if self.position >= self.length then return nil end
	return byte(self:readLen(len), 1, len)
end
BUFFER.readBytes = BUFFER.readByte

function BUFFER:writeInt(int)
	self:writeByte(band(rshift(int,24),0xFF), band(rshift(int,16),0xFF), band(rshift(int,8),0xFF), band(int,0xFF))
end

function BUFFER:readInt()
	if self.position >= self.length then return nil end
	return bor(lshift(self:readByte(), 24), lshift(self:readByte(), 16), lshift(self:readByte(), 8), lshift(self:readByte(), 0))
end

function BUFFER:writeMumbleVarInt(int)
	if (int < 0x80) then
		self:writeByte(int)
		return 1
	elseif (int < 0x4000) then
		self:writeByte(bor(rshift(int, 8), 0x80), band(int, 0xFF))
		return 2
	elseif (int < 0x200000) then
		self:writeByte(bor(rshift(int, 16), 0xC0), band(rshift(int, 8), 0xFF), band(int, 0xFF))
		return 3
	elseif (int < 0x10000000) then
		self:writeByte(bor(rshift(int, 24), 0xE0), band(rshift(int, 16), 0xFF), band(rshift(int, 8), 0xFF), band(int, 0xFF))
		return 4
	elseif (int < 0x100000000) then
		self:writeByte(0xF0, band(rshift(int, 24), 0xFF), band(rshift(int, 16), 0xFF), band(rshift(int, 8), 0xFF), band(int, 0xFF))
		return 5
	end
end

function BUFFER:readMumbleVarInt()
	local v = self:readByte()

	if band(v, 0x80) == 0x00 then
		return band(v, 0x7F)
	elseif band(v, 0xC0) == 0x80 then
		return bor(lshift(band(v, 0x3F), 8), self:readByte())
	elseif band(v, 0xF0) == 0xF0 then
		local c = band(v, 0xFC)
		if c == 0xF0 then
			return bor(lshift(self:readByte(), 24), lshift(self:readByte(), 16), lshift(self:readByte(), 8), self:readByte())
		elseif c == 0xF4 then
			return bor(lshift(self:readByte(), 56), lshift(self:readByte(), 48), lshift(self:readByte(), 40), lshift(self:readByte(), 32), lshift(self:readByte(), 24), lshift(self:readByte(), 16), lshift(self:readByte(), 8), self:readByte())
		elseif c == 0xF8 then
			return bnot(v)
		elseif c == 0xFC then
			return bnot(band(v, 0x03))
		end
	elseif band(v, 0xF0) == 0xE0 then
		return bor(lshift(band(v, 0x0F), 24), lshift(self:readByte(), 16), lshift(self:readByte(), 8), self:readByte())
	elseif band(v, 0xE0) == 0xC0 then
		return bor(lshift(band(v, 0x1F), 16), lshift(self:readByte(), 8), self:readByte())
	end
end

function BUFFER:writeVarInt(int)
	local bytes = 0
	while int > 127 do
		self:writeByte(bor(band(int, 127), 128))
		bytes = bytes + 1
		int = rshift(int, 7)
	end
	bytes = bytes + 1
	self:writeByte(band(int, 127))
	return bytes
end

function BUFFER:readVarInt(maxBytes)
	if self.position >= self.length then return nil end
	local ret = 0
	for i=0, maxBytes or 5 do
		local b = self:readByte()
		ret = bor(lshift(band(b, 127), (7 * i)), ret)
		if (band(b, 128) == 0) then
			break
		end
	end
	return ret
end

function BUFFER:writeFloat(float)
	if float == 0 then
		self:writeByte(0x00, 0x00, 0x00, 0x00)
	elseif float ~= float then
		self:writeByte(0xFF, 0xFF, 0xFF, 0xFF)
	else
		local sign = 0x00
		if float < 0 then
			sign = 0x80
			float = -float
		end
		local mantissa, exponent = frexp(float)
		exponent = exponent + 0x7F
		if exponent <= 0 then
			mantissa = ldexp(mantissa, exponent - 1)
			exponent = 0
		elseif exponent > 0 then
			if exponent >= 0xFF then
				self:writeByte(sign + 0x7F, 0x80, 0x00, 0x00)
				return
			elseif exponent == 1 then
				exponent = 0
			else
				mantissa = mantissa * 2 - 1
				exponent = exponent - 1
			end
		end
		mantissa = floor(ldexp(mantissa, 23) + 0.5)

		self:writeByte(sign + floor(exponent / 2), (exponent % 2) * 0x80 + floor(mantissa / 0x10000), floor(mantissa / 0x100) % 0x100, mantissa % 0x100)
	end
end

function BUFFER:readFloat()
	if self.position >= self.length then return nil end
	local b1, b2, b3, b4 = self:readByte(), self:readByte(), self:readByte(), self:readByte()
	local exponent = (b1 % 0x80) * 0x02 + floor(b2 / 0x80)
	local mantissa = ldexp(((b2 % 0x80) * 0x100 + b3) * 0x100 + b4, -23)
	if exponent == 0xFF then
		if mantissa > 0 then
			return 0 / 0
		else
			mantissa = math.huge
			exponent = 0x7F
		end
	elseif exponent > 0 then
		mantissa = mantissa + 1
	else
		exponent = exponent + 1
	end
	if b1 >= 0x80 then
		mantissa = -mantissa
	end
	return ldexp(mantissa, exponent - 0x7F)
end

function BUFFER:writeShort(short)
	self:writeByte(band(rshift(short,8),0xFF), band(short,0xFF))
end

function BUFFER:readShort()
	if self.position + 1 > self.length then return nil end
	return bor(lshift(self:readByte(), 8), lshift(self:readByte(), 0))
end

function BUFFER:writeString(str)
	self:writeVarInt(#str)
	self:write(str)
end

function BUFFER:readString()
	if self.position >= self.length then return nil end
	local len = self:readVarInt()
	return self:read(len)
end

function BUFFER:next()
	if self.position >= self.length then return nil end
	return byte(self:toString(self.position + 1, 1))
end

function BUFFER:readNullString()
	local null = self:toString(self.position + 1):find('%z')
	if null then
		return self:readLen(null)
	end
end

function BUFFER:peekPattern(pattern)
	local _, pos = self:toString(self.position + 1):find(pattern)
	if pos then
		return self:peek(pos), pos
	end
end

function BUFFER:readPattern(pattern)
	local _, pos = self:toString(self.position + 1):find(pattern)
	if pos then
		return self:readLen(pos)
	end
end

function BUFFER:writeNullString(str)
	self:write(str)
	self:writeByte(0x0)
end

function BUFFER:dump(buf)
	local len = self.length
	for i = 0, ceil(len/10)-1 do
		for x = i * 10, min((i+1)*10, len)-1 do
			io.write(('%.2x'):format(self.buffer[x]) .. ' ')
		end
		for i = min((i+1)*10, len), (i+1)*10 - 1 do
			io.write'   '
		end
		io.write( ' | ' )
		
		for x = i * 10, min((i+1)*10, len) - 1 do
			local ch = self.buffer[x]
			if ch < 32 or ch >= 200 then ch = '.'
			else ch = char(ch) end
			io.write(ch .. ' ')
		end
		io.write('\n')
	end
end

return Buffer