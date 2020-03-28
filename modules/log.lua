local log = {
	levels = {
		{ name = "trace", color = "\27[1;34m" },
		{ name = "debug", color = "\27[1;36m" },
		{ name = "info", color = "\27[1;32m" },
		{ name = "warn", color = "\27[1;33m" },
		{ name = "error", color = "\27[1;31m" },
		{ name = "fatal", color = "\27[1;35m" },
	},
	color = jit.os == "Linux",
	date = "%H:%M:%S",
	level = "debug",
	errorfile = io.open("error.log", "a")
}

function log.setColor(b)
	log.color = b
end

function log.setLevel(l)
	log.level = l
end

local format = string.format

for level, cfg in ipairs(log.levels) do
	local upname = cfg.name:upper()
	log[upname] = level

	log[cfg.name] = function(text, ...)
		if log[log.level:upper()] > log[upname] then return end

		if select("#", ...) > 0 then
			text = format(text, ...)
		end

		local date = os.date(log.date)
		local message

		if log.color then
			message = format("[%s%-5s\27[0m - \27[2m%s\27[0m] %s", cfg.color, upname, date, text)
		else
			message = format("[%-5s - %s] %s", upname, date, text)
		end

		if log.errorfile and log[upname] >= log["ERROR"] then
			-- Escape any possible ANSI color characters and write the plain text to the errorfile
			log.errorfile:write(string.stripANSI(message) .. "\n")
		end

		print(message)
	end
end

return log