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