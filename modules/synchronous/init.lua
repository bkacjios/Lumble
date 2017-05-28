--[[
Synchronous by Somepotato
All code, software, documentation, and any other data
for this project are to be licensed under the 2-clause BSD license.
]]
local M = {
	_NAME = "Synchronous",
	_DESC = "A task scheduling library for LuaJIT.",
	_VERSION="1.0.0"
}
local prefix = SYNCHRONOUS_PREFIX or "synchronous."
local tm = require(prefix .. 'taskmgr')
local tk = require(prefix .. 'task')
require(prefix .. 'platform')(M)

M.tasklist = {}
M.sleepingTasks = {}
M.managers = {}
M.timers = {}
--This will not affect timers!
--Setting this will determine how often each task manager is polled.
--Timers will always override this if more accuracy is needed.
M.pollAccuracy = 1/30

local function managerSorter( a, b )
	return not a:canBlock()
end

function M.registerTaskManager(mgr)
	mgr.tasklist = {}
	mgr.taskdata = {}
	mgr.getCurrentTask = M.getCurrentTask
	table.insert(M.managers, mgr)
	mgr:init(M)
	table.sort(M.managers, managerSorter)
end

--Returns all active tasks owned by name task manager.
function M.getTasks( name )
	return M.tasklist
end
function M.terminateTask(task, noDeregister)
	if not noDeregister then
		for i = 1, #M.tasklist do
			if M.tasklist[i] == task then
				table.remove(M.tasklist, i)
				break
			end
		end
	end
	for k, v in pairs(M.managers) do
		v:removeTask(task)
	end
end
function M.addThread(callback, ...)
	if type(callback) ~= 'function' then
		error("Synchronous Error: Expected a function, got " .. type(callback), 2)
	end
	local task = setmetatable({coroutine = coroutine.create(callback), hooks = {}, arguments = {...}}, tk)
	task.terminate = M.terminateTask
	task.nostartupwake = M.running--No future tasks should be woken by the boot scheduler
	table.insert(M.tasklist, task)
	if coroutine.running() then
		task:wake(...)
	end
	return task
end
function M.createTask(callback, ...)
	local task = setmetatable({coroutine = coroutine.create(callback), hooks = {}, arguments = {...}}, tk)
	task.terminate = M.terminateTask
	task.nostartupwake = true
	table.insert(M.tasklist, task)
	return task
end

function M.getCurrentTask()
	local running = coroutine.running()
	for i = 1, #M.tasklist do
		local task = M.tasklist[i]
		if task.coroutine == running then 
			return task
		end
	end
end
function M.step()
	for k, v in pairs(M.managers) do
		v:poll()
	end
end
function M.loop()
	M.running = true
	local looper = coroutine.create(function()
		local i = 1
		
		while i <= #M.tasklist do
			local task = M.tasklist[i]
			if not task.nostartupwake then
				local ret = task.arguments and {task:wake(unpack(task.arguments))} or {task:wake()}
				task.arguments = nil--free that data, GC!
				if ret[1] == 'error' then--Yielded!
					print("Synchronous Thread Error: " .. ret[2])
				end
				if ret[1] then
					task:terminate()
				else
					i = i + 1
				end
			else i = i + 1 end
		end
		
		while #M.tasklist > 0 or #M.timers > 0 do 
			local sleepDuration = 1/30
			local currentTime = M.getTime() 
			if #M.timers > 0 then
				local i = 1
				while i <= #M.timers do
					
					local timer = M.timers[i]
					if timer and timer[1] <= currentTime then
						timer[2]:wake()
						
						table.remove(M.timers, i)
					else
						i = i + 1
						if timer[3] then
							sleepDuration = math.max(0,math.min(sleepDuration-0.001--[[1ms accuracy guarantee attempt]], timer[1] - currentTime))
						end
					end
				end
			end 
			for i = 1, #M.managers do
				local manager = M.managers[i]
				if i == #M.managers and manager:canBlock() then
					manager:poll(sleepDuration)
					sleepDuration = nil
				else
					--print(debug.getinfo(manager.poll).source)
					manager:poll()
				end
			end
			if sleepDuration then
				M.sleepReal(sleepDuration)
			end
			
			if #M.timers == 0 then
				local active 
				for i = 1, #M.tasklist do
					if(M.tasklist[i] and M.tasklist[i]:isActive()) then
						active = true
						break
					end
				end
				if not active then break end
			end
		end
	end)--print('looper',looper)
	local s,e = coroutine.resume(looper)
	if not s then error("Internal Synchronous Error: " .. e) end
	
