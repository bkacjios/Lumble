local afk = require("scripts.afk")
local lua = require("scripts.lua")
local mumble = require("lumble")
local log = require("log")
local ev = require("ev")
local lfs = require("lfs")
local config = require("config")
require("shunting")

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

local name_convert = {
	["Amer"] = "Sancho",
	["Atsu"] = "Drak",
	["Bkacjios"] = "Bhord",
	["Paste"] = "Ranger Rick",
	["Will"] = "Hrangus",
}

local inititive = {
	["Sancho"] = 5,
	["Drak"] = 4,
	["Bhord"] = 0,
	["Ranger Rick"] = 4,
	["Hrangus"] = 1,
}

local did_roll = {}
local rolled_initiatives = {}

client:addCommand("initiative", function(client, user, cmd, args, raw)
	local results, total = math.roll(20, 1)

	local username = user:getName()
	local name = name_convert[username] or username

	if args[1] == "list" then
		local message = "<p>Iinitiative order<ol>"
		for k,v in pairs(rolled_initiatives) do
			message = message .. string.format("<li><b>%s</b>: %d</li>", v.name, v.roll + v.bonus)
		end
		message = message .. "</ol>"

		if name == "Orange-Tang" then
			rolled_initiatives = {}
			did_roll = {}
			user:getChannel():message(message)
		else
			user:message(message)
		end
		return
	elseif args[1] == "clear" then
		if name == "Orange-Tang" then
			rolled_initiatives = {}
			did_roll = {}
			user:message("Initiative list cleared")
		else
			user:message("Only the DM can clear the initiative list")
		end
		return
	end

	if did_roll[name] then
		user:message(string.format("<i>%s</i>, you already rolled your initiative..", name))
		return
	end
	did_roll[name] = true
	local bonus = (inititive[name] or 0)
	local message = string.format("<p><b>%s</b> rolled a <b><span style=\"color:#aa0000\">%d</span></b> (%d + %d) initiative", name, total + bonus, total, bonus)
	table.insert(rolled_initiatives, {name = name, roll = total, bonus = bonus})
	table.sort(rolled_initiatives, function(a, b) return a.roll + a.bonus > b.roll + b.bonus end)
	user:getChannel():message(message)
end):setHelp("Roll for initiative"):setUsage("[clear, list]"):alias("init")

