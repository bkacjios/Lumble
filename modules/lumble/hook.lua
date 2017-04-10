local log = require("log")

local hook = {
	hooks = {},
}

function hook.add(name, desc, callback)
	if not hook.hooks[name] then hook.hooks[name] = {} end
	hook.hooks[name][desc] = callback
end

function hook.run(name, ...)
	if not hook.hooks[name] then return end
	for desc, callback in pairs(hook.hooks[name]) do
		local succ, ret = pcall(callback, ...)
		if not succ then
			log.error("hook error: %s (%s)", desc, ret)
		else
			return ret
		end
	end
end

return hook