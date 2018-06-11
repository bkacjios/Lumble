local afk = require("scripts.afk")
local lua = require("scripts.lua")
local mumble = require("lumble")
local log = require("log")
local ev = require("ev")
local lfs = require("lfs")
local config = require("config")
require("shunting")
require("extensions.io")

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

--lua.install(client)
afk.install(client)

client:addCommand("summon", function(client, user, cmd, args, raw)
	client.me:move(user:getChannel())
end):setHelp("Bring me to your channel")

client:addCommand("math", function(client, user, cmd, args, raw)
	local str = raw:sub(#cmd+2)

	local stack, err = math.postfix(str)

	if not stack then
		local message = string.format("<p><b><span style=\"color:#aa0000\">error</span></b>: %s", err)
		log.info(message:stripHTML())
		user:message(message)
		return
	end

	local node = math.postfix_to_infix(stack)
	local equation = math.infix_to_string(node)
	local total = math.solve_postfix(stack)

	user:message(string.format("<table><tr><td><b>Equation</b></td><td>: %s</td></tr><tr><td><b>Solution</b></td><td>: %s</td></tr></table>", equation, total))
end):setHelp("Calculate a mathematical expression"):setUsage("<expression>")


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
	["Ranger Rick"] = 5,
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
			--rolled_initiatives = {}
			--did_roll = {}
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
	local message = string.format("<p><b>%s</b> rolled a <b><span style=\"color:#3377ff\">%d</span></b> (%d + %d) initiative", name, total + bonus, total, bonus)
	table.insert(rolled_initiatives, {name = name, roll = total, bonus = bonus})
	table.sort(rolled_initiatives, function(a, b) return a.roll + a.bonus > b.roll + b.bonus end)

	if not client:isPlaying() then
		local stream = client:createOggStream(("audio/dnd/dice_roll_1-%d.ogg"):format(math.random(1, 2)))
		stream:setVolume(1)
		client:playOggStream(stream)
	end

	user:getChannel():message(message)
end):setHelp("Roll for initiative"):setUsage("[clear, list]"):alias("init")

local advantage_shortcuts = {
	"advantage",
	"advan",
	"adv",
}

local disadvantage_shortcuts = {
	"disadvantage",
	"disadvan",
	"disadv",
	"dadvan",
	"disad",
	"dadv",
}

