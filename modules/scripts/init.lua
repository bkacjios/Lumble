local afk = require("scripts.afk")
local lua = require("scripts.lua")
local mumble = require("lumble")
local log = require("log")
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

local client = mumble.getClient("::1", 64738, params)

if not client then return end 
client:auth("LuaBot", "dix", {"dnd", "hedoesntevenknow", })

client:hook("OnUserStartSpeaking", function(client, user)
	--print("START SPEAKING", user)
	user.speech_last = client:getTime()
	user.speech_delay_last = 0
	user.speech_delay_prev = 0
	user.speech_delay_avg = 0
	user.speech_delay_highest = 0
end)

local function roundToNearestEvenTenth(num)
	-- Convert 0.01 to 1, 0.02 to 2 and so on..
	local tenth = num * 100
	local rounded = math.floor(tenth + 0.5)

	-- If it's an odd number and greater than 1
	-- This fixes times like 0.03
	if rounded > 1 and rounded % 2 == 1 then
		-- Round to closest even number
		if tenth >= rounded then
			rounded = math.ceil(tenth + 0.5)
		else
			rounded = math.floor(tenth - 0.5)
		end
	end

	return rounded / 100
end

function math.sineBetween(min, max, t)
    local halfRange = (max - min) / 2
    return min + halfRange + math.sin(t) * halfRange
end

local lastDay = tonumber(os.date("%w"))

client:hook("OnPing", function(client, ms)
	local day = tonumber(os.date("%w"))

	if day ~= lastDay then
		lastDay = day
		log.info("Date changed: %s", os.date("%a, %b %d %Y"))
	end
end)

client:hook("OnUserSpeak", function(client, event)
	local t = client:getTime()

	local user = event.user

	-- Round to nearest tenth
	local delay = roundToNearestEvenTenth(t - user.speech_last)
	-- delay = time between each packet

	if delay ~= 0 then
		user.speech_delay_prev = user.speech_delay_last
		user.speech_delay_last = delay
	
		if user.speech_delay_last ~= 0 and user.speech_delay_prev ~= 0 then
			user.speech_delay_avg = (user.speech_delay_prev + delay) / 2
		else
			user.speech_delay_avg = delay
		end
	end

	if delay > user.speech_delay_highest then
		user.speech_delay_highest = delay
	end

	--print(delay, user.speech_delay_avg)

	user.speech_last = t
end)

client:hook("OnUserStopSpeaking", function(client, user)
	--print("END SPEAKING", user)
	--print("Delay: ", user.speech_delay_highest)
end)

local channelsounds = {
	[3] = "audio/soundboard/dotes.ogg", -- Dota2
	[4] = "audio/soundboard/midas.ogg", -- CIV VI
	[29] = "audio/soundboard/absoluteclassic.ogg", -- An Absolute Classic
	[33] = "audio/soundboard/woaw.ogg", -- WoW of Worldcraft
	[40] = "audio/soundboard/boom.ogg", -- BOOM TETRIS
	[41] = "audio/soundboard/n64.ogg", -- Nintenies
	[47] = "audio/soundboard/hands.ogg", -- Deepthroat Galactic
	[48] = "audio/soundboard/cum.ogg", -- Cum
	[49] = { -- With You
		"audio/withyou_short-1.ogg",
		"audio/withyou_short-2.ogg",
	},
	[50] = { -- War Thunder
		"audio/soundboard/planecrash.ogg",
		"audio/soundboard/advancedtechnology.ogg",
	},
	[6] = "audio/soundboard/orangetagn.ogg", -- OT's Anti-F SafeSpace
	[51] = "audio/soundboard/heyyeyeh.ogg", -- HEYYEYAAEYAAAEYAEYAA
	[52] = "audio/soundboard/rexxar.ogg", -- Cards duel.ogg
}

