local audio = {}

local buffer = require("buffer")

local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift
local bor = bit.bor

function audio.writeVarInt(b, i)
	if (i < 0x80) then
		b:writeByte(i)
		return 1
	elseif (i < 0x4000) then
		b:writeByte(bor(rshift(i, 8), 0x80))
		b:writeByte(band(i, 0xFF))
		return 2
	--[[elseif (i < 0x200000) then
		b:writeByte(bor(rshift(i, 16), 0xC0))
		b:writeByte(band(rshift(i, 8), 0xFF))
		b:writeByte(band(i, 0xFF))
		return 3
	elseif (i < 0x10000000) then
		b:writeByte(bor(rshift(i, 24), 0xE0))
		b:writeByte(band(rshift(i, 16), 0xFF))
		b:writeByte(band(rshift(i, 8), 0xFF))
		b:writeByte(band(i, 0xFF))
		return 4
	elseif (i < 0x100000000) then
		b:writeByte(0xF0)
		b:writeByte(band(rshift(i, 24), 0xFF))
		b:writeByte(band(rshift(i, 16), 0xFF))
		b:writeByte(band(rshift(i, 8), 0xFF))
		b:writeByte(band(i, 0xFF))
		return 5]]
	end
end

function audio.createPacket(mode, target, sequence)
	local b = buffer()
	local header = bor(lshift(mode, 5), target)
	b:writeByte(header)
	audio.writeVarInt(b, sequence)
	return b
end

return audio 