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

concommand.Add("ping", function(cmd, args)
	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			print(("%s:%d"):format(host, port))
			print(("\tname  : %s"):format(client:getChannel()))
			print("TCP Stats")
			print(("\tpackets : %d"):format(client.ping.tcp_packets))
			print(("\tping    : %.02f"):format(client.ping.tcp_ping_avg))
			print("UDP Stats")
			print(("\tpackets : %d"):format(client.ping.udp_packets))
			print(("\tping    : %.02f"):format(client.ping.udp_ping_avg))
		end
	end
end)

concommand.Add("status", function(cmd, args)
	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			print(("%s:%d"):format(host, port))
			print(("\tname  : %s"):format(client:getChannel()))
			print(("\tusers : %d"):format(table.Count(client:getUsers()), client.config.max_users or 0))
			print(("\tuptime: %s"):format(math.SecondsToHuman(client:getTime())))

			local users = client:getUsers()
			local longest = longestName(users)

			print(("# %2s %3s %-".. #longest .."s %-16s %-18s %-11s %s"):format("id", "ses", "name", "ip", "channel", "online", "idle"))
			for k, user in UserPairs(users) do
				local channel = user:getChannel()
				local channel_format = ("%-3d[%-13s]"):format(channel:getID(), channel:getName():ellipse(13))
				print(("# %2s %3s %-".. #longest + 11 .."s %-16s %-18s %-11s %s"):format(user:getID(), user:getSession(), user, user:getAddress(), channel_format, math.SecondsToHuman(user:getStat("onlinesecs", 0), 1), math.SecondsToHuman(user:getStat("idlesecs", 0), 1)))
			end
		end
	end
end, "Show server statuses")

local function printTree(branch, tabs)
	tabs = tabs or 0

	local users, num_users = branch:getUsers()

	if num_users > 0 then
		print(("%s%3i - %s (%i)"):format(("\t"):rep(tabs), branch:getID(), branch, num_users))
	else
		print(("%s%3i - %s"):format(("\t"):rep(tabs), branch:getID(), branch))
	end

	for k,user in UserPairs(users) do
		print(("%s%3i - %s"):format(("\t"):rep(tabs + 1), user:getID(), user))
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
			client:close()
		end
	end
end, "Disconnect from the server")

concommand.Add("say", function(cmd, args, raw)
	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			client.me:getChannel():message(raw:sub(4))
		end
	end
end, "Say a thing")

concommand.Add("exit", function(cmd, args)
	os.exit()
end, "Close the program")
concommand.Alias("exit", "quit")
concommand.Alias("exit", "quti")

function concommand.loop()
	local msg = io.read()
	if not msg then return end
	local args = string.parseArgs(msg)
	local cmd = table.remove(args,1)
	if not cmd then return end
	local info = concommand.commands[cmd:lower()]
	if info then
		local suc, err = pcall(info.callback, cmd, args, msg)
		if not suc then
			log.error("%q (%s)", msg, err)
		end
	else
		print(("Unknown command: %q"):format(cmd))
	end
end

return concommand