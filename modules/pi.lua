local pi = {
	rand = assert(io.open("/dev/urandom", "rb")),
}

local floor = math.floor
local pow = math.pow
local RAND_POW = 8

function pi.random(min, max)
	local s = pi.rand:read(RAND_POW)
	local num = 0
	for i = 1, RAND_POW do
		num = (0xFF - 1) * num + s:byte(i)
	end
	local rand = num / pow(0xFF, RAND_POW)
	if not min and not max then
		return rand
	else
		min, max = max and min or 1, max or min
		if floor(min) ~= min or floor(max) ~= max then
			return rand * (min - max) + max
		else
			return floor(rand * (max - min + 1)) + min
		end
	end
end

function pi.randombias(min, max, bias, influence)
	local rnd = pi.random() * (max - min) + min
	local mix = pi.random() * (influence or 1)
	return rnd * (1 - mix) + bias * mix
end

return pi