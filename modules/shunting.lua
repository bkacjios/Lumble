local Buffer = require("buffer")

function math.factorial(n)
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
		associativity = "right",
		method = function(a) return bit.bnot(a) end,
		args = 1,
	},
	["!"] = {
		precedence = 1,
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
	-- Check 3 character operators first
	elseif operators[buf:peek(3)] then
		return buf:readLen(3)
	-- Check 2 character operators second
	elseif operators[buf:peek(2)] then
		return buf:readLen(2)
	-- Check 1 character operators last
	elseif operators[peek] or peek == '(' or peek == ')' or peek == ',' then
		return buf:readChar()
	else
		-- Fall back to a function name
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
					if #stack <= 0 then return false, "mismatched parentheses, expecting '('" end
				end
			end
			if #stack > 0 and functions[stack[#stack]] then
				local pop = table.remove(stack)
				table.insert(queue, pop)
			end
		elseif operators[token] then
			local valid = not tonumber(prev_token) and prev_token ~= ')' and prev_token ~= '!'

			if token == '~' and not tonumber(buf:peek(1)) then
				return false, "operator '~' needs a number after it"
			elseif token == '!' and valid then
				if prev_token then
					return false, ("unexpected token '%s' after '%s', expected number"):format(token, prev_token)
				else
					return false, ("unexpected token '%s', expected number"):format(token)
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

local function next_op(tbl, pos)
	for i=pos+1, #tbl do
		if operators[tbl[i]] then
			return tbl[i]
		end
	end
end

local function shouldParen(op, next_op)
	if next_op == '-' then
		return true
	elseif next_op == '*' or next_op == '/' then
		if op == '+' or op == '-' then
			return true
		end
	end
	return false
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

local function newFunctionNode(func, arg1, arg2)
	return {
		kind = "function",
		func = func,
		arg1 = arg1,
		arg2 = arg2,
	}
end

local function needParensOnLeft(node)
	if node.left.kind ~= "operator" and node.left.kind ~= "unary" then
		return false
	end
	if node.operator == "*" or node.operator == "/" or node.operator == "^" then
		return node.operator ~= node.left.operator
	end
	return node.left.precedence < node.precedence
end
    
local function needParensOnRight(node)
	if node.right.kind == "number" or node.right.kind == "unary" then
		return false
	end
	if node.operator == "+" or node.operator == "*" then
		return node.right.precedence < node.precedence
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
		elseif functions[token] then
			if functions[token].args <= 1 then
				local pop1 = table.remove(stack)
				table.insert(stack, newFunctionNode(token, pop1))
			else
				local pop1 = table.remove(stack)
				local pop2 = table.remove(stack)
				table.insert(stack, newFunctionNode(token, pop2, pop1))
			end
		end
	end

	return table.remove(stack)
end

function math.infix_to_string(node)
	if not node then return "" end
	if node.kind == "number" then
		return node.value
	elseif node.kind == "function" then
		if node.arg1 and node.arg2 then
			return node.func .. '(' .. math.infix_to_string(node.arg1) .. ', ' .. math.infix_to_string(node.arg2) .. ')'
		else
			return node.func .. '(' .. math.infix_to_string(node.arg1) .. ')'
		end
	elseif node.kind == "unary" then
		if node.associativity == "left" then
			return '(' .. math.infix_to_string(node.node) .. node.operator .. ')'
		else
			return '(' .. node.operator .. math.infix_to_string(node.node) .. ')'
		end
	end
	local lhs = math.infix_to_string(node.left)
	--print("lhs", lhs)
	if needParensOnLeft(node) then
		lhs = '(' .. lhs .. ')'
	end
	local rhs = math.infix_to_string(node.right)
	--print("rhs", rhs)
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
		elseif functions[token] then
			local args = {}
			for i=1,functions[token].args do
				table.insert(args, 1, table.remove(stack))
			end
			local func = functions[token].method
			table.insert(stack, func(unpack(args)))
		else
			table.insert(stack, token)
		end
	end

	return table.remove(stack)
end

--local expression = "random(1,5)"
--local expression = "-min(0xf.0e0p1,0x12p2)+(2e-3+-5*(59*1+4)/2)"
local expression = "(2e-3+-5*(59*1+4)/2)"
--local expression = "3e1 + 1"
--local expression = "-sqrt(1 << 4)!"
--local expression = "120 % 60"
--local expression = "1 + 3 / 2 ^ 4"
--local expression = "23--4+4^3/2*2"
--local expression = "min(3,2)/2+4"
--local expression = "-1 + 2"
local expression = "1+3-5*2/2"
local expression = "2^3-1 * 2^2 + 4 - 5%2/2"
local expression = "4+(-4)!+ 1*1/3"

local stack, err = math.postfix(expression)

if not stack then
	print(err)
	return
end

table.foreach(stack, print)

local total = math.solve_postfix(stack)

print(expression .. " = " .. total)

local node = math.postfix_to_infix(stack)

print(math.infix_to_string(node))