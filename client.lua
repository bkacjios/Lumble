package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'
--require'log'.level = 'trace'
local autoreload = require("autoreload")
local terminal = require("terminal")
local concommand = require("concommand")
local mumble = require("lumble")
local socket = require("socket")

require("scripts")

--[[local last = os.time()
while true do
	mumble.update()
	socket.sleep(0.01)
end]]

local function main()
	autoreload.poll()
	mumble.update()
end

terminal.new(main, concommand.loop)
terminal.loop()

print()