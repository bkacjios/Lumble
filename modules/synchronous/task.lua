--A task is a thing that does something, perhaps to something or to a thing
--but for some task manager.
--Tasks are just coroutine objects with a custom metatable.
local Task = {} Task.__index = Task
function Task:wake(...)
	self.ran = true
	--self:terminate(true)
	if(not self:isActive()) then
		return self:terminate()
	end
	
	local data = (self.arguments and not (select('#', ...) > 0)) and {coroutine.resume(self.coroutine, unpack(self.arguments))} or {coroutine.resume(self.coroutine, ...)}
	
	if not data[1] then
		print("Synchronous Task Error: " .. data[2])
		self:callHook("error", data[2])
		self:callHook("death")
		return 'error', data[2]
	elseif coroutine.status(self.coroutine) == 'dead' then
		self:callHook("death", unpack(data, 2))
		return 'dead', unpack(data, 2)
	end
	return false
end
--If a coroutine is alive, return true.
function Task:isActive()
	return self.ran and coroutine.status(self.coroutine) ~= 'dead'
end
function Task:yield(...)
	return coroutine.yield(...)
end
function Task:hook(name, callback, ...)
	if not self.hooks[name] then self.hooks[name] = {} end
	table.insert(self.hooks[name], {callback, ...})
	return self
end
function Task:callHook(name, ...)
	if not self.hooks[name] then return end
	for k, v in pairs(self.hooks[name]) do
		v(...)
	end
end
return Task