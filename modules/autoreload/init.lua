local lfs = require("lfs")
local log = require("log")
local reload = require("autoreload.reload")

local autoreload = {
	monitoring = {},
	hooks = {},
	lastpoll = os.time(),
}

function autoreload.poll()
	if autoreload.lastpoll > os.time() then return end
    autoreload.lastpoll = os.time() + 1

    local list = {}

	for module, info in pairs(autoreload.monitoring) do
		local mod = lfs.attributes(info.file, "modification")
		if info.mod ~= mod then
			info.mod = mod
			table.insert(list, module)
            log.debug("%s marked for reload", module)
		end
	end

	reload.reload(list)
end

function autoreload.getPackageFile(module)
	module = module:gsub("%.", "/")

	for file in string.gmatch(package.path:gsub("?", module), "([^;]+)") do
		if lfs.attributes(file, "mode") == "file" then
			return file
		end
	end
end

function autoreload.watch(module)
	local file = autoreload.getPackageFile(module)

	if not file then
		log.warn("lua module '".. module .. "' not found: skipping, probably C module")
		return
	end

	autoreload.monitoring[module] = {
		file = file,
		mod = lfs.attributes(file, "modification")
	}
end

local original_require = require

function autoreload.require(module)
	autoreload.watch(module)
	return original_require(module)
end

function require(module)
	return autoreload.require(module)
end

return autoreload