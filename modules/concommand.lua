local concommand = {
	commands = {},
}

local log = require("log")

function concommand.Add(name, cb, help)
	concommand.commands[name] = {
		name = name,
		callback = cb,
		help = help,
	}
end

function concommand.Alias(name, alias)
	local original = concommand.commands[name]
	concommand.commands[alias] = {
		name = alias,
		callback = original.callback,
		help = original.help,
		alias = true
	}
end

concommand.Add("help", function(cmd, args)
	print("Command List")
	for _,cmd in pairs(concommand.commands) do
		print(("> %s"):format(cmd.name))
	end
end, "Display a list of all commands")
concommand.Alias("help", "commands")

function concommand.loop()
	local msg = io.read()
	local args = string.parseArgs(msg)
	local cmd = table.remove(args,1)
	if not cmd then return end
	local info = concommand.commands[cmd:lower()]
	if info then
		local suc, err = pcall(info.callback, cmd, args, msg)
		if not suc then
			log.error("%s (%q)", msg, err)
		end
	else
		print(("Unknown command: %s"):format(cmd))
	end
end

return concommand