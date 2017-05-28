local client = require("lumble.client")
local server = require("lumble.server")
local reload = require("autoreload.reload")
local synch = require("synchronous")
local log = require("log")

local mumble = {
	clients = {},
	servers = {},
	reconnect = {},
}
--Returns a promise to the client.
function mumble.connect(host, port, params, noretry)
	
	return synch.promise(function(fulfill, reject)
		local ret = client.new(fulfill, reject, host, port, params)
		if not ret then return end
		mumble.clients[host] = mumble.clients[host] or {}
		mumble.clients[host][port] = client
	end)
	
	--[[
	if not client then
		if not noretry then
			table.insert(mumble.reconnect, {host = host, port = port, params = params, time = os.time() + 1, try = 1})
		end
		return false, err
	end
	]]

end

function mumble.getClients()
	return mumble.clients
end

function mumble.getClient(host, port, params)
	if mumble.clients[host] and mumble.clients[host][port] then
		return synch.promise(function(fulfill)
			fulfill(mumble.clients[host][port])
		end)
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
	local time = synch.getTime()

	for i, info in pairs(mumble.reconnect) do
		if info.time <= time then
			log.debug("reconnecting.. (%s attempt)", math.stndrd(info.try))
			local client, err = mumble.connect(info.host, info.port, info.params, true)
			if client then
				mumble.reconnect[i] = nil
				client:auth(info.username, info.password)
			else
				info.time = time + (info.try * 5)
				info.try = info.try + 1
			end
		end
	end

end

function mumble.setup()
	synch.addThread(mumble.update)
end

return mumble