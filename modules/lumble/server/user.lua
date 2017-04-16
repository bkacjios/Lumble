local user = {}
user.__index = user

local proto = require("lumble.proto")

function user.new(server, socket, session)
	return setmetatable({
		server	= server,
		socket	= socket,
		proto	= proto.UserState(),
	}, user)
end

function user:__tostring()
	return ("%s[%d][%s]"):format(self.proto.name, self.proto.session, self.proto.user_id == 0 and "Unregistered" or "Registered")
end

function user:getClient()
	return self.client
end

return user