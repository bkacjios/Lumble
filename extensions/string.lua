local char = string.char
local gsub = string.gsub

function string.gisub(s, pat, repl, n)
	pat = string.gsub(pat, '(%a)', function (v)
		return '['..string.upper(v)..string.lower(v)..']'
	end)

	if n then
		pat = string.gsub(s, pat, repl, n)
	else
		pat = string.gsub(s, pat, repl)
	end

	return pat
end

function string.trim(self, char)
	char = char or "%s"
	return (self:gsub("^"..char.."*(.-)"..char.."*$", "%1" ))
end

function string.AddCommas(str)
	return tostring(str):reverse():gsub("(...)", "%1,"):gsub(",$", ""):reverse()
end

function string.tohex(str)
	return (str:gsub('.', function (c)
		return string.format('%02X', string.byte(c))
	end))
end

local entityMap  = {
	["lt"]		= "<",
	["gt"]		= ">",
	["quot"]	= '"',
	["apos"]	= "'",
	["amp"]		= "&",
	["nbsp"]	= " ",
}

local function entitySwap(orig,n,s)
	return entityMap[s] or n=="#" and char(s) or n=="#x" and char(tonumber(s,16)) or orig
end

function string.unescapeHTML(str)
	local unescaped = gsub(str, '(&(#?x?)([%d%a]+);)', entitySwap)
	return unescaped
end

local htmlEntities = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
    ["/"] = "&#47;"
}

function string.escapeHTML(s)
    assert("Expected string in argument #1.")
    return (string.gsub(s, "[}{\">/<'&]", htmlEntities))
end

function string.stripHTML(str)
	local stripped = gsub(str, "<.->", "")
	return stripped
end

function string.parseArgs(line)
	local cmd, val = line:match("(%S-)%s-=%s+(.+)")
	if cmd and val then
		return {cmd:trim(), val:trim()}
	end
	local quote = line:sub(1,1) ~= '"'
	local ret = {}
	for chunk in string.gmatch(line, '[^"]+') do
		quote = not quote
		if quote then
			table.insert(ret,chunk)
		else
			for chunk in string.gmatch(chunk, "%S+") do -- changed %w to %S to allow all characters except space
				table.insert(ret, chunk)
			end
		end
	end
	return ret
end

function string.Plural(str, num, suffix)
	return num == 1 and str or (str .. (suffix or "s"))
end

function string.AOrAn(s)
	return string.match(s, "^h?[AaEeIiOoUu]") and "an" or "a"
end

function string.longest(...)
	local longest
	for k,str in pairs({...}) do
		if not longest or #longest < #str then
			longest = str
		end
	end
	return longest
end

local STRING = getmetatable("")

function STRING:__index(index)
	local val = string[index]
	if val then
		return val
	elseif tonumber(index) then
		return self:sub(index, index)
	end
end