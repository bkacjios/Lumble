local prefix = SYNCHRONUS_PREFIX or "synchronous."
local impl = setmetatable({}, require(prefix..'taskmgr'))
local socket = require'socket'
local gettime
function impl:canBlock()
	return true
end
function impl:process(theTask, data)
	if gettime() > data then
		self:resumeTask(theTask)
	end
end
function impl:poll(block)
	self:iterate(self.process)
end
local wrapper = {} wrapper.__index = function(self, k)
	if wrapper[k] then return wrapper[k] end
	--if k == 'close' then error(debug.traceback()) end
	if self.socket[k] then
		wrapper[k] = function(self, ...)
			return self.socket[k](self.socket,...)
		end
		return wrapper[k]
	end
end
local passableErrors = {
	['timeout'] = true,
	['wantread'] = true,
	['wantwrite'] = true,
	['Operation already in progress'] = true
}
--Connects to a server
function wrapper:connect(address, port)
	--print'connection attempt'
	--print(debug.traceback())
	while true do
		local suc, err = self.socket:connect(address, port)
		if err and passableErrors[err] then
		elseif err == 'already connected' then
			return true
		elseif not suc then
			return false, err
		else
			return true 
		end
		
		--print(require'synchronous'.getCurrentTask())
		impl:addTask({self, 'send'})
		--print(require'synchronous'.getCurrentTask())
	end
end
local ssl
function wrapper:dohandshake(params)
	ssl = ssl or require'ssl'
	local newsock, err = ssl.wrap(self.socket, params)
	if not newsock then
		return false, err
	end
	self.socket = newsock
	newsock:settimeout(0)
	while true do
		local suc, err = newsock:dohandshake()
		if suc then return self end
		if err == 'wantread' then
			impl:addTask({self, 'recv'})
		elseif err == 'wantwrite' then
			impl:addTask({self, 'send'})
		else
			return false, err
		end
	end
end
function wrapper:receive(pattern, prefix, immediate) 
	local buffer = prefix and {prefix} or {}
	local all = pattern == '*a'
	if all then pattern = 0xFFF end
	while true do
		local suc = impl:addTask({self, 'recv'})
		
		--print(#impl.recvt,coroutine.yield())
		--if err ~= 'wantread' then
		if not suc then return suc, err end
		local suc, err, partial = self.socket:receive(pattern)
		
		if not suc and not passableErrors[err] and not all then
			return false, err, partial
		elseif (suc or (partial and immediate)) then
			if #buffer == 0 then return (prefix or '') .. (suc or partial) end
			if partial then
				return (prefix or '') .. partial
			else
				table.insert(buffer, suc)
			end
			return table.concat(buffer)
		elseif partial and #partial > 0 then
			table.insert(buffer, partial)
		elseif not passableErrors[err] then break end
		if suc and (pattern == '*l') then break end
		if type(pattern) == 'number' and (suc or partial) then
			pattern = pattern - (suc and #suc or #partial)
			if pattern <= 0 then break end
		end
		--end
	end
	return table.concat(buffer)
end
function wrapper:send(data, i, j)
	i = i or 1
	j = j or #data
	while i < j do
		local suc, err = impl:addTask({self, 'send'})
		if not suc then return suc, err end
		suc, err = self.socket:send(data, i, j)
		if suc then i = suc else return suc, err end
	end
	return 1
end
--This call is BLOCKING!
--It will not return until someone is accepted or there is an (irrecoverable?) error.
function wrapper:accept()
	while true do
		impl:addTask({self, 'send'})
		local ret, err = self.socket:accept()
		if ret then return impl:wrapSocket(ret) end
		if not passableErrors[err] then
			return false, err
		end
	end
end

------End Wrapper-------

function impl:onTaskAdded(task, data)
	
	local action = data[2]
	
	data[1].task = task
	task.job = data
end
local tblCache = {}
function impl:pollSockets(task, job)
	--This isn't ideal at all, but due to WinSock issues and some POSIX ones, I have to select one at a time.
	--If anyone is able to resolve this, please let me know!
	
	local wrapper = job[1]
	local sock = wrapper.socket
	local action = job[2]
	
	tblCache[1] = sock
	if action:find'send' then
		local r, s, er = socket.select(nil, tblCache, 0)
		if #s > 0 then
			self:wakeTask(task, true)
		end
	elseif action:find'recv' then
		--print('hi')
		local r, s, er = socket.select(tblCache, nil, 0)
		--print(r,s,er,#tblCache,#r)
		if #r > 0 then
			self:wakeTask(task, true)
		end
	end
	
end
function impl:canBlock()
	return #impl.sendt > 0 or #impl.recvt > 0
end
function impl:poll(sleep)
	local rcv, snd, err
	--print(#self.recvt, #self.sendt, self.recvt[1], self.sendt[1])
	
		--rcv,snd,err = socket.select(self.recvt, self.sendt, 1)
		
		
		-- if rcv then 
			-- self:iterate(self.pollIterator, rcv, impl.recvt)
		-- end
		-- if snd then
			-- self:iterate(self.pollIterator, snd, impl.sendt)
		-- end
	self:iterate(self.pollSockets)
			
end
function impl:onTaskRemoved( task, job, noRemove )
	task.job = nil
	
	if not noRemove then
		for i = 1, #impl.sendt do
			if impl.sendt[i] == job[1].socket then
				table.remove(impl.sendt, i)
				break
			end
		end
		for i = 1, #impl.recvt do
			if impl.recvt[i] == job[1].socket then
				table.remove(impl.recvt, i)
				break
			end
		end
	end
	
end

function impl.wrapSocket(socket)
	--if type(socket) == 'boolean' then print(debug.traceback()) end
	socket:settimeout(0)
	return setmetatable({socket=socket}, wrapper)
end
function impl:init(synch, inst)
	getCurrentTask = synch.getCurrentTask
	synch.wrapSocket = impl.wrapSocket
	gettime = synch.getTime
end
impl.sendt = {}
impl.recvt = {}
return impl