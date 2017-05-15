local afk = require("scripts.afk")
local lua = require("scripts.lua")
local mumble = require("lumble")

local params = {
	mode = "client",
	protocol = "sslv23",
	key = "config/dongerbot.key",
	certificate = "config/dongerbot.pem",
}

local client = mumble.getClient("mbl27.gameservers.com", 10004, params)
if not client then return end
client:auth("LuaBot")

client:hook("OnServerSync", function(client, me)
	local channel = client:getChannel("DongerBots Chamber of sentience learning")
	me:move(channel)
end)

lua.install(client)
afk.install(client)

client:addCommand("summon", function(client, user, cmd, args, raw)
	client.me:move(user:getChannel())
end):setHelp("Bring me to your channel")

client:addCommand("roll", function(client, user, cmd, args, raw)
	local dice = tonumber(args[1] and args[1]:match("[Dd](%d+)") or args[1]) or 20
	local num = tonumber(args[2]) or 1

	local results, total = math.roll(dice, num)

	local outcome = ("and got <b><span style=\"color:#aa0000\">%d</span></b>"):format(total)

	if num > 1 then
		outcome = ([[<b>x %d</b><table>
  <tr>
    <td><b>Rolls</b></td>
    <td>: %s</td>
  </tr>
  <tr>
    <td><b>Total</b></td>
    <td>: %d</td>
  </tr>
  <tr>
    <td><b>Min</b></td>
    <td>: %d</td>
  </tr>
  <tr>
    <td><b>Max</b></td>
    <td>: %d</td>
  </tr>
</table>]]):format(num, table.concat(results, ", "), total, math.min(unpack(results)), math.max(unpack(results)))
	end

	user:getChannel():message("<p><b>%s</b> rolled a <b><span style=\"color:#aa0000\">D%d</span></b> %s", user:getName(), dice, outcome)
end):setHelp("Roll a X sided dice X amount of times"):setUsage("<sides> <times>")

client:addCommand("help", function(client, user, cmd, args, raw)
	local debug = args[1] == "user"
	local message = "<p>Here's a list of commands<br/>"
	for cmd, info in pairs(client:getCommands()) do
		if cmd == info.cmd and ((info.master and (not debug and user:isMaster())) or not info.master) then
			message = message .. "<b>!" .. cmd .. "</b>" .. (info.help and (" - <i>" .. info.help:escapeHTML() .. "</i>") or "") .. "<br/>"
		end
	end
	user:message(message)
end):setHelp("Display a list of all commands"):alias("commands"):alias("?")