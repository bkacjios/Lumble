local lfs = require("lfs")

local autoreload = {
	monitoring = {},
	lastpoll = os.time(),
}

function autoreload.poll()
	if autoreload.lastpoll > os.time() then return end
	autoreload.lastpoll = os.time() + 1

	for k,v in pairs(autoreload.monitoring) do
		local mod = lfs.attributes(k, "modification")
		if v ~= mod then
			autoreload.monitoring[k] = mod
			local succ, err = pcall(dofile, k)
			if not succ then
				log.error(("[AUTORELOAD] %s"):format(err))
			else
				log.debug(("[AUTORELOAD] %s"):format(k))
			end
		end
	end
end

function autoreload.watch(f)
	autoreload.monitoring[f] = lfs.attributes(f, "modification")
end

function include(f)
	autoreload.watch(f)
	local succ, err = pcall(dofile, f)
	if not succ then
		log.error(("[INITIALIZE] %s"):format(err))
	end
end

function includeDir(directory)
	for file in lfs.dir(directory) do
		if file ~= '.' and file ~= '..' then
			local path = directory .. file
			local mode = lfs.attributes(path, "mode")
			if mode == 'file' then
				include(path)
			end
		end
	end
end