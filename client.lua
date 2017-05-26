package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'
--require'log'.level = 'trace'
local copas = require("copas")
local autoreload = require("autoreload")
--local terminal = require("terminal")
local concommand = require("concommand")
local mumble = require("lumble")


local startup = require("scripts")

--[[local last = os.time()
while true do
	mumble.update()
	socket.sleep(0.01)
end]]


mumble.setup()
copas.addthread(startup)
copas.loop()