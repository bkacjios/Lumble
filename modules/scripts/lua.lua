local lua = {}

local log = require("log")

local env = {
	assert = assert,
	error = error,
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	pcall = pcall,
	select = select,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	_VERSION = _VERSION,
	xpcall = xpcall,
	bit = {
		tobit = bit.tobit,
		tohex = bit.tohex,
		bnot = bit.bnot,
		band = bit.band,
		bor = bit.bor,
		bxor = bit.bxor,
		lshift = bit.lshift,
		rshift = bit.rshift,
		arshift = bit.arshift,
		rol = bit.rol,
		ror = bit.ror,
		bswap = bit.bswap,
	},
	math = {
		abs = math.abs, acos = math.acos, asin = math.asin, 
		atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos, 
		cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, 
		fmod = math.fmod, frexp = math.frexp, huge = math.huge, 
		ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, 
		min = math.min, modf = math.modf, pi = math.pi, pow = math.pow, 
		rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh, 
		sqrt = math.sqrt, tan = math.tan, tanh = math.tanh,
	},
	string = {
		byte = string.byte, char = string.char, find = string.find, 
		format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
		len = string.len, lower = string.lower, match = string.match, 
		rep = string.rep, reverse = string.reverse, sub = string.sub, 
		upper = string.upper,
	},
	table = {
		concat = table.concat,
		foreach = table.foreach,
		foreachi = table.foreachi,
		getn = table.getn,
		insert = table.insert,
		maxn = table.maxn,
		pack = table.pack,
		unpack = table.unpack or unpack,
		remove = table.remove, 
		sort = table.sort,
	},
	coroutine = {
		create = coroutine.create,
		resume = coroutine.resume,
		running = coroutine.running,
		status = coroutine.status,
		wrap = coroutine.wrap,
		yield = coroutine.yield,
	},
	jit = {
		version = jit.version,
		version_num = jit.version_num,
		os = jit.os,
		arch = jit.arch,
	},
	os = {
		clock = os.clock,
		date = os.date,
		difftime = os.difftime,
		time = os.time,
	},
}
env._G = env
env.__newindex = env

local function sandbox(user, func)
	local getUser = function(name)
		for session,user in pairs(user:getClient():getUsers()) do
			if user:getName() == name then
				return user
			end
		end
	end

	env.__index = function(self, index)
		return rawget(env, index) or getUser(index)
	end,

	setfenv(func, setmetatable({
		print = function(...)
			local txts = {}
			for i=1, select("#", ...) do
				table.insert(txts, tostring(select(i, ...)))
			end
			user:message(table.concat(txts, ", "))
		end,
		me = user,
		bot = user:getClient().me,
		client = user:getClient(),
		users = user:getClient():getUsers(),
		channel = user:getChannel(),
	}, env))
end

function lua.run(client, event)
	local str = event.message:unescapeHTML():stripHTML()
	local user = event.actor

	-- Ignore chat messages to the entire channel
	if event.channels or str:sub(1,1) == "#" then return end

	local lua, err = loadstring(str)

	log.debug("%s ran: %s", user, str)
	
	if not lua then
		log.warn("%s compile error: (%s)", user, err)
		user:message("compile error: %s", err:escapeHTML())
	else
		sandbox(user, lua)

		local quota = 5000

		local timeout = function()
			error("instructions exceeded", 2)
		end

		jit.off()
		debug.sethook(timeout, "", quota)

		local status, err = pcall(lua)
		if not status then
			log.warn("%s runtime error: (%s)", user, err)
			user:message("runtime error: %s", err:escapeHTML())
		elseif err then
			user:message(tostring(err))
		end

		debug.sethook()
		jit.on()
	end
end

function lua.install(client)
	client:hook("OnTextMessage", "Lua - Run", lua.run)
end

return lua