client:addCommand("roll", function(client, user, cmd, args, raw)
	local str = raw:sub(#cmd+2)

	for _, dadv in pairs(disadvantage_shortcuts) do
		str = str:gsub(dadv, "min(d20, d20)")
	end
	for _, adv in pairs(advantage_shortcuts) do
		str = str:gsub(adv, "max(d20, d20)")
	end

	if not str:match("%d-[Dd]%d+") then
		str = "d20" .. (str ~= "" and (" %s"):format(str) or "")
	end

	local rolls = {}
	local orig_str = str
	local num_rolls = 0

	str = string.gsub(str, "(%d-)[Dd](%d+)", function(num, dice)
		num = tonumber(num) or 1
		dice = tonumber(dice)
		local results, total = math.roll(dice, num)
		rolls[dice] = rolls[dice] or {}
		num_rolls = num_rolls + num
		for k, result in pairs(results) do
			table.insert(rolls[dice], result)
		end
		return ("(%s)"):format(table.concat(results, "+"))
	end)

	local stack, err = math.postfix(str)

	if not stack then
		local message = string.format("<p><b><span style=\"color:#aa0000\">Error</span></b>: %s", err)
		log.info(message:stripHTML())
		user:message(message)
		return
	end

	local node = math.postfix_to_infix(stack)
	local equation = math.infix_to_string(node)
	local total = math.solve_postfix(stack)

	local username = user:getName()
	local name = name_convert[username] or username

	local message = string.format("<p><b>%s</b> rolled <b><span style=\"color:#3377ff\">%s</span></b> and got <b><span style=\"color:#3377ff\">%s</span></b>", name, orig_str:gsub("%s+", ""), total)

	if #stack > 2 then
		message = message .. ("\n<table><tr><td><b>Equation</b></td><td>: %s</td></tr>"):format(equation:gsub("%%", "%%%%"))
		message = message .. ("\n<tr><td><b>Solution</b></td><td>: %s</td></tr>"):format(total)

		for dice, results in pairs(rolls) do
			local roll_list = ""
			for k, roll in pairs(results) do
				if dice == roll then
					roll_list = roll_list .. "<b><span style=\"color:#00aa00\">" .. roll .. "</span></b>"
				elseif roll == 1 then
					roll_list = roll_list .. "<b><span style=\"color:#aa0000\">" .. roll .. "</span></b>"
				else
					roll_list = roll_list .. roll
				end
				if k < #results then
					roll_list = roll_list .. ", "
				end
			end
			message = message .. ("\n<tr><td><b>D%d Rolls</b></td><td>: %s</td></tr>"):format(dice, roll_list)
		end

		message = message .. "</table>"
	end

	log.info(message:stripHTML())

	if cmd:sub(2) == "proll" then
		user:message(message)
	else
		if not client:isPlaying() then
			local sound_num = math.min(num_rolls, 6)
			local rand = math.random(1, 2)
			local stream = client:createOggStream(("audio/dnd/dice_roll_%d-%d.ogg"):format(sound_num, rand))
			stream:setVolume(1)
			client:playOggStream(stream)
		end
		user:getChannel():message(message)
	end
end):setHelp("Roll some dice"):setUsage("[1D20 [, expression]]"):alias("proll"):alias("rtd")

client:addCommand("flip", function(client, user, cmd, args, raw)
	local number = tonumber(args[1]) or 1

	local results, total = math.roll(2, number)

	local num_heads = 0
	local num_tails = 0

	for i=1,#results do
		local heads = results[i] == 1
		num_heads = num_heads + (heads and 1 or 0)
		num_tails = num_tails + (heads and 0 or 1)
		results[i] = heads and "heads" or "tails"
	end

	local username = user:getName()
	local name = name_convert[username] or username

	local message

	if #results > 1 then
		message = ("<b>%s</b> flipped <i>%d coins</i> and got <b><span style=\"color:#3377ff\">%d heads</span></b> and <b><span style=\"color:#3377ff\">%d tails</span></b>"):format(name, #results, num_heads, num_tails)
	else
		message = ("<b>%s</b> flipped a coin and got <b><span style=\"color:#3377ff\">%s</span></b>"):format(name, results[1])
	end

	log.info(message:stripHTML())

	if cmd:sub(2) == "pflip" then
		user:message(message)
	else
		if not client:isPlaying() then
			local stream = client:createOggStream(("audio/dnd/coin_flip-%d.ogg"):format(math.random(1,2)))
			stream:setVolume(1)
			client:playOggStream(stream)
		end
		user:getChannel():message(message)
	end
end):setHelp("Flip a coin"):setUsage("[#coins = 1]"):alias("pflip")

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

	if not client:isPlaying() then
		local stream = client:createOggStream(("audio/dnd/dice_roll_4-%d.ogg"):format(math.random(1, 2)))
		stream:setVolume(1)
		client:playOggStream(stream)
	end

	user:getChannel():message("<p><b>%s</b>, here are your stats to choose from: <b><span style=\"color:#3377ff\">%s</span></b>", user:getName(), table.concat(stats, ", "))
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
		end
	end
	user:message(message .. "</table>")
end):setHelp("List all commands"):alias("commands"):alias("?")

client:addCommand("source", function(client, user, cmd, args, raw)
	local command = client:getCommand(args[1])
	if command then
		local info = debug.getinfo(command.callback)
		local f, err = io.open(info.short_src, "r")
		local source = f:readLines(info.linedefined, info.lastlinedefined)
		local fixed = source:gsub("%%", "%%%%"):escapeHTML():gsub("\r", "<br/>"):gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		user:message("<p>" .. fixed .. "</p>")
	end
end)

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

local json = require("dkjson")
local https = require("ssl.https")

local function getDuration(stamp)
	local hours = string.match(stamp, "(%d+)H") or 0
	local minutes = string.match(stamp, "(%d+)M") or 0
	local seconds = string.match(stamp, "(%d+)S") or 0

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	else
		return string.format("%02d:%02d", minutes, seconds)
	end
end

function twitchHttps(url, ...)
	local t = {}
	local r, c, h = https.request({
		url = url:format(...),
		sink = ltn12.sink.table(t),
		headers = {
			["Client-ID"] = config.twitch.client,
		},
	})

	r = table.concat(t, "")
	return r, c, h
end


local function formatTwitch(id)
	local req = twitchHttps(("https://api.twitch.tv/helix/clips?id=%s"):format(id))
	if not req then return end
	if( #req == 0 ) then return end

	local js = json.decode(req)

	local items = js.data[1]

	if not items then return "Private or invalid Twitch.tv Clip." end

	return ([[
<center><table>
	<tr>
		<td align="center" valign="middle">
			<h3>%s</h3>
		</td>
	</tr>
	<tr>
		<td align="center">
			<a href="%s"><img src="%s" width="250" /></a>
		</td>
	</tr>
</table></center>
]]):format(items.title, items.url, items.thumbnail_url):gsub("%%", "%%%%")
end

local function formatYoutube(id)
	local req = https.request(("https://www.googleapis.com/youtube/v3/videos?key=%s&part=statistics,snippet,contentDetails&id=%s"):format(config.youtube.api, id))
	if not req then return end
	if( #req == 0 ) then return end

	local js = json.decode(req)

	local items = js.items[1]

	if not items then return "Private or invalid YouTube video." end

	return ([[
<center><table>
	<tr>
		<td align="center" valign="middle">
			<h3>%s (%s)</h3>
		</td>
	</tr>
	<tr>
		<td align="center">
			<a href="http://youtu.be/%s"><img src="%s" width="250" /></a>
		</td>
	</tr>
</table></center>
]]):format(items.snippet.title, getDuration(items.contentDetails.duration), id, items.snippet.thumbnails.medium.url)
end

local function formatOther(url)
	return ([[<p><center><a href="%s"><img src="%s" width="250" /></a></center>]]):format(url, url, url)
end

local valid_others = {
	["jpg"] = true,
	["jpeg"] = true,
	["gif"] = true,
	["png"] = true,
	["tga"] = true,
	["tif"] = true,
	["bmp"] = true,
}

client:hook("OnTextMessage", "Thumbnails", function(client, event)
	local message = event.message:unescapeHTML():stripHTML()
	local user = event.actor

	local youtube = message:match("youtube%.com/watch.-v=([%w_-]+)") or message:match("youtu%.be/([%w_-]+)" )
	local twitch = message:match("clips.twitch.tv/(%w+)")
	local other = message:match("(https?://[%w%p]+)")

	if youtube then
		user:getChannel():message(formatYoutube(youtube))
	end
	if twitch then
		user:getChannel():message(formatTwitch(twitch))
	end
	if other then
		local ext = string.ExtensionFromFile(other):lower()
		if valid_others[ext] then
			user:getChannel():message(formatOther(other))
		end
	end
end)