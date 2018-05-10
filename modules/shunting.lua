local Buffer = require("buffer")

function math.factorial(n)
	for i=1, n-1 do
		n = n * i
	end
	return n
end

local operator = {
	[">"] = {
		precedence = 6,
		associativity = "left",
		method = function(a, b) return a > b and 1 or 0 end,
		args = 2,
	},
	["<"] = {
		precedence = 6, 
		associativity = "left",
		method = function(a, b) return a < b and 1 or 0 end,
		args = 2,
	},
	[">="] = {
		precedence = 6,
		associativity = "left",
		method = function(a, b) return a >= b and 1 or 0 end,
		args = 2,
	},
	["<="] = {
		precedence = 6,
		associativity = "left",
		method = function(a, b) return a <= b and 1 or 0 end,
		args = 2,
	},
	["=="] = {
		precedence = 7,
		associativity = "left",
		method = function(a, b) return a == b and 1 or 0 end,
		args = 2,
	},
	["!="] = {
		precedence = 7,
		associativity = "left",
		method = function(a, b) return a ~= b and 1 or 0 end,
		args = 2,
	},
	["<>"] = {
		precedence = 7,
		associativity = "left",
		method = function(a, b) return a ~= b and 1 or 0 end,
		args = 2,
	},
	["&"] = {
		precedence = 8,
		associativity = "left",
		method = function(a, b) return bit.band(a,b) end,
		args = 2,
	},
	--[[["^"] = {
		precedence = 9,
		associativity = "left",
		method = function(a, b) return bit.bxor(a,b) end,
		args = 2,
	},]]
	["|"] = {
		precedence = 10,
		associativity = "left",
		method = function(a, b) return bit.bor(a,b) end,
		args = 2,
	},
	["<<"] = {
		precedence = 5,
		associativity = "left",
		method = function(a, b) return bit.lshift(a,b) end,
		args = 2,
	},
	[">>"] = {
		precedence = 5,
		associativity = "left",
		method = function(a, b) return bit.rshift(a,b) end,
		args = 2,
	},
	[">>>"] = {
		precedence = 5,
		associativity = "left",
		method = function(a, b) return bit.arshift(a,b) end,
		args = 2,
	},
	["+"] = {
		precedence = 4,
		associativity = "left",
		method = function(a, b) return a + b end,
		args = 2,
	},
	["-"] = {
		precedence = 4,
		associativity = "left",
		method = function(a, b) return a - b end,
		args = 2,
	},
	["*"] = {
		precedence = 3,
		associativity = "left",
		method = function(a, b) return a * b end,
		args = 2,
	},
	["/"] = {
		precedence = 3,
		associativity = "left",
		method = function(a, b) return a / b end,
		args = 2,
	},
	["%"] = {
		precedence = 3,
		associativity = "left",
		method = function(a, b) return a % b end,
		args = 2,
	},
	["~"] = {
		precedence = 2,
		associativity = "left",
		method = function(a) return bit.bnot(a) end,
		args = 1,
	},
	["!"] = {
		precedence = 1,
		associativity = "right",
		method = function(a) return math.factorial(a) end,
		args = 1,
	},
	["^"] = {
		precedence = 0,
		associativity = "right",
		method = function(a, b) return a ^ b end,
		args = 2,
	},
}

local functions = {
	["abs"] = {args = 1, method = math.abs},
	["acos"] = {args = 1, method = math.acos},
	["asin"] = {args = 1, method = math.asin},
	["atan"] = {args = 1, method = math.atan},
	["atan2"] = {args = 2, method = math.atan2},
	["ceil"] = {args = 2, method = math.ceil},
	["cos"] = {args = 1, method = math.cos},
	["cosh"] = {args = 1, method = math.cosh},
	["deg"] = {args = 1, method = math.deg},
	["exp"] = {args = 1, method = math.exp},
	["floor"] = {args = 2, method = math.floor},
	["fmod"] = {args = 2, method = math.fmod},
	--["frexp"] = {args = 2, method = math.frexp},
	["ldexp"] = {args = 2, method = math.ldexp},
	["ln"] = {args = 1, method = math.log},
	["log"] = {args = 1, method = math.log10},
	["max"] = {args = 2, method = math.max},
	["min"] = {args = 2, method = math.min},
	--["modf"] = {args = 2, method = math.modf},
	["pow"] = {args = 2, method = math.pow},
	["rad"] = {args = 1, method = math.rad},
	["rand"] = {args = 0, method = math.random},
	["random"] = {args = 2, method = math.random},
	["sin"] = {args = 1, method = math.sin},
	["sinh"] = {args = 1, method = math.sinh},
	["sqrt"] = {args = 1, method = math.sqrt},
	["tan"] = {args = 1, method = math.tan},
	["tanh"] = {args = 1, method = math.tanh},
}

