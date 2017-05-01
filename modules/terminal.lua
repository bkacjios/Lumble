local terminal = {}

local ev = require("ev")
local log = require("log")

local loop = ev.Loop.default

local function error(str)
	log.error(debug.traceback(str, 2))
end

local function exit(loop, sig, revents)
	loop:unloop()
end

function terminal.new(main, input)
	local sig = ev.Signal.new(exit, ev.SIGINT)
	sig:start(loop)

	local evt = ev.IO.new(function()
		xpcall(input, error)
	end, 0, ev.READ)
	evt:start(loop)

	local timer = ev.Timer.new(function()
		xpcall(main, error)
	end, 0.01, 0.01)
	timer:start(loop)
end

function terminal.loop()
	ev.Loop.default:loop()
end

return terminal