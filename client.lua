package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

local autoreload = require("autoreload")
--local terminal = require("terminal")
local concommand = require("concommand")
local mumble = require("lumble")

local socket = require("socket")

require("scripts")

while true do
	mumble.update()
	socket.sleep(0.02)
end

--[[local function main()
	autoreload.poll()
	mumble.update()
end

terminal.new(main, concommand.loop)
terminal.loop()]]

print()