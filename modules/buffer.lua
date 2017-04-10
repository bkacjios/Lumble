local bit = require("bit")

local BUFFER = {}
BUFFER.__index = BUFFER

local function Buffer(str)
	return setmetatable({buffer = str or "", position = 1}, BUFFER)
end

function BUFFER:getBuffer()
	return self.buffer
end

function BUFFER:getRaw()
	return self.buffer
end

function BUFFER:__len()
	return string.len(self.buffer)
end

function BUFFER:length()
	return string.len(self.buffer)
end
BUFFER.len = BUFFER.length

function BUFFER:write( str )
	local before = string.sub(self.buffer, 0, self.position - 1) or ""
	local after = string.sub(self.buffer, self.position) or ""
	self.buffer = before .. str .. after
	self.position = self.position + string.len(str)
end

function BUFFER:writeByte(byte)
	self:writeChar(string.char(byte))
end

function BUFFER:writeChar(char)
	self:write(char)
end

function BUFFER:readChar()
	local ret = string.sub(self.buffer, self.position, self.position)
	self.position = self.position + 1
	return ret
end

function BUFFER:readByte()
	return string.byte(self:readChar())
end

function BUFFER:writeInt( int )
	self:writeByte(bit.band(bit.rshift(int,24),0xFF))
	self:writeByte(bit.band(bit.rshift(int,16),0xFF))
	self:writeByte(bit.band(bit.rshift(int,8),0xFF))
	self:writeByte(bit.band(int,0xFF))
end

function BUFFER:readInt()
	return bit.lshift(self:readByte(), 24) + bit.lshift(self:readByte(), 16) + bit.lshift(self:readByte(), 8) + bit.lshift(self:readByte(), 0)
end

function BUFFER:writeFloat( float )
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
	return bit.lshift(self:readByte(), 8) + bit.lshift(self:readByte(), 0)
end

function BUFFER:writeString(str)
	self:writeShort(#str)
	self:write(str)
end

function BUFFER:readString()
	local len = self:readShort() - 1
	local ret = string.sub(self.buffer, self.position, self.position + len)
	self.position = self.position + len + 1
	return ret
end

function BUFFER:seek( pos )
	self.position = pos
end

function BUFFER:next()
	local nxt = self.position + 1
	return string.byte(string.sub(self.buffer, nxt, nxt))
end

function BUFFER:sendTo(sock)
	return sock:send(self:getRaw())
end

return Buffer