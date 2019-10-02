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

local function exit(loop, sig, revents)
	loop:unloop()
end

ev.Signal.new(exit, ev.SIGINT):start(ev.Loop.default)

local evt = ev.IO.new(function()
	xpcall(concommand.loop, debug.traceback)
end, 0, ev.READ)
evt:start(ev.Loop.default)

local timer = ev.Timer.new(function()
	autoreload.poll()
end, 1, 1)
timer:start(ev.Loop.default)

local timer = ev.Timer.new(function()
	mumble.update()
end, 10, 10)
timer:start(ev.Loop.default)

ev.Loop.default:loop()

print()

--[[mumble.setup()
copas.addthread(startup)
copas.loop()]]