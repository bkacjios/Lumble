local Buffer = require("buffer")

function math.factorial(n)
	if n == 0 then
		return 1
	end
	for i=1, n-1 do
		n = n * i
	end
	return n
end

local operators = {
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
	["up"] = {
		precedence = 2,
		associativity = "right",
		method = function(a) return a end,
		args = 1,
	},
	["-"] = {
		precedence = 4,
		associativity = "left",
		method = function(a, b) return a - b end,
		args = 2,
	},
	["um"] = {
		precedence = 2,
		associativity = "right",
		method = function(a) return -a end,
		args = 1,
	},
	["x"] = {
		precedence = 3,
		associativity = "left",
		method = function(a, b) return a * b end,
		args = 2,
	},
	["*"] = {
		precedence = 3,
		associativity = "left",
		method = function(a, b) return a * b end,
		args = 2,
	},
	["÷"] = {
		precedence = 3,
		associativity = "left",
		method = function(a, b) return a / b end,
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
		associativity = "right",
		method = function(a) return bit.bnot(a) end,
		args = 1,
	},
	["!"] = {
		precedence = 2,
		associativity = "left",
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

local translate_tokens = {
	["um"] = '-',
	["up"] = '+',
}

local functions = {
	["abs"] = {method = math.abs},
	["acos"] = {method = math.acos},
	["asin"] = {method = math.asin},
	["atan"] = {method = math.atan},
	["atan2"] = {multi = true, method = math.atan2},
	["ceil"] = {multi = true, method = math.ceil},
	["cos"] = {method = math.cos},
	["cosh"] = {method = math.cosh},
	["deg"] = {method = math.deg},
	["exp"] = {method = math.exp},
	["floor"] = {multi = true, method = math.floor},
	["fmod"] = {multi = true, method = math.fmod},
	--["frexp"] = {multi = true, method = math.frexp},
	["ldexp"] = {multi = true, method = math.ldexp},
	["ln"] = {method = math.log},
	["log"] = {method = math.log10},
	["max"] = {multi = true, method = math.max},
	["min"] = {multi = true, method = math.min},
	--["modf"] = {multi = true, method = math.modf},
	["pow"] = {multi = true, method = math.pow},
	["rad"] = {method = math.rad},
	["rand"] = {args = 0, method = math.random},
	["random"] = {multi = true, method = math.random},
	["sin"] = {method = math.sin},
	["sinh"] = {method = math.sinh},
	["sqrt"] = {method = math.sqrt},
	["tan"] = {method = math.tan},
	["tanh"] = {method = math.tanh},
}

local constants = {
	["pi"] = math.pi,
	["π"] = math.pi,
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

local function peekToken(buf, size)
	-- Skip over any whitespace..
	buf:readPattern("^%s+")
	-- Peek at the next token available
	return buf:peek(size)
end

local function readToken(buf)
	local peek1, peek2, peek3 = peekToken(buf, 1), peekToken(buf, 2), peekToken(buf, 3)
	local peekfunc, peekfunclen = buf:peekPattern("^%a+")

	-- Check if token is a number
	if tonumber(peek1) then
		return readNumber(buf)
	-- Check 3 character operators first
	elseif operators[peek3] or constants[peek3] then
		return buf:readLen(3)
	-- Check 2 character operators second
	elseif operators[peek2] or constants[peek2] then
		return buf:readLen(2)
	-- Check 1 character operators last
	elseif operators[peek1] or constants[peek1] or peek1 == '(' or peek1 == ')' or peek1 == ',' then
		return buf:readChar()
	-- Fall back to a function name
	elseif functions[peekfunc] then
		return buf:readLen(peekfunclen)
	end

	-- Read everything? Should cause an invalid token error
	return buf:readAll()
end
 
function math.postfix(str)
	local queue = {}
	local stack = {}

	local prev_token = nil
	local prev_important_token = nil
	local args = {}

	local buf = Buffer(str)

	while buf:next() do
		local token = readToken(buf)

		if not token then break end

		if tonumber(token) then
			if tonumber(prev_important_token) or constants[prev_important_token] then
				return false, "number given without an operator"
			end
			table.insert(queue, tonumber(token))
		elseif constants[token] then
			if tonumber(prev_important_token) or constants[prev_important_token] then
				return false, "constant given without an operator"
			end
			table.insert(queue, constants[token])
		elseif functions[token] then
			-- Make functions with only 1 argument have optional parentheses
			local peek = peekToken(buf, 1) --buf:peek(1)

			if peek ~= "(" then
				if functions[token].multi then
					return false, ("'(' expected after function '%s'"):format(token)
				--elseif not tonumber(peek) then
				elseif not peek or peek == "" then
					return false, ("function '%s' has no arguments"):format(token)
				end
			end
			table.insert(stack, token)
			args[#stack] = 1
		elseif token == ',' then
			while true do
				local pop = table.remove(stack)
				if pop == "(" then
					table.insert(stack, "(")
					break
				else
					table.insert(queue, pop)
					if #stack == 0 then return false, "expected '(' before ','" end
				end
			end
			-- Only allow commas on the same scope as a function
			if not functions[stack[#stack-1]] then
				return false, ("misuse of ',' outside of funciton scope near '%s'"):format(prev_token)
			elseif not functions[stack[#stack-1]].multi then
				return false, ("unexpected ',' in function '%s'"):format(stack[#stack-1])
			end
			args[#stack-1] = args[#stack-1] + 1
		elseif token == "(" then
			table.insert(stack, token)
		elseif token == ")" then
			while true do
				local pop = table.remove(stack)
				if pop == "(" then
					break
				else
					table.insert(queue, pop)
					if #stack <= 0 then return false, "mismatched parentheses, expecting '('" end
				end
			end
			if #stack > 0 and functions[stack[#stack]] then
				local n = args[#stack]
				local pop = table.remove(stack)
				if n <= 0 or prev_token == '(' then
					return false, ("function '%s' has no arguments"):format(pop)
				end
				table.insert(queue, pop .. ":" .. n)
			end
		elseif operators[token] then
			local valid = not tonumber(prev_token) and not constants[prev_token] and prev_token ~= ')' and prev_token ~= '!'

			if token == '~' and not tonumber(peekToken(buf, 1)) and not constants[buf:peekPattern("^%a+")] then
				return false, "operator '~' needs a number or constnat after it"
			elseif token == '!' and valid then
				if prev_token then
					return false, ("unexpected token '%s' after '%s', expected number or constant"):format(token, prev_token)
				else
					return false, ("unexpected token '%s', expected number or constant"):format(token)
				end
			elseif not prev_token or valid then
				if token == '+' then
					token = "up"
				elseif token == '-' then
					token = "um"
				elseif token ~= '~' then
					return false, ("invalid use of operator '%s' near '%s'"):format(token, prev_token)
				end
			end

			local tprec = operators[token].precedence
			local rassoc = operators[token].associativity

			while #stack > 0 and operators[stack[#stack]] do
				local pop = stack[#stack]
				local pprec = operators[pop].precedence
				if tprec > pprec or (tprec == pprec and rassoc ~= "right") then
					table.insert(queue, table.remove(stack))
				else
					break
				end
			end
			table.insert(stack, token)
		else
			return false, ("unexpected token '%s'"):format(token)
		end
		if token ~= '(' and token ~= ')' then
			prev_important_token = token
		end
		prev_token = token
	end
	while #stack > 0 do
		local pop = table.remove(stack)
		if pop == '(' then
			return false, "mismatched parentheses, expecting ')'"
		elseif pop == ')' then
			return false, "mismatched parentheses, expecting '('"
		else
			table.insert(queue, pop)
		end
	end
	return queue
end

do

local function newNumberNode(value)
	return {
		kind = "number",
		value = value,
	}
end

local function newOPNode(token, left, right)
	local info = operators[token]

	return {
		kind = "operator",
		operator = translate_tokens[token] or token,
		precedence = info.precedence,
		left = left,
		right = right,
	}
end

local function newUnaryNode(token, node)
	local info = operators[token]
	return {
		kind = "unary",
		operator = translate_tokens[token] or token,
		precedence = info.precedence,
		associativity = info.associativity,
		node = node,
	}
end

local function newFunctionNode(func, args)
	return {
		kind = "function",
		precedence = 1,
		func = func,
		args = args,
	}
end

local function needParensOnLeft(node)
	if node.left.kind == "number" or node.left.kind == "unary" or node.left.kind == "function" then
		return false
	end
	if node.operator == "*" or node.operator == "/" or node.operator == "^" then
		return node.left.precedence <= node.precedence
	end
	return node.left.precedence < node.precedence
end

local function needParensOnRight(node)
	if node.right.kind == "number" or node.right.kind == "unary" or node.right.kind == "function" then
		return false
	end
	if node.operator == "+" or node.operator == "*" then
		return node.right.precedence ~= node.precedence
	end
	return node.right.precedence <= node.precedence
end

function math.postfix_to_infix(tbl)
	local stack = {}
	local first = false
	for k, token in ipairs(tbl) do
		if tonumber(token) then
			table.insert(stack, newNumberNode(token))
		elseif operators[token] then
			if operators[token].args <= 1 then
				local pop1 = table.remove(stack)
				table.insert(stack, newUnaryNode(token, pop1))
			else
				local pop1 = table.remove(stack)
				local pop2 = table.remove(stack)
				table.insert(stack, newOPNode(token, pop2, pop1))
			end
		elseif string.find(token, ":") then
			local spos, epos = string.find(token, ":")
			local args = {}

			for i=1,token:sub(epos+1) do
				table.insert(args, 1, table.remove(stack))
			end

			table.insert(stack, newFunctionNode(token:sub(1, spos-1), args))
		elseif functions[token] then
			table.insert(stack, newFunctionNode(token, {table.remove(stack)}))
		end
	end

	return table.remove(stack)
end

function math.infix_to_string(node, infunc)
	if not node then return "" end
	if node.kind == "number" then
		return node.value
	elseif node.kind == "function" then
		local str = node.func .. '('
		for k,arg in pairs(node.args) do
			str = str .. math.infix_to_string(arg, true)
			if k < #node.args then
				str = str .. ', '
			end
		end
		return str .. ')'
	elseif node.kind == "unary" then
		local val
		if node.associativity == "left" then
			if node.operator == "!" then
				if node.node.kind == "number" then
					val = math.infix_to_string(node.node) .. node.operator
				else
					val = '(' .. math.infix_to_string(node.node) .. ')' .. node.operator
				end
			else
				val = math.infix_to_string(node.node) .. node.operator
			end
		else
			val = node.operator .. math.infix_to_string(node.node)
		end
		if infunc then
			return val
		end
		return '(' .. val .. ')'
	end
	local lhs = math.infix_to_string(node.left)
	if needParensOnLeft(node) then
		lhs = '(' .. lhs .. ')'
	end
	local rhs = math.infix_to_string(node.right)
	if needParensOnRight(node) then
		rhs = '(' .. rhs .. ')'
	end
	return lhs .. ' ' .. node.operator .. ' ' .. rhs
end

end

function math.solve_postfix(tbl)
	local stack = {}
	for k, token in ipairs(tbl) do
		if operators[token] then
			local args = {}
			for i=1,operators[token].args do
				table.insert(args, 1, table.remove(stack))
			end
			local func = operators[token].method
			table.insert(stack, func(unpack(args)))
		elseif string.find(token, ":") then
			local spos, epos = string.find(token, ":")
			local args = {}

			for i=1,token:sub(epos+1) do
				table.insert(args, 1, table.remove(stack))
			end

			local func = functions[token:sub(1, spos-1)].method
			table.insert(stack, func(unpack(args)))
		elseif functions[token] then
			local func = functions[token].method
			table.insert(stack, func(table.remove(stack)))
		else
			table.insert(stack, token)
		end
	end

	return table.remove(stack)
end

--[[local expression = "random(1,5)"
local expression = "-min(0xf.0e0p1,0x12p2)+(2e-3+-5*(59*1+4)/2)"
local expression = "3e1 + 1"
local expression = "-sqrt(1 << 4)!"
local expression = "120 % 60"
local expression = "1 + 3 / 2 ^ 4"
local expression = "23--4+4^3/2*2"
local expression = "min(3,2)/2+4"
local expression = "-1 + 2"
local expression = "4+(-4)!+ 1*1/3"
local expression = "18(+4)"
local expression = "sqrt(-1+4-2)"
local expression = "2^3-1 * 2^2 + 4 - 5%2/2"
local expression = "sqrt(-1 +4*2/1)"
local expression = "2e-3+-5*(59*1+4)/2"
local expression = "2-(3+-5)*59*1+4/2"
local expression = "min(-3, max(-2,-1,0,1,2)) + sin 1"
local expression = "1 + 1 - 1 - 1 * 2 - 3 ^ 4 / 5 / 2 * 2 + 6 - 7"
local expression = "(6-1)! + 0! + -1/5^2"
local expression = "6-1x0+2÷2+π"

local stack, err = math.postfix(expression)

if not stack then
	print(err)
	return
end

table.foreach(stack, print)

local total = math.solve_postfix(stack)

print(expression .. " = " .. total)

local node = math.postfix_to_infix(stack)

print(math.infix_to_string(node))]]
