local lfs = require("lfs")

lfs.chdir(arg[0]:match("^(.*[/\\])[^/\\]-$"))

package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

--require'log'.level = 'trace'
--local copas = require("copas")
local autoreload = require("autoreload")
local concommand = require("concommand")
local mumble = require("lumble")

local ev = require("ev")

require("scripts")

ev.Signal.new(function(loop, sig, revents)
	loop:unloop()
end, ev.SIGINT):start(ev.Loop.default)

ev.IO.new(function()
	xpcall(concommand.loop, debug.traceback)
end, 0, ev.READ):start(ev.Loop.default)

ev.Timer.new(function()
	autoreload.poll()
	mumble.update()
end, 1, 1):start(ev.Loop.default)

ev.Loop.default:loop()

print()

--[[mumble.setup()
copas.addthread(startup)
copas.loop()]]