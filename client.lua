package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

local mumble = require("lumble")
local afk = require("scripts.afk")

local client = mumble.connect("mbl27.gameservers.com", 10004, "config/dongerbot.pem", "config/dongerbot.key")
client:auth("LuaBot")

client:hook("OnServerSync", function(client, me)
	local channel = client:getChannel("DongerBots Chamber of sentience learning/DongerBots Chamber of sentience learning")
	me:move(channel)
end)

afk.install(client)

while client:update() do
	client:sleep(0.01)
end