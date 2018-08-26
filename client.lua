local lfs = require("lfs")

lfs.chdir(arg[0]:match("^(.*[/\\])[^/\\]-$"))

package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

--require'log'.level = 'trace'
--local copas = require("copas")
local autoreload = require("autoreload")
local terminal = require("terminal")
local concommand = require("concommand")
local mumble = require("lumble")

require("scripts")

local function main()
	autoreload.poll()
	mumble.update()
end

terminal.new(main, concommand.loop)
terminal.loop()

print()

--[[mumble.setup()
copas.addthread(startup)
copas.loop()]]