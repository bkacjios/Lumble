local client = require("lumble.client")

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

return mumble