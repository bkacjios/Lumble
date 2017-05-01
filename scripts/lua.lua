local lua = {}

local log = require("log")

local sandbox_G = {}

local env = {
	string = _G.string,
	table = _G.table,
	pairs = _G.pairs,
	ipairs = _G.ipairs,
	pcall = _G.pcall,
	xpcall = _G.xpcall,
	type = _G.type,
	coroutine = _G.coroutine,
	next = _G.next,
	tostring = _G.tostring,
	tonumber = _G.tonumber,
	unpack = _G.unpack,
	assert = _G.assert,
	bit = _G.bit,
	os = {
		time = os.time,
		date = os.date,
		clock = os.clock,
		difftime = os.difftime,
	},
	__newindex = sandbox_G,
}

local function sandbox(user, func)
	local getPlayer = function(name)
		for session,user in pairs(user:getClient():getUsers()) do
			print(session, user)
			if user:getName() == name then
				return user
			end
		end
	end

	env.__index = function(self, index)
		return rawget(self, index) or getPlayer(index)
	end,

	setfenv(func, setmetatable({
		print = function(...)
			local txts = {}
			for k,v in pairs({...}) do
				table.insert(txts, tostring(v))
			end
			user:message(table.concat(txts, ",    "))
		end,
		me = user,
		client = user:getClient(),
	}, env))
end

function lua.run(user, str)
	local lua, err = loadstring(str)

	log.debug("%s ran: %s", user, str)
	
	if not lua then
		log.warn("%s compile error: (%s)", user, err)
		user:message("compile error: %s", err)
	else
		sandbox(user, lua)
		local status, err = pcall(lua)
		if not status then
			log.warn("%s runtime error: (%s)", user, err)
			user:message("runtime error: %s", err)
		end
	end
end

return lua