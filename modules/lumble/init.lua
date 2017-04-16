local client = require("lumble.client")
local server = require("lumble.server")

local mumble = {}

function mumble.connect(host, port, pem, key)
	local params = {
		mode = "client",
		protocol = "sslv23",
		key = key,
		certificate = pem,
	}

	return client.new(host, port, params)
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

return mumble