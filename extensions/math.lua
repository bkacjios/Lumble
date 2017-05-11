math.randomseed(os.time())

function math.roll(dice, num)
	local results = {}
	local total = 0

	for i=1, num or 1 do
		results[i] = math.random(1, dice)
		total = total + results[i]
	end

	return results, total
end

function math.difftime(t1,t2)
	local d1 = os.date('*t',t1)
	local d2 = os.date('*t',t2)
	local carry = false
	local diff = {}
	local colMax = {60, 60, 24, os.date('*t', os.time{year = d1.year, month = d1.month + 1, day = 0}).day, 12}
	d2.hour = d2.hour - (d2.isdst and 1 or 0) + (d1.isdst and 1 or 0) -- handle dst
	for i,v in ipairs({'sec','min','hour','day','month','year'}) do
		diff[v] = d2[v] - d1[v] + (carry and -1 or 0)
		carry = diff[v] < 0
		if carry and colMax[i] then diff[v] = diff[v] + colMax[i] end
	end
	return diff
end

function math.SecondsToHuman(sec, accuracy)
	local accuracy = accuracy or 2
	local now = os.time()
	local diff = math.difftime(now - sec, now)
	local results = {}
	
	if diff.year >= 1 then
		table.insert(results, diff.year .. string.Plural(" year", diff.year))
	end
	if diff.month >= 1 then
		table.insert(results, diff.month .. string.Plural(" month", diff.month))
	end
	if diff.day >= 1 then
		table.insert(results, diff.day .. string.Plural(" day", diff.day))
	end
	if diff.hour >= 1 then
		table.insert(results, diff.hour .. string.Plural(" hour", diff.hour))
	end
	if diff.min >= 1 then
		table.insert(results, diff.min .. string.Plural(" minute", diff.min))
	end
	if diff.sec >= 1 then
		table.insert(results, diff.sec.. string.Plural(" second", diff.sec))
	end
	
	local result = {}
	for i=1,accuracy do
		result[i] = results[i]
	end
	
	return table.concat(result, ", ")
end

function math.randombias(min, max, bias, influence)
	local rnd = math.random() * (max - min) + min
	local mix = math.random() * (influence or 1)
	return rnd * (1 - mix) + bias * mix
end

function math.round(num, places)
	local mult = math.pow(10, (places or 0))
	return math.floor(num * mult + 0.5) / mult
end

local STNDRD_TBL = {"st", "nd", "rd"}
function math.stndrd(num)
	num = num % 100
	if num > 10 and num < 20 then
		return "th"
	end
	return num .. STNDRD_TBL[num % 10] or "th"
end