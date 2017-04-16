package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

local mumble = require("lumble")

local client = mumble.connect("mbl27.gameservers.com", 10004) --, "config/dongerbot.pem", "config/dongerbot.key")
client:auth("LuaBot")

while client:update() do
	client:sleep(0.01)
end