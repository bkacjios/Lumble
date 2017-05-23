local bit = require("bit")
local ffi = require('ffi')

local BUFFER = {}
BUFFER.__index = BUFFER

local function Buffer(length)
	local string

	if type(length) == "string" then
		string = length
		length = #string
	elseif type(length) == "number" then
		length = math.max(length, 0)
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

	meta.buffer = ffi.new('unsigned char[?]', meta.capacity)

	if string then
		ffi.copy(meta.buffer, string, length)
	end

	return setmetatable(meta, BUFFER)
end

function BUFFER:__tostring()
	return ("Buffer[%d/%d]"):format(self.length, self.capacity)
end

function BUFFER:getBuffer()
	return self.buffer
end

function BUFFER:toString(i, j)
	local offset = i and i - 1 or 0
	return ffi.string(self.buffer + offset, (j or self.length) - offset)
end

function BUFFER:clear()
	ffi.fill(self.buffer, self.length)
	self.position = 0
end

function BUFFER:__len()
	return self.length
end
BUFFER.len = BUFFER.__len

function BUFFER:write(str)
	local len = #str

	if self.position + len > self.capacity then
		if self.dynamic then
			local pow = 2
			local mult = (self.length + len) / self.capacity

			if math.ceil(mult) - mult < 0.5 then
				mult = mult + 1
			end

			self.capacity = self.capacity * math.ceil(mult)

			local new = ffi.new('unsigned char[?]', self.capacity)
			ffi.copy(new, self.buffer, self.length)

			self.buffer = new
		else
			len = self.length - self.position
		end
	end

	ffi.copy(self.buffer + self.position, str, len)
	self.position = self.position + len

	if self.dynamic then
		self.length = self.length + len
	end
end

function BUFFER:readLen(len)
	len = math.max(1, len or 1)
	len = math.min(self.length - self.position, len)
	local ret = ffi.string(self.buffer + self.position, len)
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
	local startpos, endpos = self:toString():find("\r?\n", self.position + 1)
	if startpos and endpos then
		local ret = self:readLen(startpos - 1 - self.position)
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
				table.insert(returns, self:readAll())
			elseif arg:sub(1,2) == "*l" then
				table.insert(returns, self:readLine())
			else
				return error(format("bad argument #%i to 'read' (invalid format)",n))
			end
		elseif type(arg) == "number" then
			table.insert(returns, self:readLen(arg))
		end
	end

	if #returns > 0 then
		return unpack(returns)
	end

	return nil
end

function BUFFER:writeByte(...)
	self:write(string.char(...))
end

function BUFFER:readChar()
	return self:readLen(1)
end

function BUFFER:readByte(len)
	if self.position >= self.length then return nil end
	return string.byte(self:readLen(len), 1, len)
end

function BUFFER:writeInt(int)
	self:writeByte(bit.band(bit.rshift(int,24),0xFF))
	self:writeByte(bit.band(bit.rshift(int,16),0xFF))
	self:writeByte(bit.band(bit.rshift(int,8),0xFF))
	self:writeByte(bit.band(int,0xFF))
end

function BUFFER:readInt()
	if self.position >= self.length then return nil end
	return bit.lshift(self:readByte(), 24) + bit.lshift(self:readByte(), 16) + bit.lshift(self:readByte(), 8) + bit.lshift(self:readByte(), 0)
end

function BUFFER:writeVarInt(int)
	local bytes = 0
	while int > 127 do
		self:writeByte(bit.bor(bit.band(int, 127), 128))
		bytes = bytes + 1
		int = bit.rshift(int, 7)
	end
	bytes = bytes + 1
	self:writeByte(bit.band(int, 127))
	return bytes
end

function BUFFER:readVarInt(maxBytes)
	if self.position >= self.length then return nil end
	local ret = 0
	for i=0, maxBytes or 5 do
		local b = self:readByte()
		ret = bit.bor(bit.lshift(bit.band(b, 127), (7 * i)), ret)
		if (bit.band(b, 128) == 0) then
			break
		end
	end
	return ret
end

function BUFFER:writeFloat(float)
	if float == 0 then
		self:writeByte(0x00)
		self:writeByte(0x00)
		self:writeByte(0x00)
		self:writeByte(0x00)
	elseif float ~= float then
		self:writeByte(0xFF)
		self:writeByte(0xFF)
		self:writeByte(0xFF)
		self:writeByte(0xFF)
	else
		local sign = 0x00
		if float < 0 then
			sign = 0x80
			float = -float
		end
		local mantissa, exponent = math.frexp(float)
		exponent = exponent + 0x7F
		if exponent <= 0 then
			mantissa = math.ldexp(mantissa, exponent - 1)
			exponent = 0
		elseif exponent > 0 then
			if exponent >= 0xFF then
				self:writeByte(sign + 0x7F)
				self:writeByte(0x80)
				self:writeByte(0x00)
				self:writeByte(0x00)
				return
			elseif exponent == 1 then
				exponent = 0
			else
				mantissa = mantissa * 2 - 1
				exponent = exponent - 1
			end
		end
		mantissa = math.floor(math.ldexp(mantissa, 23) + 0.5)

		self:writeByte(sign + math.floor(exponent / 2))
		self:writeByte((exponent % 2) * 0x80 + math.floor(mantissa / 0x10000))
		self:writeByte(math.floor(mantissa / 0x100) % 0x100)
		self:writeByte(mantissa % 0x100)
	end
end

function BUFFER:readFloat()
	if self.position >= self.length then return nil end
	local b1, b2, b3, b4 = self:readByte(), self:readByte(), self:readByte(), self:readByte()
	local exponent = (b1 % 0x80) * 0x02 + math.floor(b2 / 0x80)
	local mantissa = math.ldexp(((b2 % 0x80) * 0x100 + b3) * 0x100 + b4, -23)
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
	return math.ldexp(mantissa, exponent - 0x7F)
end

function BUFFER:writeShort(short)
	self:writeByte(bit.band(bit.rshift(short,8),0xFF))
	self:writeByte(bit.band(short,0xFF))
end

function BUFFER:readShort()
	if self.position + 1 > self.length then return nil end
	return bit.lshift(self:readByte(), 8) + bit.lshift(self:readByte(), 0)
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
	local nxt = self.position + 1
	return string.byte(self.buffer:sub(nxt, nxt))
end

function BUFFER:readNullString()
	local null = self:toString():find('%z', self.position + 1)
	if null then
		return self:readLen(null - self.position)
	end
end

function BUFFER:writeNullString(str)
	self:write(str)
	self:writeByte(0x0)
end

return Buffer