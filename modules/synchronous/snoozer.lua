local prefix = SYNCHRONOUS_PREFIX or "synchronous."
local impl = setmetatable({}, require(prefix..'taskmgr'))
local gettime
function impl:canBlock()
	return false
end
function impl:process(theTask, data)
	if gettime() > data then
		self:wakeTask(theTask)
	end
end
function impl:poll(block)
	self:iterate(self.process)
end
local getCurrentTask
local function sleep(s)
	impl:addTask(gettime() + s)
end
function impl:init(synch, inst)
	getCurrentTask = synch.getCurrentTask
	gettime = synch.getTime
	synch.sleep = sleep
end
return impl