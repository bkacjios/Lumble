local operator = {
	["+"] = {
		precedence = 0,
		associativity = "left",
		method = function(a, b) return a + b end,
	},
	["-"] = {
		precedence = 0,
		associativity = "left",
		method = function(a, b) return a - b end,
	},
	["*"] = {
		precedence = 5,
		associativity = "left",
		method = function(a, b) return a * b end,
	},
	["/"] = {
		precedence = 5,
		associativity = "left",
		method = function(a, b) return a / b end,
	},
	["%"] = {
		precedence = 5,
		associativity = "left",
		method = function(a, b) return a % b end,
	},
	["^"] = {
		precedence = 10,
		associativity = "right",
		method = function(a, b) return a ^ b end,
	},
}

local functions = {
	--["cos"] = math.cos,
	--["exp"] = math.exp,
	["max"] = math.max,
	["min"] = math.min,
	--["sqrt"] = math.sqrt,
}

function string.split(str, separator, withpattern)
	if withpattern == nil then withpattern = false end

	local ret = {}
	local current_pos = 1

	for i = 1, #str do
		local start_pos, end_pos = string.find(str, separator, current_pos, not withpattern)
		if not start_pos then break end
		ret[i] = string.sub(str, current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end

	ret[#ret + 1] = string.sub(str, current_pos)
	return ret
end

function string.nice_equation(expr)
	local oper = {"%+", "%-", "%*", "%/", "%^", "%%", "%(", "%)", "%w+", "%d+"}
	for _, o in ipairs(oper) do
		expr = expr:gsub(o, " %1 ")
	end
	return expr:gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", "")
end

function math.shunting(str)
	local queue = {}
	local stack = {}

	local tokens = string.nice_equation(str):split(" ")

	local rep_num = 0
	for pos, token in ipairs(tokens) do
		if tonumber(token) then
			rep_num = rep_num + 1
			if rep_num > 1 then
				return false, "two numbers given with no operator"
			end
			table.insert(queue, tonumber(token))
		elseif functions[token] then
			rep_num = 0
			if tokens[pos + 1] ~= "(" then
				return false, ("'(' expected near '%s'"):format(token)
			else
				table.insert(stack, token)
			end
		elseif token == ',' then
			rep_num = 0
			while true do
				local op = table.remove(stack)
				if op == "(" then
					table.insert(stack, "(")
					break
				else
					table.insert(queue, op)
					if #stack == 0 then
						return false, "expected '('' before ','"
					end
				end
			end
		elseif token == "(" then
			rep_num = 0
			table.insert(stack, token)
		elseif token == ")" then
			rep_num = 0
			while true do
				local op = table.remove(stack)
				if op == "(" then
					break
				else
					table.insert(queue, op)
					if #stack <= 0 then return false, "mismatched parentheses, expecting '('" end
				end
			end
			if #stack > 0 and functions[stack[#stack]] then
				table.insert(queue, table.remove(stack))
			end
		elseif operator[token] then
			rep_num = 0
			while #stack > 0 and operator[stack[#stack]] do
				local op = stack[#stack]
				if (operator[op].associativity ~= "right" and operator[token].precedence == operator[op].precedence) or operator[token].precedence < operator[op].precedence then
					table.insert(queue, table.remove(stack))
				else
					break
				end
			end
			table.insert(stack, token)
		else
			return false, ("unexpected token '%s'"):format(token)
		end
	end
	while #stack > 0 do
		local op = table.remove(stack)
		if op == "(" then
			return false, "mismatched parentheses, expecting ')'"
		elseif op == ")" then
			return false, "mismatched parentheses, expecting '('"
		else
			table.insert(queue, op)
		end
	end
	return queue
end

function math.solve_shunting(tbl)
	local stack = {}
	for k, token in ipairs(tbl) do
		if operator[token] then
			local right = table.remove(stack)
			local left = table.remove(stack)
			local func = operator[token].method
			table.insert(stack, func(left, right))
		elseif functions[token] then
			local right = table.remove(stack)
			local left = table.remove(stack)
			local func = functions[token]
			table.insert(stack, func(left, right))
		else
			table.insert(stack, token)
		end
	end

	return table.remove(stack)
end

local expression = "7 % 6"

local thing = math.shunting(expression)
local total = math.solve_shunting(thing)

print(expression, total)