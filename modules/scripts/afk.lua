require("extensions.math")
require("extensions.string")

local log = require("log")
local config = require("config")

local afk = {}

function afk.checkStats(client, event)
	local user = event.user

	if user:getName() == "AIArena" then return end

	local root = client:getChannel():getName()

	local afkchannel = client:getChannel(config.afk.channel[root])

	-- Ignore people in the AFK channel
	if not afkchannel or user:getChannel() == afkchannel then return end

	local idle = event.idlesecs or 0

	if idle > config.afk.movetime * 60 then
		user:move(afkchannel)
		log.info("%s moved to %s", user, afkchannel)
	elseif idle > (config.afk.movetime * 60) - (config.afk.warning * 60) then
		if not user.warned then
			local message = config.afk.warningmessage:format(math.SecondsToHuman(idle), afkchannel:getName(), math.SecondsToHuman((config.afk.movetime * 60) - idle))
			user:message(message)
			user.warned = true
			log.info("%s warned they are AFK", user)
		end
	elseif user.warned then
		user.warned = false
		log.info("%s no longer AFK", user)
	end
end

function afk.queryUsers(client)
	for k,user in pairs(client:getUsers()) do
		if user ~= client.me then
			user:requestStats()
		end
	end
end

function afk.install(client)
	client:hook("OnUserStats", "AFK Check", afk.checkStats)
	client:hook("OnPing", "AFK Query User", afk.queryUsers)
end

return afk