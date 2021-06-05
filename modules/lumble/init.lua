local client = require("lumble.client")
local server = require("lumble.server")
local reload = require("autoreload.reload")
--local copas = require("copas")
local log = require("log")

local mumble = {
	clients = {},
	servers = {},
	reconnect = {},
}

function mumble.connect(host, port, params, noretry)
	local client, err = client.new(host, port, params)

	if not client then
		if not noretry then
			table.insert(mumble.reconnect, {host = host, port = port, params = params, try = 1})
		end
		return false, err
	end

	mumble.clients[host] = mumble.clients[host] or {}
	mumble.clients[host][port] = client

	-- If we disconnect, try to reconnect
	client:hook("OnDisconnect", "Reconnect on Disconnect", function(client)
		mumble.clients[client.host][client.port] = nil
		table.insert(mumble.reconnect, {
			host = client.host,
			port = client.port,
			params = client.params,
			username = client.username,
			password = client.password,
			tokens = client.tokens,
			hooks = client.hooks or {}, -- Carry over all hooks..
			commands = client.commands or {}, -- Carry over all commands..
			try = 1,
		})
	end)

	reload.reload("scripts")

	return client
end

function mumble.getClients()
	return mumble.clients
end

function mumble.getClient(host, port, params)
	if mumble.clients[host] and mumble.clients[host][port] then
		return mumble.clients[host][port]
	end

	return mumble.connect(host, port, params)
end

function mumble.host(host, port)
	local params = {
		mode = "server",
		protocol = "any",
		key = "config/serverAkey.pem",
		certificate = "config/serverA.pem",
		cafile = "config/rootA.pem",
		verify = {"none"},
		options = "all",
	}
	return server.new(host, port, params)
end

function mumble.update()
	for i, info in pairs(mumble.reconnect) do
		log.debug("reconnecting.. (%s attempt)", math.stndrd(info.try))
		local client, err = mumble.connect(info.host, info.port, info.params, true)
		if client then
			mumble.reconnect[i] = nil
			client.hooks = info.hooks or client.hooks
			client.commands = info.commands or client.commands
			client:auth(info.username, info.password, info.tokens)
		else
			info.try = info.try + 1
		end
	end
end

--[[function mumble.setup()
	copas.addthread(mumble.update)
end]]

return mumble