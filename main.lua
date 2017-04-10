package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

local mumble = require("lumble")
local socket = require("socket")

local client = mumble.connect("mbl27.gameservers.com", 10004) --, "config/dongerbot.pem", "config/dongerbot.key")
client:auth("LuaBot")

local connected = true

while connected do
	connected = client:update()
	socket.sleep(0.01)
end