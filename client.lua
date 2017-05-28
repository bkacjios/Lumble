package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'
require'log'.level = 'trace'
local synch = require'synchronous'
synch.registerTaskManager(require'synchronous.luasocket')
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

synch.addThread(startup)
mumble.setup()
synch.loop()
--copas.addthread(startup)
--copas.loop()