package.path = package.path .. ';./modules/?.lua;./modules/?/init.lua'

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