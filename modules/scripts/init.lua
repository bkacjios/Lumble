local afk = require("scripts.afk")
local lua = require("scripts.lua")
local mumble = require("lumble")
local log = require("log")
local ev = require("ev")
local lfs = require("lfs")

local params = {
	mode = "client",
	protocol = "sslv23",
	key = "config/dongerbot.key",
	certificate = "config/dongerbot.pem",
}

--local client = mumble.getClient("198.27.70.16", 7331, params)
local client = mumble.getClient("mbl27.gameservers.com", 10004, params)

if not client then return end
client:auth("LuaBot", "", {"dnd"})

local socket = require("socket")

local function createStream(client)
	local timer = ev.Timer.new(function()
		for i=1,2 do
			client:streamAudio()
		end
	end, 0.02, 0.02)
	timer:start(ev.Loop.default)
end

client:hook("OnServerSync", function(client, me)
	createStream(client)
	--[[local channel = client:getChannel("DongerBots Chamber of sentience learning")
	me:move(channel)]]
	--me:setRecording(true)
	--me:setPrioritySpeaker(true)
	--client:playOgg("lookingkindofdumb.ogg")
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
	<td><b>Rolls</b></td><td>: %s</td>
  </tr>
  <tr>
	<td><b>Total</b></td><td>: %d</td>
  </tr>
  <tr>
	<td><b>Min</b></td><td>: %d</td>
  </tr>
  <tr>
	<td><b>Max</b></td><td>: %d</td>
  </tr>
</table>]]):format(num, table.concat(results, ", "), total, math.min(unpack(results)), math.max(unpack(results)))
	end

	local message = string.format("<p><b>%s</b> rolled a <b><span style=\"color:#aa0000\">D%d</span></b> %s", user:getName(), dice, outcome)

	log.info(message:stripHTML())

	if user:getName() == "Orange-Tang" then
		user:message(message)
	else
		user:getChannel():message(message)
	end
end):setHelp("Roll a X sided dice X amount of times"):setUsage("<sides> <times>")

client:addCommand("rollstats", function(client, user, cmd, args)
	local stats = {}

	for i=1,6 do
		local results, total = math.roll(6, 4)

		local stat = 0
		table.sort(results, function(a, b) return a > b end)

		for i=1,3 do
			stat = stat + results[i]
		end

		table.insert(stats, stat)
	end

	user:getChannel():message("<p><b>%s</b>, here are your stats to choose from: <b><span style=\"color:#aa0000\">%s</span></b>", user:getName(), table.concat(stats, ", "))
end):setHelp("Rolls 4 D6, 6 times, and takes the highest 3 values")

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

client:addCommand("about", function(client, user, cmd, args, raw)
	local message = [[<b>LuaBot</b>
Created by <a href="https://github.com/Someguynamedpie">Somepotato</a> &amp; <a href="https://github.com/bkacjios">Bkacjios</a><br/><br/>
<a href="https://github.com/bkacjios/Lumble">https://github.com/bkacjios/Lumble</a>]]
	user:message(message)
end, "Get some information about LuaBot")

client:addCommand("play", function(client, user, cmd, args, raw)
	client:playOgg(("audio/%s.ogg"):format(args[1]), tonumber(args[2]))
end)

client:addCommand("volume", function(client, user, cmd, args, raw)
	local volume = args[1]
	if volume then
		volume = tonumber(volume)/100
		if not user:isMaster() then volume = math.min(volume,1) end
		client:setVolume(volume)
		log.debug(("[COMMAND] %s: changed the volume to %i"):format(user:getName(), volume*100))
	else
		user:message(("Volume level: <b>%i</b>"):format(client:getVolume()*100))
	end
end)

local playlist = {}
local track = 0

local function playPlaylist(client)
	if track >= #playlist then
		track = 0
	end
	track = track + 1

	if playlist[track] then
		client:playOgg(playlist[track])
	end
end

client:hook("AudioFinish", playPlaylist)

client:addCommand("dnd", function(client, user, cmd, args, raw)
	playlist = {}

	local path = ("audio/dnd/%s/"):format(args[1])

	if args[1] == "none" or args[1] == "silence" then
		if client:isPlaying() then
			client:getPlaying():fadeOut(5)
		end
		return
	end	

	if lfs.attributes(path,"mode") ~= "directory" then
		user:message("invalid mode: %s", args[1])
		return
	end

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." and lfs.attributes(path .. file, "mode") == "file" and string.ExtensionFromFile(file) == "ogg" then
			table.insert(playlist, path .. file)
		end
	end

	table.Shuffle(playlist)

	if client:isPlaying() then
		client:getPlaying():fadeOut(5)
	else
		track = 0
		playPlaylist(client)
	end
end):setHelp("Set mood music for D&D")

client:addCommand("fade", function(client, user, cmd, args, raw)
	client.playing:fadeOut(tonumber(args[1]) or 5)
end):setHelp("Fade out the current audio")