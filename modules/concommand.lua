local concommand = {
	commands = {},
}

local log = require("log")
local mumble = require("lumble")

require("extensions.channel")
require("extensions.math")
require("extensions.string")
require("extensions.table")
require("extensions.user")

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
		name = name,
		callback = original.callback,
		help = original.help,
	}
end

concommand.Add("help", function(cmd, args)
	print("Command List")
	for name, cmd in pairs(concommand.commands) do
		if name == cmd.name then
			print(("> %-12s"):format(cmd.name) .. (cmd.help and (" - " .. cmd.help) or ""))
		end
	end
end, "Display a list of all commands")
concommand.Alias("help", "commands")

local function longestName(users)
	local longest
	for k,user in pairs(users) do
		local name = user:getName()
		if not longest or #longest < #name then
			longest = name
		end
	end
	return longest
end

concommand.Add("status", function(cmd, args)
	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			print(("%s:%d"):format(host, port))
			print(("\tname  : %s"):format(client:getChannel():getName()))
			print(("\tusers : %d"):format(table.Count(client:getUsers()), client.config.max_users or 0))
			print(("\tuptime: %s"):format(math.SecondsToHuman(client:getTime())))

			local users = client:getUsers()
			local longest = longestName(users)

			print(("# %2s %7s %-".. #longest .."s %s"):format("id", "session", "name", "channel"))
			for k, user in UserPairs(users) do
				local channel = user:getChannel()
				local channel_format = ("%-3d[%s]"):format(channel:getID(), channel:getName():ellipse(24))
				print(("# %2s %7s %-".. #longest .."s %-8s"):format(user:getID(), user:getSession(), user:getName(), channel_format))
			end
		end
	end
end, "Show server statuses")

local function printTree(branch, tabs)
	tabs = tabs or 0
	print(("%s%3i - %s (%i)"):format(("\t"):rep(tabs), branch:getID(), branch:getName(), table.Count(branch:getUsers())))
	for k,user in UserPairs(branch:getUsers()) do
		print(("%s%3i - %s"):format(("\t"):rep(tabs + 1), user:getID(), user:getName()))
	end

	for k,chan in ChannelPairs(branch:getChildren()) do
		printTree(chan, tabs + 1)
	end
end

concommand.Add("channels", function(cmd, args)
	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			local root = client:getChannel()
			printTree(root)
		end
	end
end, "Display a list of all channels")

concommand.Add("disconnect", function(cmd, args)
	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			client.socket:close()
		end
	end
end, "Disconnect from the server")

concommand.Add("exit", function(cmd, args)
	os.exit()
end, "Close the program")
concommand.Alias("exit", "quit")
concommand.Alias("exit", "quti")

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