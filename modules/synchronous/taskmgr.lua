--A task manager is something that handles all sub-tasks of a certain type.
--An example would be a LuaSocket task manager. It would manage all
--sockets wrapped by the Task Manager, and the Task Manager
--would be ... tasked ... to waking up the respective Tasks.
--Using this interface, Synchronous is able to implement higher level
--APIs such as Promises.

--Task managers that Synchronous implements include (this may or may not be an exhaustive list, check the controllers folder.)
--Snoozer - Implements a sleep() function
--SmartTimer - Implements an accurate timer that can either call a function after a delay, or repeatedly call it every so often.
--LuaSocket - Implements an synchronous asynchronous LuaSocket handler.
----Don't use Synchronous if you're using OpenResty; OR already takes care of everything!
local M = {} M.__index = M
--Returns a list of sleeping tasks
function M:getTaskList()
	return self.tasks
end
--If your task is able to block for a set period of time in seconds,
--return true here.
--You need to be able to block with up to millisecond precision.
function M:canBlock()
	return false
end
--If blocking is a number,
--you must block for that many seconds.
--Do the logic you need here for determining if your tasks need waking.
function M:poll(blocking)
	
end
--This will iterate all the tasks in a safe manner;
--it is preferred you use this instead of doing it yourself,
--as this handles tasks being removed.
M.iterator = 0
function M:iterate(callback, ...)
	self.iterator = 1
	while self.iterator <= #self.tasklist do
		local task = self.tasklist[self.iterator]
		--print(task)
		if task then
			local prev = #self.tasklist
			callback(self, task, self.taskdata[task], ...)
			--[[if #self.tasklist > prev then
				error("You cannot add items while iterating!" .. #self.tasklist .. ';' .. prev)
			end]]
		end--Unlikely that there will be a gap, but a safety is nice.
		self.iterator = self.iterator + 1
	end
	--search for duplicates post iterate
	local dupes = {}
	for i = 1, #self.tasklist do
		if dupes[self.tasklist[i]] then error('Duplicate task in tasklist post-iterate! Oh no! At ' .. i .. ' and ' .. dupes[self.tasklist[i]]) end
		dupes[self.tasklist[i]] = i
	end
end

function M:removeTask(task, ...)
	local done
	for i = 1, #self.tasklist do
		if self.tasklist[i] == task then
			table.remove(self.tasklist, i)
			self:onTaskRemoved(task, self.taskdata[task], ...)
			if self.iterator >= i then
				self.iterator = self.iterator - 1
			end
			
			if done then
				print('Duplicate task in tasklist: ' .. debug.traceback(), i, done)
			end
			done=i
			--break
		end
	end
	
	self.taskdata[ task ] = nil
end
function M:wakeTask(task, ...)
	task:terminate(true)--secret! it doesn't actually terminate it! just keeps it from waking up, but we're waking it here!
	return task:wake(...)
end
--Adds a task to the list, yielding it.
function M:addTask(data)
	local task = self:getCurrentTask()
	table.insert( self.tasklist, task )
	self.taskdata[ task ] = data
	self:onTaskAdded(task, data)
	
	return coroutine.yield(data)
end
--Called when a task has been added.
function M:onTaskAdded(task, data)
end
--Called when a task has been removed.
function M:onTaskRemoved(task, data)
end

--Called right before your task is registered.
--synch is a reference to the Synchronous module.
function M:init(synch)

end
return M