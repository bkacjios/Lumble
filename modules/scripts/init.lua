local afk = require("scripts.afk")
local lua = require("scripts.lua")
local mumble = require("lumble")

local params = {
	mode = "client",
	protocol = "sslv23",
	key = "config/dongerbot.key",
	certificate = "config/dongerbot.pem",
}

local client = mumble.getClient("mbl27.gameservers.com", 10004, params)
client:auth("LuaBot")

client:hook("OnServerSync", function(client, me)
	local channel = client:getChannel("DongerBots Chamber of sentience learning")
	me:move(channel)
end)

lua.install(client)
afk.install(client)