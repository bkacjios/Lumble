local terminal = {}

local ev = require("ev")
local log = require("log")

local loop = ev.Loop.default

local function exit(loop, sig, revents)
	loop:unloop()
end

function terminal.new(main, input)
	local sig = ev.Signal.new(exit, ev.SIGINT)
	sig:start(loop)

	local evt = ev.IO.new(function()
		xpcall(input, debug.traceback)
	end, 0, ev.READ)
	evt:start(loop)

	local timer = ev.Timer.new(function()
		xpcall(main, debug.traceback)
	end, 0.1, 0.1)
	timer:start(loop)
end

function terminal.loop()
	ev.Loop.default:loop()
end

return terminal