local constants = {
	["pi"] = math.pi,
	["inf"] = math.huge,
	["e"] = math.exp(1),
}

local function readNumber(buf)
	local num = ''

	local dobreak = false
	while buf:next() do
		for i=4,1,-1 do
			local peek = buf:peek(i)
			if tonumber(num .. peek) then
				num = num .. buf:readLen(i)
			else
				dobreak = true
			end
		end
		if dobreak then break end
	end

	return tonumber(num)
end

local function readToken(buf)
	local peek = buf:peek(1)
	-- Check if the token is a number
	if tonumber(peek) then
		return readNumber(buf)
	-- Check 2 character operators first
	elseif operator[buf:peek(2)] then
		return buf:readLen(2)
	-- Then check single character operators
	elseif operator[peek] or peek == '(' or peek == ')' or peek == ',' or peek == ' ' then
		return buf:readChar()
	else
		-- Fall back to a function call
		return buf:readPattern("%a+")
	end
end
 
function math.postfix(str)
	local queue = {}
	local stack = {}

	local prev_token = nil

	local buf = Buffer(str:gsub("%s", ''))

	while buf:next() do
		local token = readToken(buf)

		if not token then break end

		if tonumber(token) then
			table.insert(queue, tonumber(token))
		elseif constants[token] then
			table.insert(queue, constants[token])
		elseif functions[token] then
			-- Make functions with only 1 argument have optional parentheses
			if functions[token].args > 1 and buf:peek(1) ~= "(" then
				return false, ("'(' expected after '%s'"):format(token)
			else
				table.insert(stack, token)
			end
		elseif token == ',' then
			while true do
				local pop = table.remove(stack)
				if pop == "(" then
					table.insert(stack, "(")
					break
				else
					table.insert(queue, pop)
					if #stack == 0 then
						return false, "expected '('' before ','"
					end
				end
			end
		elseif token == "(" then
			table.insert(stack, token)
		elseif token == ")" then
			while true do
				local pop = table.remove(stack)
				if pop == "(" then
					break
				else
					table.insert(queue, pop)
					if #stack <= 0 then return false, ("mismatched parentheses, expecting '(' got '%s'"):format(pop) end
				end
			end
			if #stack > 0 and functions[stack[#stack]] then
				local pop = table.remove(stack)
				table.insert(queue, pop)
			end
		elseif operator[token] then
			if token == '~' and not tonumber(buf:peek(1)) then
				return false, "operator '~' needs a number after it"
			elseif token == '!' then
				if prev_token ~= ')' and prev_token ~= '!' and not tonumber(prev_token) then
					if prev_token then
						return false, ("unexpected token '%s' after '%s', expected number"):format(token, prev_token)
					else
						return false, ("unexpected token '%s', expected number"):format(token)
					end
				end
			end

			while #stack > 0 and operator[stack[#stack]] do
				local op = stack[#stack]
				if (operator[op].associativity ~= "right" and operator[token].precedence == operator[op].precedence) or operator[token].precedence > operator[op].precedence then
					table.insert(queue, table.remove(stack))
				else
					break
				end
			end
			table.insert(stack, token)
		else
			return false, ("unexpected token '%s'"):format(token)
		end
		prev_token = token
		::continue::
	end
	while #stack > 0 do
		local pop = table.remove(stack)
		if pop == "(" then
			return false, "mismatched parentheses, expecting ')' asd"
		elseif pop == ")" then
			return false, "mismatched parentheses, expecting '(' asd"
		else
			table.insert(queue, pop)
		end
	end
	return queue
end

function math.solve_postfix(tbl)
	local stack = {}
	for k, token in ipairs(tbl) do
		if operator[token] then
			local args = {}
			for i=1,operator[token].args do
				local t = table.remove(stack) or 0
				table.insert(args, 1, t)
			end
			local func = operator[token].method
			table.insert(stack, func(unpack(args)))
		elseif functions[token] then
			local args = {}
			for i=1,functions[token].args do
				table.insert(args, table.remove(stack))
			end
			local func = functions[token].method
			table.insert(stack, func(unpack(args)))
		else
			table.insert(stack, token)
		end
	end

	return table.remove(stack)
end

--local expression = "4! + 1"
local expression = "-min(0xf.0e0p1,0x12p2)+(2e-3+-5*(59*1+4)/2)"
--local expression = "3e1 + 1"
local expression = "1 << 2! + 4"

local stack, err = math.postfix(expression)

if not stack then
	print(err)
	return
end

table.foreach(stack, print)

local total = math.solve_postfix(stack)

print(expression .. " = " .. total)