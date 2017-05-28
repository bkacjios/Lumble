--A promise demo
SYNCHRONOUS_PREFIX = ''
local synch = require'init'
synch.promise(function(resolve, reject)
	print("Sleeping...")
	synch.sleep(1)
	print("Slept!")
	resolve()
end):after(function(...)
	print("Promise ran!")
end)

synch.loop()