local function handleChannelSounds(client, event)
	local imoved = client.me == event.user
	local mychan = imoved and event.channel or client.me:getChannel()
	local cid = mychan:getID()

	local cnlsnd = channelsounds[cid]

	if imoved or (cnlsnd and event.channel == mychan) then
		local tp = type(cnlsnd)
		if tp == "table" then
			client:playOgg(cnlsnd[math.random(1,#cnlsnd)])
		elseif tp == "string" then
			client:playOgg(cnlsnd)
		end
	end
end

client:hook("OnUserConnected", "LuaBot - Channel Sounds [Connecting]", handleChannelSounds)
client:hook("OnUserChannel", "LuaBot - Channel Sounds [Channel]", handleChannelSounds)

--[[client:hook("OnUserChannel", "LuaBot - DND Alerts", function(client, event)
	if event.channel ~= client.me:getChannel() then return end

	local day = tonumber(os.date("%w"))
	local hour = tonumber(os.date("%H"))
	local minute = tonumber(os.date("%M"))

	if day == 2 then
		if hour == 18 then
			client.me:getChannel():message("%s is %d minutes early for DND", event.user:getName(), 59-minute)
		elseif hour == 19 then
			client.me:getChannel():message("%s is %d minutes late for DND", event.user:getName(), minute)
		end
	end
end)]]

client:hook("OnUserChannel", "LuaBot - OS Channels", function(client, event)
	local linux = client:getChannel("Linux")
	local windows = client:getChannel("Windows")

	if event.channel == linux or event.channel == windows then
		local os_version = event.user:getStats()["version"]["os_version"]

		if event.user == client.me then return end

		if (event.channel == linux and not string.find(os_version:lower(), "linux", 1, true)) or 
			(event.channel == windows and not string.find(os_version:lower(), "win", 1, true)) then
			event.user:move(event.user:getPreviousChannel())
		end
	end
end)

local function findMostPopularChannel()
	local party = client.me:getChannel()

	local root = client:getChannel()
	local afkchannel = client:getChannel(2) -- config.afk.channel[root:getName()] or "AFK"

	if not afkchannel then return end

	local partyusers, num_party = party:getUsers()
	if party == client.me:getChannel() then
		num_party = num_party - 1
	end

	for id, channel in pairs(table.ShuffleCopy(client:getChannels())) do
		local users, num_users = channel:getUsers()

		if channel == client.me:getChannel() then
			num_users = num_users - 1
		end

		if num_users > num_party and channel ~= client.me:getChannel() and channel ~= afkchannel then
			party = channel
		end
	end

	return party
end

client:hook("OnUserState", "Alone Checker", function(client, event)
	if not client:isSynced() then return end

	local users, num_users = client.me:getChannel():getUsers()
	
	if num_users <= 1 then
		local party = findMostPopularChannel()
		if party then
			client.me:move(party)
		end
	end
end)

client:hook("OnUserState", "Muted - AFK", function(client, event)
	if event.self_mute == nil or event.self_deaf == nil then return end

	local user = event.user
	local root = client:getChannelRoot():getName()
	local afk = client:getChannel(2) -- config.afk.channel[root:getName()] or "AFK"

	if user:getName():lower() == "davey" then
		afk = client:getChannel("Davis Speaks to the Preacher")
	end

	if event.self_mute == true and event.self_deaf == true then
		user:move(afk)
	elseif event.self_deaf == false and user:getPreviousChannel() ~= afk then
		user:move(user:getPreviousChannel())
	end
end)

client:hook("OnServerSync", function(client, me)
	--[[local channel = client:getChannel("DongerBots Chamber of sentience learning")
	me:move(channel)]]
	--me:setRecording(true)
	--me:setPrioritySpeaker(true)
	--client:playOgg("audio/melee.ogg")
end)

client:hook("OnTextMessage", "soundboard", function(client, event)
	local message = event.message
	local user = event.actor

	if message:sub(1,1) == "#" then
		local path = ("audio/soundboard/%s"):format(message:sub(2))
		local file = ("%s.ogg"):format(path)

		if lfs.attributes(path,"mode") == "directory" then
			local sounds = {}
			for file in lfs.dir(path) do
				if file ~= "." and file ~= ".." then
					table.insert(sounds, file)
				end
			end
			file = ("%s/%s"):format(path, sounds[math.random(1,#sounds)])
		end
		if lfs.attributes(file,"mode") == "file" then
			log.debug("%s played: #%s", user, message:sub(2))
			client:playOgg(file, user.session + 10)
			return true
		end
	end
end)

lua.install(client)
afk.install(client)

client:addCommand("youtube", function(client, user, cmd, args, raw)
	os.execute("cat ./youtube.pid | xargs kill -9")
	os.execute(string.format("./youtube.sh %s", args[1]))
end)

client:addCommand("stop", function(client, user, cmd, args, raw)
	os.execute("cat ./youtube.pid | xargs kill -9")
end)

client:addCommand("replay", function(client, user, cmd, args, raw)
	local f = io.open(("audio/replay/%s.rec"):format(user:getHash()), "rb")
	if not f then return end
	local size = f:seek("end")
	local time = client.audio_frames * 480 * 100 * 3
	local pos = math.max(0, size - time)
	f:seek("set", pos)
	client.recording_playback = f
end)

client:addCommand("summon", function(client, user, cmd, args, raw)
	print(client, user, client.me, user:getChannel())
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

	user:getChannel():message(string.format("<table><tr><td><b>Equation</b></td><td>: %s</td></tr><tr><td><b>Solution</b></td><td>: %s</td></tr></table>", equation:gsub("%%", "%%%%"), total))
end):setHelp("Calculate a mathematical expression"):setUsage("<expression>")

--[[local name_convert = {
	["Amer"] = "Sancho",
	["Aetsu"] = "Drak",
	["Bkacjios"] = "Bhord",
	["Paste"] = "Ranger Rick",
	["Will"] = "Hrangus",
	["NewDale"] = "Elph",
}]]

local name_convert = {
	["Amer"] = "Zaid",
	["Aetsu"] = "Torge",
	["Bkacjios"] = "Kilmos",
	["Paste"] = "Danger Rick",
	["Will"] = "Gug",
	["NewDale"] = "Alph",
	["Davey"] = "Coughertwo",
	["Henricos"] = "Gørf",
}

local card_suites = {
	"&spades;", -- Spades
	"&diams;",
	"&clubs;",
	"&hearts;", -- Hearts
}

local card_colors = {
	"%s",
	"<span style=\"color:#FF0000\">%s</span>",
	"%s",
	"<span style=\"color:#FF0000\">%s</span>",
}
local card_dim_colors = {
	"<span style=\"color:#797979\">%s</span>",
	"<span style=\"color:#ff4a4a\">%s</span>",
	"<span style=\"color:#797979\">%s</span>",
	"<span style=\"color:#ff4a4a\">%s</span>",
}

local card_values = {
	[1] = {1, 11},
	[2] = {2, 2},
	[3] = {3, 3},
	[4] = {4, 4},
	[5] = {5, 5},
	[6] = {6, 6},
	[7] = {7, 7},
	[8] = {8, 8},
	[9] = {9, 9},
	[10] = {10, 10},
	[11] = {10, 10},
	[12] = {10, 10},
	[13] = {10, 10},
}

local card_names = {
	[1] = "A",
	[2] = "2",
	[3] = "3",
	[4] = "4",
	[5] = "5",
	[6] = "6",
	[7] = "7",
	[8] = "8",
	[9] = "9",
	[10] = "10",
	[11] = "J",
	[12] = "Q",
	[13] = "K",
}

local blackjack_playing = {}

local function drawRandomCard(user)
	local username = user:getName()
	local number
	repeat
		number = math.random(1,52)
	until not blackjack_playing[username]["drawn"][number]
	blackjack_playing[username]["drawn"][number] = true
	local suit = (number % 4) + 1
	local value = (number % 13) + 1
	return { suit_id = suit, suit = card_suites[suit], value = card_values[value], name = card_names[value], id = number, bold = true }
end

local function getHandValues(user, index)
	local username = user:getName()
	local values = {0, 0}
	local player = blackjack_playing[username]
	local hand  = player[index]
	for k,card in pairs(hand) do
		values[1] = values[1] + card.value[1]
		values[2] = values[2] + card.value[2]
	end
	return values
end

local function hasBlackjack(user, index)
	local values = getHandValues(user, index)
	return values[2] == 21
end

local function getNiceValueString(values)
	local hand_value
	if values[1] == values[2] then
		hand_value = values[1]
	else
		hand_value = table.concat(values, '/')
	end
	return hand_value
end

local function getAllPlayersHands(user, stand)
	local username = user:getName()
	local name = name_convert[username] or username
	local player = blackjack_playing[username]
	local hand  = player["hand"]
	local house = player["house"]

	local message = "<p><table><tr><th>Player</th><th>Hand</th><th>Value</th></tr><tr><td>House</td><td><pre><b>"

	for k,card in pairs(house) do
		if not stand and k > 1 then
			message = message .. "[?&nbsp;?]"
		else
			if card.bold then
				card.bold = false
				message = message .. card_colors[card.suit_id]:format(('[%-2s%s]'):format(card.name, card.suit))
			else
				message = message .. card_dim_colors[card.suit_id]:format(('[%-2s%s]'):format(card.name, card.suit))
			end
		end
	end

	if not stand then
		message = message .. ("</b></pre></td><td>%s</td><tr><td>%s</td><td><pre><b>"):format(getNiceValueString(player.house[1].value), name)
	else
		message = message .. ("</b></pre></td><td>%s</td><tr><td>%s</td><td><pre><b>"):format(getNiceValueString(getHandValues(user, "house")), name)
	end

	for k,card in pairs(hand) do
		if card.bold then
			card.bold = false
			message = message .. card_colors[card.suit_id]:format(('[%-2s%s]'):format(card.name, card.suit))
		else
			message = message .. card_dim_colors[card.suit_id]:format(('[%-2s%s]'):format(card.name, card.suit))
		end
	end

	message = message .. ("</b></pre></td><td>%s</td></table>"):format(getNiceValueString(getHandValues(user, "hand")))
	return message
end

local function shouldHouseHit(user)
	local house_values = getHandValues(user, "house")
	return house_values[1] < 17 or house_values[2] < 17
end

local function doHouseHit(user)
	local username = user:getName()
	local house = blackjack_playing[username]["house"]
	table.insert(house, drawRandomCard(user))
end

local function doEndGame(user)
	while shouldHouseHit(user) do
		doHouseHit(user)
	end
end

client:addCommand("hit", function(client, user, cmd, args, raw)
	local username = user:getName()
	local name = name_convert[username] or username

	local player = blackjack_playing[username]

	if not player then
		local message = "<p><b><span style=\"color:#aa0000\">Error</span></b>: You aren't playing a game of <b>!blackjack</b>"
		user:message(message)
		return
	end

	table.insert(player["hand"], drawRandomCard(user))

	local message
	local hand_values = getHandValues(user, "hand")

	if hand_values[1] > 21 and hand_values[2] > 21 then
		doEndGame(user)

		message = getAllPlayersHands(user, true)

		local house_values = getHandValues(user, "house")
		if house_values[1] > 21 and house_values[2] > 21 then
			message = message .. "<p><b>House &amp; Player bust: <span style=\"color:#aa0000\">LOSS</span></b>"
		elseif house_values[1] > hand_values[1] then
			message = message .. "<p><b>House better hand: <span style=\"color:#aa0000\">LOSS</span></b>"
		else
			message = message .. "<p><b>Player bust: <span style=\"color:#aa0000\">LOSS</span></b>"
		end

		blackjack_playing[username] = nil
	else
		message = getAllPlayersHands(user)
	end

	user:getChannel():message(message)
end):setHelp("Hit in a game of blackjack")

client:addCommand("stand", function(client, user, cmd, args, raw)
	local username = user:getName()
	local name = name_convert[username] or username

	local player = blackjack_playing[username]
	if not player then
		local message = "<p><b><span style=\"color:#aa0000\">Error</span></b>: You aren't playing a game of <b>!blackjack</b>"
		user:message(message)
		return
	end

	doEndGame(user)

	local message = getAllPlayersHands(user, true)
	local hand_values = getHandValues(user, "hand")
	local house_values = getHandValues(user, "house")

	if house_values[1] > 21 and house_values[2] > 21 then
		message = message .. "<p><b>House bust: <span style=\"color:#00aa00\">WIN</span></b>"
	elseif house_values[1] == hand_values[1] then
		message = message .. "<p><b>House tied: <span style=\"color:#3377ff\">DRAW</span></b>"
	elseif house_values[1] > hand_values[1] then
		message = message .. "<p><b>House better hand: <span style=\"color:#aa0000\">LOSS</span></b>"
	elseif house_values[1] < hand_values[1] then
		message = message .. "<p><b>Player better hand: <span style=\"color:#00aa00\">WIN</span></b>"
	end

	blackjack_playing[username] = nil
	user:getChannel():message(message)
end):setHelp("Stand in a game of blackjack"):alias("stay"):alias("hold")

client:addCommand("blackjack", function(client, user, cmd, args, raw)
	local username = user:getName()
	local name = name_convert[username] or username
	if blackjack_playing[username] then
		local message = "<p><b><span style=\"color:#aa0000\">Error</span></b>: You're already playing a game of <i>!blackjack</i>,  please <b>!hit</b> or <b>!stay</b>"
		log.info(message:stripHTML())
		user:message(message)
		return
	else
		blackjack_playing[username] = { drawn = {}, hand = {}, house = {} }
	end

	local player = blackjack_playing[username]
	local hand  = player["hand"]
	local house = player["house"]

	table.insert(hand, drawRandomCard(user))
	table.insert(house, drawRandomCard(user))
	table.insert(hand, drawRandomCard(user))
	table.insert(house, drawRandomCard(user))

	local message

	if hasBlackjack(user, "hand") and hasBlackjack(user, "house") then
		message = getAllPlayersHands(user, true) .. "<p><b>House &amp; Player Blackjack: <span style=\"color:#3377ff\">DRAW</span></b>"
		blackjack_playing[username] = nil
	elseif hasBlackjack(user, "hand") then
		message = getAllPlayersHands(user, true) .. "<p><b>Player Blackjack: <span style=\"color:#00aa00\">WIN</span></b>"
		blackjack_playing[username] = nil
	elseif hasBlackjack(user, "house") then
		message = getAllPlayersHands(user, true) .. "<p><b>House Blackjack: <span style=\"color:#aa0000\">LOSS</span></b>"
		blackjack_playing[username] = nil
	else
		message = getAllPlayersHands(user)
	end

	user:getChannel():message(message)
end):setHelp("Start a game of blackjack")

local inititive = {
	["Sancho"] = 5,
	["Drak"] = 4,
	["Bhord"] = 1,
	["Danger Rick"] = 5,
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

		if name == "James" then
			--rolled_initiatives = {}
			--did_roll = {}
			user:getChannel():message(message)
		else
			user:message(message)
		end
		return
	elseif args[1] == "clear" then
		if name == "James" then
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
	--local bonus = (inititive[name] or 0)
	local bonus = tonumber(args[1]) or 0
	local message = string.format("<p><b>%s</b> rolled a <b><span style=\"color:#3377ff\">%d</span></b> (%d + %d) initiative", name, total + bonus, total, bonus)
	table.insert(rolled_initiatives, {name = name, roll = total, bonus = bonus})
	table.sort(rolled_initiatives, function(a, b) return a.roll + a.bonus > b.roll + b.bonus end)

	client:playOgg(("audio/dnd/dice_roll_1-%d.ogg"):format(math.random(1, 2)), 3)

	user:getChannel():message(message)
end):setHelp("Roll for initiative"):setUsage("[clear, list, initiative bonus]"):alias("init")

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
	"dis",
}

client:addCommand("roll", function(client, user, cmd, args, raw)
	local str = raw:lower():sub(#cmd+2)

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
	local max_roll = 0

	str = string.gsub(str, "(%d-)[Dd](%d+)", function(num, dice)
		num = tonumber(num) or 1
		dice = tonumber(dice)
		local results, total = math.roll(dice, num)
		rolls[dice] = rolls[dice] or {}
		num_rolls = num_rolls + num
		max_roll = max_roll + (dice * num)
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
	local highest = -math.huge
	local lowest = math.huge
	local average = 0

	local username = user:getName()
	local name = name_convert[username] or username

	local color = "#3377ff"
	if total == max_roll then
		color = "#00aa00"
	elseif total == num_rolls then
		color = "#aa0000"
	end

	local message = string.format("<p><b>%s</b> rolled <b><span style=\"color:#3377ff\">%s</span></b> and got <b><span style=\"color:%s\">%s</span></b>", name, orig_str:gsub("%s+", ""), color, total)

	if #stack > 2 then
		message = message .. "<table>"

		for dice, results in pairs(rolls) do
			local roll_list = ""
			for k, roll in pairs(results) do

				average = average + (roll/dice)

				if roll > highest then highest = roll end
				if roll < lowest then lowest = roll end

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

		message = message .. ("\n<tr><td><b>Average</b></td><td>: %s%%%%</td></tr>"):format(math.round(average/num_rolls*100, 2))
		message = message .. ("\n<tr><td><b>Equation</b></td><td>: %s</td></tr>"):format(equation:gsub("%%", "%%%%"))
		message = message .. ("\n<tr><td><b>Total</b></td><td>: <b><span style=\"color:%s\">%s</span></b></td></tr>"):format(color, total)

		message = message .. "</table>"
	end

	log.info(message:stripHTML())

	if cmd:sub(2) == "proll" then
		user:message(message)
	else
		local sound_num = math.min(num_rolls, 6)
		local rand = math.random(1, 2)
		client:playOgg(("audio/dnd/dice_roll_%d-%d.ogg"):format(sound_num, rand), 3)
		user:getChannel():message(message)
	end
end):setHelp("Roll some dice"):setUsage("[1D20 [, expression]]"):alias("proll"):alias("rtd"):alias("rol"):alias("rool"):alias("rrol"):alias("rroll"):alias("rl"):alias("tol"):alias("yol")

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
		message = ("<p><b>%s</b> flipped <i>%d coins</i> and got <b><span style=\"color:#3377ff\">%d heads</span></b> and <b><span style=\"color:#3377ff\">%d tails</span></b>"):format(name, #results, num_heads, num_tails)
	else
		message = ("<p><b>%s</b> flipped a coin and got <b><span style=\"color:#3377ff\">%s</span></b>"):format(name, results[1])
	end

	log.info(message:stripHTML())

	if cmd:sub(2) == "pflip" then
		user:message(message)
	else
		client:playOgg(("audio/dnd/coin_flip-%d.ogg"):format(math.random(1,2)), 4)
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

	client:playOgg(("audio/dnd/dice_roll_4-%d.ogg"):format(math.random(1, 2)), 3)
	user:getChannel():message("<p><b>%s</b>, here are your stats to choose from: <b><span style=\"color:#3377ff\">%s</span></b>", user:getName(), table.concat(stats, ", "))
end):setHelp("Rolls 4D6 and takes the highest 3 values, 6 times")

local snapped = {}

client:addCommand("snap", function(client, user, cmd, args)
	local message = "<p>Thanos snapped and.."

	local channel = user:getChannel()

	if args[1] == "reset" then
		snapped = {}
		return
	end

	for session, user in pairs(channel:getUsers()) do
		local name = user:getName()
		if snapped[name] == nil then
			snapped[name] = math.random() > 0.5
		end

		if snapped[name] then
			message = message .. "<br><b>" .. name .. "</b>"
		end
	end

	channel:message(message .. "<br> were killed")
end):setHelp("thanos snap")

local function printIdleChannelTree(branch)
	local message = ""

	local users, usern = branch:getUsers()
	if usern > 0 then
		message = message .. ("\n<tr><th colspan='2'>%s</th></tr>"):format(branch:getURL())
		for k, user in UserPairs(users) do
			message = message .. ("\n<tr><td>%s</b></td><td>: %s</td></tr>"):format(user:getURL(), math.SecondsToHuman(user.stats.idlesecs or 0))
		end
	end

	for id, channel in ChannelPairs(branch:getChildren()) do
		message = message .. printIdleChannelTree(channel)
	end

	return message
end

client:addCommand("idle", function(client, user, cmd, args, raw, public)
	local message = "<table>" .. printIdleChannelTree(client:getChannelRoot(), message) .. "</table>"
	if public then
		user:getChannel():message(message)
	else
		user:message(message)
	end
end):setHelp("Print everyones idle statistics")

client:addCommand("help", function(client, user, cmd, args, raw)
	local message = "<table><tr><th>command</th><th>arguments</th><th>help</th></tr>"

	local commands = {}

	for cmd,info in pairs(client:getCommands()) do
		table.insert(commands, info)
	end

	table.sort(commands, function(a, b)
		return (a.cmd < b.cmd) or (a.cmd == b.cmd and a.name < b.name)
	end)

	local show_all = args[1] == "all" or args[2] == "all"
	local show_user = args[1] == "user" or args[2] == "user"

	for k, info in pairs(commands) do
		if ((info.master and (not show_user and user:isMaster())) or not info.master) and not info.aliased then
			message = message .. ("<tr><td><b>%s%s</b></td><td>%s</td><td>%s</td></tr>"):format(cmd[1], info.name, info.usage:escapeHTML(), info.help:escapeHTML())
			
			if show_all then
				for k, sinfo in pairs(commands) do
					if sinfo.cmd == info.cmd and sinfo.aliased then
						message = message .. ("<tr><td><i>&nbsp;%s%s</i></td><td>%s</td><td>%s</td></tr>"):format(cmd[1], sinfo.name, sinfo.usage:escapeHTML(), sinfo.help:escapeHTML())
					end
				end
			end
		end
	end
	user:message(message .. "</table>")
end):setHelp("List all commands"):alias("commands"):alias("?")

client:addCommand("kickme", function(client, user, cmd, args, raw)
	user:kick(args[1] or "Bye bye!")
end):setHelp("Kick yourself from the server"):setUsage("[reason]")

client:addCommand("source", function(client, user, cmd, args, raw)
	local command = client:getCommand(args[1])
	if command then
		local info = debug.getinfo(command.callback)
		local f, err = io.open(info.short_src, "r")
		local source = f:readLines(info.linedefined, info.lastlinedefined)
		local fixed = source:gsub("%%", "%%%%"):escapeHTML():gsub("\r", "<br/>"):gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		user:message("<p>" .. fixed .. "</p>")
	end
end):setHelp("See the source code of a command"):setUsage("<command name>"):alias("src")

client:addCommand("about", function(client, user, cmd, args, raw)
	local message = [[<p><b>Lumble</b>
Created by <a href="https://github.com/bkacjios">Bkacjios</a> &amp; <a href="https://github.com/Someguynamedpie">Somepotato</a><br/>
<a href="https://github.com/bkacjios/Lumble">https://github.com/bkacjios/Lumble</a>]]
	user:message(message)
end, "Get some information about LuaBot")

client:addCommand("play", function(client, user, cmd, args, raw)
	client:playOgg(("audio/%s.ogg"):format(args[1]), tonumber(args[2]), nil, tonumber(args[3]))
end):setHelp("Play an audio file"):setUsage("<file> [channel] [count]")

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
		user:move(event.channel_prev)
	end
end)

client:addCommand("volume", function(client, user, cmd, args, raw)
	local volume = args[1]
	local channel = tonumber(args[2])
	if volume then
		volume = tonumber(volume)/100
		if not user:isMaster() then volume = math.min(volume,1) end
		if channel then
			client:setVolume(volume, channel)
			log.debug(("[COMMAND] %s: changed the volume of channel %i to %i"):format(user:getName(), channel, volume*100))
		else
			client:setMasterVolume(volume)
			log.debug(("[COMMAND] %s: changed the master volume to %i"):format(user:getName(), volume*100))
		end
	else
		if channel then
			user:message(("Volume: <b>%i</b>"):format(client:getVolume(channel)*100))
		else
			user:message(("Master volume: <b>%i</b>"):format(client:getMasterVolume()*100))
		end
	end
end):setHelp("Set the volume of any playing audio"):setUsage("<volume> [channel]")

local DND_CHAN_MUSIC = 1
local DND_CHAN_AMBIENCE = 2

local playlist = {}
local track = { 0, 0 }

local function playPlaylist(client, channel)
	if not playlist[channel] then return end

	if track[channel] >= #playlist[channel] then
		track[channel] = 0
	end
	track[channel] = track[channel] + 1

	if playlist[channel][track[channel]] then
		client:playOgg(playlist[channel][track[channel]], channel, 0.35)
	end
end

client:hook("AudioStreamFinish", playPlaylist)

client:addCommand("dnd", function(client, user, cmd, args, raw)
	local folder = cmd:sub(2) == "ambience" and "ambience" or "music"
	local channel = cmd:sub(2) == "ambience" and DND_CHAN_AMBIENCE or DND_CHAN_MUSIC

	playlist[channel] = {}

	local path = ("audio/dnd/%s/%s/"):format(folder, args[1])

	if args[1] == "none" or args[1] == "silence" then
		if client:isPlaying(channel) then
			client:getPlaying(channel):fadeOut(5)
		end
		return
	end

	if lfs.attributes(path,"mode") ~= "directory" then
		local moods = {}

		for file in lfs.dir("audio/dnd/" .. folder) do
			if lfs.attributes("audio/dnd/" .. folder .. "/" .. file, "mode") == "directory" and file ~= "." and file ~= ".." then
				table.insert(moods, file)
			end
		end

		user:message("<i>Invalid mode</i>: %s<br/><b>Available Modes</b><br/>%s", args[1], table.concat(moods, "<br/>"))
		return
	end

	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." and lfs.attributes(path .. file, "mode") == "file" and string.ExtensionFromFile(file) == "ogg" then
			table.insert(playlist[channel], path .. file)
		end
	end

	table.Shuffle(playlist[channel])

	if client:isPlaying(channel) then
		client:getPlaying(channel):fadeOut(3)
	else
		track[channel] = 0
		playPlaylist(client, channel)
	end
end):setHelp("Set the mood for D&D"):setUsage("<mood>"):alias("mood"):alias("music"):alias("ambience")

client:addCommand("fade", function(client, user, cmd, args, raw)
	local channel = tonumber(args[1]) or 1
	if client:isPlaying(channel) then
		client:getPlaying(channel):fadeOut(tonumber(args[2]) or 5)
	end
end):setHelp("Fade out the current audio"):setUsage("[channel] [duration]")

client:addCommand("endsession", function(client, user, cmd, args, raw)
	local channel = client.me:getChannel()

	playlist[DND_CHAN_MUSIC] = {}
	playlist[DND_CHAN_AMBIENCE] = {}

	if client:isPlaying(DND_CHAN_MUSIC) then
		client:getPlaying(DND_CHAN_MUSIC):fadeOut(5)
	end
	if client:isPlaying(DND_CHAN_AMBIENCE) then
		client:getPlaying(DND_CHAN_AMBIENCE):fadeOut(5)
	end

	if channel:getID() == 24 then
		for session, user in pairs(channel:getUsers()) do
			user:move("../")
		end
	end
end):setHelp("End the D&D session")

client:addCommand("afk", function(client, user, cmd, args, raw)
	local root = client:getChannelRoot():getName()

	local afkchannel = client:getChannel(config.afk.channel[root] or "AFK")

	if not afkchannel or user:getChannel() == afkchannel then return end

	user:move(afkchannel)
end):setHelp("Make the bot move you to the AFK channel")

client:addCommand("tts", function(client, user, cmd, args, raw)
	local str = raw:sub(#cmd+2)
	os.execute(string.format("LD_LIBRARY_PATH=:/usr/local/lib ./say_linux -w tts.wav %q", "[:phone on]" .. str)) -- > /dev/null
	os.execute(("oggenc --resample 48000 --quiet -o tts/%s.ogg tts.wav"):format(user.hash))
	client:playOgg(("tts/%s.ogg"):format(user.hash), user.session + 100)
end)

local json = require("json")
local https = require("ssl.https")

local function getDuration(stamp)
	local hours = string.match(stamp, "(%d+)H") or 0
	local minutes = string.match(stamp, "(%d+)M") or 0
	local seconds = string.match(stamp, "(%d+)S") or 0

	if tonumber(hours) > 0 then
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
			["Accept"] = "application/vnd.twitchtv.v5+json"
		},
	})

	r = table.concat(t, "")
	return r, c, h
end

local function formatTwitchClip(id)
	local req = twitchHttps(("https://api.twitch.tv/helix/clips?id=%s"):format(id))
	if not req then return end
	if( #req == 0 ) then return end

	local js = json.decode(req)

	local items = js.data[1]

	if not items then return "Private or invalid Twitch.tv Clip." end

	return [[
<center><table>
	<tr>
		<td align="center">
			<a href="%s"><img src="%s" width="250" /></a>
		</td>
	</tr>
	<tr>
		<td align="center" valign="middle">
			<h4>%s</h4>
		</td>
	</tr>
</table></center>
]], items.url, items.thumbnail_url, items.title
end

local function formatTwitch(id)
	local user = twitchHttps(("https://api.twitch.tv/kraken/users?login=%s"):format(id))
	if not user or #user == 0 then return end

	user = json.decode(user)

	if user.error then return user.error end

	if user._total ~= 1 then return end

	user = user.users[1]

	local stream = twitchHttps(("https://api.twitch.tv/kraken/streams/%d"):format(user._id))
	if not stream or #stream == 0 then return end

	stream = json.decode(stream)

	if stream.error then return stream.error end

	stream = stream.stream

	if not stream then return "Invalid twitch.tv stream." end

	--[[return [[
<table>
	<tr>
		<th align="center" colspan="2"><a href="%s"><img src="%s" width="250" /></a></th>
	</tr>
	<tr>
		<td><img src="%s" width="56"/></td>
		<td>
			<table>
				<tr><td><h4>%s</h4></td></tr>
				<tr><td>%s</td></tr>
				<tr><td>%d viewers</td></tr>
			</table>
		</td>
	</tr>
</table>]]

	return [[
		<table>
			<tr><td><a href="%s">%s</a> - %s</td></tr>
			<tr><td><h4>%s</h4></td></tr>
			<tr><td>%d viewers</td></tr>
		</table>
	]], stream.channel.url, stream.channel.display_name, stream.channel.game, stream.channel.status, stream.viewers
end

local function formatYoutube(id)
	local req = https.request(("https://www.googleapis.com/youtube/v3/videos?key=%s&part=statistics,snippet,contentDetails&id=%s"):format(config.youtube.api, id))
	if not req then return end
	if( #req == 0 ) then return end

	local js = json.decode(req)

	local items = js.items[1]

	if not items then return "Private or invalid YouTube video." end

	return [[
<table>
	<tr>
		<td align="center"><a href="http://youtu.be/%s"><img src="%s" width="250" /></a></td>
	</tr>
	<tr>
		<td align="center" valign="middle"><h4>%s (%s)</h4></td>
	</tr>
</table>
]], id, items.snippet.thumbnails.medium.url, items.snippet.title, getDuration(items.contentDetails.duration)
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
	local twitchclip = message:match("clips.twitch.tv/(%w+)")
	local twitch = message:match("twitch.tv/(%w+)")
	--local other = message:match("(https?://[%w%p]+)")

	--[[if youtube then
		user:getChannel():message(formatYoutube(youtube))
	elseif twitchclip then
		user:getChannel():message(formatTwitchClip(twitch))
	elseif twitch then
		user:getChannel():message(formatTwitch(twitch))
	end]]
	--[[if other then
		local ext = string.ExtensionFromFile(other):lower()
		if valid_others[ext] then
			user:getChannel():message(formatOther(other))
		end
	end]]
end)