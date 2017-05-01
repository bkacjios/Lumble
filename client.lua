package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

require("extensions.string")

local mumble = require("lumble")
local afk = require("scripts.afk")
local lua = require("scripts.lua")
local terminal = require("terminal")
local concommand = require("concommand")

local client = mumble.connect("mbl27.gameservers.com", 10004, "config/dongerbot.pem", "config/dongerbot.key")
client:auth("LuaBot")

client:hook("OnServerSync", function(client, me)
	local channel = client:getChannel("DongerBots Chamber of sentience learning")
	me:move(channel)
end)

client:hook("OnTextMessage", function(client, event)
	local str = event.message:unescapeHTML():stripHTML()
	lua.run(event.actor, str)
end)

afk.install(client)

local function main()
	client:update()
end

terminal.new(main, concommand.loop)
terminal.loop()

print()