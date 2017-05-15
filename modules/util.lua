local util = {}

function util.argerr(arg, num, expected)
	local typeName = type(arg)
	if typeName ~= expected then
		local funcName = debug.getinfo(2, "n").name
		return error(("bad argument #%d to '%s' %s expected, got %s "):format(num, funcName, expected, typeName), 2)
	end
end

function util.checkmeta(arg, expectedMeta, num, expected)
	local typeName = type(arg)
	local meta = getmetatable(arg)
	if typeName ~= "table" or meta ~= expectedMeta then
		local funcName = debug.getinfo(2, "n").name
		return error(("bad argument #%d to '%s' %s expected, got %s "):format(num, funcName, expected, typeName), 2)
	end
end

return util