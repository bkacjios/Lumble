local client = require("lumble.client")
local server = require("lumble.server")
local reload = require("autoreload.reload")
local log = require("log")

local mumble = {
	clients = {},
	servers = {},
	reconnect = {},
}

function mumble.connect(host, port, params)
	local client, err = client.new(host, port, params)

	if not client then
		table.insert(mumble.reconnect, {host = host, port = port, params = params, time = os.time() + 1})
		return false, err
	end

	mumble.clients[host] = mumble.clients[host] or {}
	mumble.clients[host][port] = client

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
	local time = os.time()

	for i, info in pairs(mumble.reconnect) do
		if info.time <= time then
			log.debug("reconnecting.. (%s attempt)", math.stndrd(info.try))
			local client, err = mumble.connect(info.host, info.port, info.params)
			if client then
				mumble.reconnect[i] = nil
				client:auth(info.username, info.password)
			else
				info.time = time + info.try * 5
				info.try = info.try + 1
			end
		end
	end

	for host, clients in pairs(mumble.clients) do
		for port, client in pairs(clients) do
			local status, err = client:update()
			if not status and err then
				mumble.clients[host][port] = nil
				table.insert(mumble.reconnect, {
					host = client.host,
					port = client.port,
					params = client.params,
					username = client.username,
					password = client.password,
					time = time + 1,
					try = 1,
				})
			end
		end
	end
end

return mumble