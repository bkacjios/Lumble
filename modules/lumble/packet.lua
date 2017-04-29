local packet = {}
packet.__index = packet

local proto = require("lumble.proto")
local buffer = require("buffer")
local log = require("log")

function packet.new(id, data)
	local packet = setmetatable({}, packet)

	if type(id) == "number" then
		packet.proto = proto[proto.MESSAGE_TYPES[id + 1]]()
		packet.id = id
	elseif type(id) == "string" then
		packet.proto = proto[id]()
		packet.id = proto.MESSAGE_IDS[id]
	end

	if type(data) == "string" then
		packet.proto:ParseFromString(data)
	elseif data then
		packet.proto = data
	end

	return packet
end

function packet:__index(key)
	return rawget(self, "proto")[key] or rawget(self, key) or packet[key]
end

function packet:__tostring()
	return ("packet [%i][%s]"):format(self.id, self:getType())
end

function packet:set(key, value)
	self.proto[key] = value
end

function packet:add(key, value)
	table.insert(self.proto[key], value)
end

function packet:get(key)
	return self.proto[key]
end

function packet:list()
	return self.proto:ListFields()
end

function packet:getID()
	return self.id
end

function packet:getType()
	return proto.MESSAGE_TYPES[self.id + 1]
end

function packet:serialize()
	return self.proto:SerializeToString()
end

function packet:getRaw()
	local buff = buffer()
	buff:writeShort(self:getID())
	local data = self:serialize()
	buff:writeInt(#data)
	buff:write(data)
	return buff:getRaw()
end

return packet