end
local promiseMeta = {}
function promiseMeta:after(fulfill, reject)
	if fulfill then
		M.holdPromise = true
		local promise = M.promise(fulfill)
		local promise2 = reject and M.promise(reject)
		M.holdPromise = false
		self.fulfilled = function(...)
			
			promise:run(...)
		end
		if reject then
			self.rejected = function(...)
				promise2:run(...)
			end
		end
		
		return promise2
	end
	if reject then
		M.holdPromise = true
		local promise = M.promise(reject)
		M.holdPromise = false
		self.rejected = function(...)
			promise:run(...)
		end
		return promise
	end
	
end
function promiseMeta:catch(catch)
	M.holdPromise = true
	local promise = M.promise(catch)
	M.holdPromise = false
	self.rejected = function(...)
		promise:run(...)
	end
	return promise
end

function M.promise(func, ...)
	local promise = {}
	local function resolve(...)
		if promise.fulfilled then
			promise.fulfilled(...)
		end
	end
	local function reject(...)
		if promise.rejected then
			promise.rejected(...)
		end
	end
	setmetatable(promise, {__index=promiseMeta})
	local args = {...}
	if M.holdPromise then
		function promise:run(...)
			local tb = debug.traceback()
			--print(tb)
			local args = {...}
			M.addThread(function()
				xpcall(function()
					func(unpack(args))
				end, function(r) reject(r,tb) end) end)
		end
	else
		local tb = debug.traceback()
		M.addThread(function()
			xpcall(function()
				func(resolve, reject, unpack(args))
			end, function(r) reject(r,tb) end) end)
	end
	return promise
	
end

--[[local promiseMeta = {} promiseMeta.__index = promiseMeta
function M.promise(func)
	return function(...)
		local tasq=M.createTask(func, ...)
		return setmetatable({task = tasq}, promiseMeta)
	end
end
--M.promise(function(s) sleep(s) end)(1):then(function()print'Slept!'end)()
function promiseMeta:after(cb)
	local nextPromise = setmetatable({post = cb}, promiseMeta)
	nextPromise.parent = self.parent or self
	nextPromise.task = M.createTask(function()
		if self.task then
			self.task:wake(unpack(self.arguments or {}))
		end
		nextPromise.task:wake()
	end)
	
	return nextPromise
end
function promiseMeta:__call(...)
	self.task:wake()
end]]
--After <seconds> seconds, run <callback>(...)
--If hyperaccuracy is on, Synchronous will try
--to guarantee up to 1ms accuracy.
--This might cause spikes in CPU usage, but it's necesssary
--in order to have accurate timings due to how sleeping works.
--The more hyperaccurate timers you have,
--the more CPU spikes you may get.
function M.after(seconds, hyperaccurate, callback, ...)
	table.insert(M.timers, {M.getTime() + seconds, M.createTask(callback, ...), hyperaccurate})
end
function M.afterRepeat(seconds, hyperaccurate, callback, ...)
	M.after(seconds, hyperaccurate, function(...)
		callback(...)
		M.afterRepeat(seconds, hyperaccurate, callback, ...)
	end, ...)
end


M.registerTaskManager(require(prefix .. 'snoozer'))
return M
--M.loop()
