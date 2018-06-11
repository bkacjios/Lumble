local byte = string.byte
local char = string.char
local gsub = string.gsub
local lower = string.lower
local upper = string.upper
local match = string.match
local gmatch = string.gmatch
local format = string.format

local max = math.max

function string.GetPathFromFilename(path)
	return path:match("^(.*[/\\])[^/\\]-$") or ""
end

function string.ExtensionFromFile( path )
	return path:match("%.([^%.]+)$")
end

function string.StripExtension( path )
	local i = path:match(".+()%.[^%.]+$")
	if i then return path:sub(1, i-1) end
	return path
end

function string.gisub(s, pat, repl, n)
	pat = gsub(pat, '(%a)', function (v)
		return '['..upper(v)..lower(v)..']'
	end)

	if n then
		pat = gsub(s, pat, repl, n)
	else
		pat = gsub(s, pat, repl)
	end

	return pat
end

function string.trim(self, char)
	char = char or "%s"
	return self:gsub("^"..char.."*(.-)"..char.."*$", "%1" )
end

function string.ltrim(s)
	return s:gsub("^%s*", "")
end

function string.rtrim(s)
	local n = #s
	while n > 0 and s:find("^%s", n) do n = n - 1 end
	return s:sub(1, n)
end

function string.AddCommas(str)
	return tostring(str):reverse():gsub("(...)", "%1,"):gsub(",$", ""):reverse()
end

function string.tohex(str)
	return (str:gsub('.', function (c)
		return format('%02X', byte(c))
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
    return (gsub(s, "[}{\">/<'&]", htmlEntities))
end

function string.stripHTML(str)
	local stripped = gsub(str, "<.-/?>", "")
	return stripped
end

function string.parseArgs(line)
	local cmd, val = line:match("(%S-)%s-=%s+(.+)")
	if cmd and val then
		return {cmd:trim(), val:trim()}
	end
	local quote = line:sub(1,1) ~= '"'
	local ret = {}
	for chunk in gmatch(line, '[^"]+') do
		quote = not quote
		if quote then
			table.insert(ret,chunk)
		else
			for chunk in gmatch(chunk, "%S+") do -- changed %w to %S to allow all characters except space
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
	return match(s, "^h?[AaEeIiOoUu]") and "an" or "a"
end

function string.ellipse(s, len)
	len = max(len or 3, 3)
	if #s >= len then
		local before = s:sub(1, len - 3):rtrim()
		return before .. "..."
	end
	return s
end

function string.longest(t)
	local longest
	for k,str in pairs(t) do
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