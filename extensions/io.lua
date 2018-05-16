local FILE = getmetatable(io.stdin)

local crc32 = require("hash.crc32")
local md5 = require("hash.md5")
local cast = require("ffi").cast

function FILE:crc32()
	local pos = self:seek()
	self:seek("set")
	local checksum = crc32(self:read("*a"))
	self:seek("set", pos)
	return tonumber(cast("unsigned int", checksum))
end

function FILE:md5()
	local pos = self:seek()
	self:seek("set")
	local m = md5.new()
	m:update(self:read("*a"))
	self:seek("set", pos)
	return md5.tohex(m:finish())
end

function FILE:readByte(len)
	len = len or 1
	return string.byte(self:read(len), 1, len)
end

function FILE:readChar()
	return self:read(1)
end

function FILE:readInt()
	return bit.lshift(self:readByte(), 24) + bit.lshift(self:readByte(), 16) + bit.lshift(self:readByte(), 8) + bit.lshift(self:readByte(), 0)
end

function FILE:readShort()
	return bit.lshift(self:readByte(), 8) + bit.lshift(self:readByte(), 0)
end

function FILE:readLines(lstart, lend)
	local count = 1
	local ret = ""

	for line in self:lines() do
		if count >= lstart and count <= lend then
			ret = ret .. line
		end
		count = count + 1
	end

	return ret
end