package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

local mumble = require("lumble")

local client = mumble.connect("mbl27.gameservers.com", 10004) --, "config/dongerbot.pem", "config/dongerbot.key")
client:auth("LuaBot")

client:hook("OnServerSync", function(me)
	local channel = client:getChannel("DongerBots Chamber of sentience learning/REPROGRAMMING AND ISOLATION CHAMBER")
	me:move(channel)
	channel:message("Hello!")
end)

while client:update() do
	client:sleep(0.01)
end