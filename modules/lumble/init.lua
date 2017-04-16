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

function mumble.host(host, port, pem, key)
	local params = {
		mode = "server",
		protocol = "any",
		key = key,
		certificate = pem,
		verify = {"peer"},
		options = "all",
	}
	return server.new(host, port, params)
end

return mumble