local lfs = require("lfs")
local log = require("log")
local reload = require("autoreload.reload")
require("extensions.io")

local autoreload = {
	monitoring = {},
	lastpoll = os.time(),
}

function autoreload.poll()
	if autoreload.lastpoll > os.time() then return end
	autoreload.lastpoll = os.time() + 1

	for module, info in pairs(autoreload.monitoring) do
		local changed = lfs.attributes(info.file, "modification")
		if info.changed ~= changed then
			info.changed = changed

			local f, err = io.open(info.file, "rb")

			if f then
				local crc = f:crc32()
				f:close()

				if info.crc ~= crc then
					local status, err = reload.reload(module)
					if status then
						info.crc = crc
						log.debug("%s[%q] reloaded: %X", module, info.file, crc)
					else
						log.error("%s[%q] reload failed: %s", module, info.file, err)
					end
				end
			else
				log.warn("%s[%q] %s", module, info.file, err)
			end
		end
	end
end

function autoreload.getPackageFile(module)
	module = module:gsub("%.", "/")
	for file in string.gmatch(package.path:gsub("?", module), "([^;]+)") do
		if lfs.attributes(file, "mode") == "file" then
			local f = io.open(file, "rb")
			local crc = f:crc32()
			f:close()
			return file, crc
		end
	end
end

function autoreload.watch(module)
	if module == "autoreload" or module == "autoreload.reload" then return end

	local file, crc = autoreload.getPackageFile(module)

	if not file then
		--log.warn("lua module '".. module .. "' not found: skipping, probably C module")
		return
	end

	if autoreload.monitoring[module] then return end

	log.trace("watching %s[%q]", module, file)

	autoreload.monitoring[module] = {
		file = file,
		crc = crc,
		changed = lfs.attributes(file, "modification")
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