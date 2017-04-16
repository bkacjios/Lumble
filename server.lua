package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

local mumble = require("lumble")

local server = mumble.host("192.168.1.230", 10004, "config/dongerbot.pem", "config/dongerbot.key")

while server:update() do
	server:sleep(0.01)
end