client:addCommand("math", function(client, user, cmd, args, raw)
	local str = raw:sub(#cmd+2)

	local shunting, err = math.shunting(str)

	if not shunting then
		local message = string.format("<p><b><span style=\"color:#aa0000\">error</span></b>: %s", err)
		log.info(message:stripHTML())
		user:message(message)
		return
	end

	local total = math.solve_shunting(shunting)

	user:getChannel():message(string.format("<table><tr><td><b>Solution</b></td><td>: %s</td></tr></table>", total))
end):setHelp("Calculate a mathematical expression"):setUsage("<expression>")

client:addCommand("roll", function(client, user, cmd, args, raw)
	local str = raw:sub(#cmd+2)

	if #str <= 0 then
		str = "d20"
	elseif args[1] == "advantage" or args[1] == "adv" then
		str = "max(d20, d20)"
	elseif args[1] == "disadvantage" or args[1] == "disadv" then
		str = "min(d20, d20)"
	end

	local rolls = {}
	local num_rolls = 0

	str = string.gsub(str, "(%d+)[Dd](%d+)", function(num, dice)
		num_rolls = num_rolls + num
		local results, total = math.roll(dice, num)
		local name = ("D%d"):format(dice)
		rolls[name] = rolls[name] or {}
		for k, result in pairs(results) do
			table.insert(rolls[name], result)
		end
		return ("(%s)"):format(table.concat(results, "+"))
	end)

	str = string.gsub(str, "[Dd](%d+)", function(dice)
		num_rolls = num_rolls + 1
		local name = ("D%d"):format(dice)
		rolls[name] = rolls[name] or {}
		local results, total = math.roll(dice, 1)
		for k, result in pairs(results) do
			table.insert(rolls[name], result)
		end
		return ("%s"):format(table.concat(results, "+"))
	end)

	local stack, err = math.postfix(str)

	if not stack then
		local message = string.format("<p><b><span style=\"color:#aa0000\">error</span></b>: %s", err)
		log.info(message:stripHTML())
		user:message(message)
		return
	end

	local total = math.solve_postfix(stack)

	local username = user:getName()
	local name = name_convert[username] or username

	local rolled_dice = {}

	for dice, results in pairs(rolls) do
		table.insert(rolled_dice, #results > 1 and ("%d%s"):format(#results, dice) or dice)
	end

	local message = string.format("<p><b>%s</b> rolled <b><span style=\"color:#aa0000\">%s</span></b> and got <b><span style=\"color:#aa0000\">%s</span></b>", name, table.concatList(rolled_dice), total)

	if #stack > 2 then
		message = message .. ("\n<table><tr><td><b>Equation</b></td><td>: %s = %s</td></tr>"):format(str:gsub("%s", ""):gsub("%%", "%%%%"):escapeHTML(), total)

		for dice, results in pairs(rolls) do
			message = message .. ("\n<tr><td><b>%s</b></td><td>: %s</td></tr>"):format(dice:upper(), table.concat(results, ", "))
		end

		message = message .. "</table>"
	end

	log.info(message:stripHTML())

	if cmd:sub(2) == "proll" then
		user:message(message)
	else
		user:getChannel():message(message)
	end
end):setHelp("Roll some dice"):setUsage("[1D20 [, expression]]"):alias("proll")

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
end):setHelp("Rolls 4D6 and takes the highest 3 values, 6 times")

client:addCommand("help", function(client, user, cmd, args, raw)
	local debug = args[1] == "user"
	local message = "<table><tr><th>command</th><th>arguments</th><th>help</th></tr>"

	local commands = {}

	for cmd,info in pairs(client:getCommands()) do
		table.insert(commands, info)
	end

	table.sort(commands, function(a, b) return a.cmd < b.cmd end)

	for k, info in pairs(commands) do
		if ((info.master and (not debug and user:isMaster())) or not info.master) then
			message = message .. ("<tr><td><b>%s%s</b></td><td>%s</td><td>%s</td></tr>"):format(cmd[1], info.name, info.usage:escapeHTML(), info.help:escapeHTML())
			--message = message .. "<b>" .. cmd[1] .. info.name .. "</b>" .. (info.help and (" - <i>" .. info.help:escapeHTML() .. "</i>") or "") .. "<br/>"
		end
	end
	user:message(message .. "</table>")
end):setHelp("List all commands"):alias("commands"):alias("?")

client:addCommand("about", function(client, user, cmd, args, raw)
	local message = [[<b>LuaBot</b>
Created by <a href="https://github.com/Someguynamedpie">Somepotato</a> &amp; <a href="https://github.com/bkacjios">Bkacjios</a><br/><br/>
<a href="https://github.com/bkacjios/Lumble">https://github.com/bkacjios/Lumble</a>]]
	user:message(message)
end, "Get some information about LuaBot")

client:addCommand("play", function(client, user, cmd, args, raw)
	client:playOgg(("audio/%s.ogg"):format(args[1]), tonumber(args[2]))
end):setHelp("Play an audio file"):setUsage("<file> [volume]")

local restricted = {}

client:addCommand("restrict", function(client, user, cmd, args, raw)
	local name = args[1]

	local channel = user:getChannel()
	local path = channel:getPath()

	restricted[path] = restricted[path] or {}

	if not restricted[path][name] then
		user:getChannel():message("%s is now restricted from joining %s", name, channel:getName())
		restricted[path][name] = true
	else
		user:getChannel():message("%s is no longer restricted from joining %s", name, channel:getName())
		restricted[path][name] = false
	end
end):setHelp("Restrict a user from joining your current channel"):setUsage("<username>")

client:hook("OnUserChannel", "LuaBot - User Restrict", function(client, event)
	local user = event.user
	local name = user:getName()
	local channel = event.channel
	local path = event.channel:getPath()

	if restricted[path] and restricted[path][name] then
		user:message("You are currently restricted from joining %s", channel:getName())
		user:move(event.channel_from)
	end
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
end):setHelp("Set the volume of any playing audio"):setUsage("<volume>")

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
		local moods = {}

		for file in lfs.dir("audio/dnd") do
			if lfs.attributes(path,"mode") ~= "directory" and file ~= "." and file ~= ".." then
				table.insert(moods, file)
			end
		end

		user:message("<i>Invalid mode</i>: %s<br/><b>Available Modes</b><br/>%s", args[1], table.concat(moods, "<br/>"))
		user:message(file)
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
end):setHelp("Set music for D&D"):setUsage("<mood>"):alias("mood")

client:addCommand("fade", function(client, user, cmd, args, raw)
	client.playing:fadeOut(tonumber(args[1]) or 5)
end):setHelp("Fade out the current audio")

client:addCommand("afk", function(client, user, cmd, args, raw)
	local root = client:getChannel():getName()

	local afkchannel = client:getChannel(config.afk.channel[root])

	if not afkchannel or user:getChannel() == afkchannel then return end

	user:move(afkchannel)
end):setHelp("Make the bot move you to the AFK channel")