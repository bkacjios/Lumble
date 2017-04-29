--[[
	All user specific settings use the hash of a users
	authentication certificate to prevent spoofing.

	- Use the command !hash to find a users hash via the SuperUser.
	- Disable SuperUser access by setting it to nil or false.
]]

return {
	-- A username that can initialy control the bot.
	-- Set to false or nil after setting up the masters list as it is unsecure.
	-- This is perfectly fine to leave as-is if you own the server
	-- in which the bot will reside in. This will just mean that
	-- the mumble-server's "SuperUser" will also have control over the bot.
	superuser = "SuperUser",

	-- What the bot will call its masters
	mastername = "senpai",

	-- Users who have advanced command access
	masters = {
		["b304c9259eca9d38abb8cebd242b4609be2f972e"] = true,	-- Bkacjios
		["64f59879ea4e10658fd01a0592c7d6ebbf20a443"] = true,	-- Orange-Tang
		["4109b0315ce639056869be0f041cf3aa53e39275"] = true,	-- Atsu
	},

	-- The default channel for the bot
	home = "DongerBots Chamber of sentience learning",

	afk = {
		-- Check every second
		checktime = 1,

		-- Number of minutes before the movetime a user will be warned
		warning = 10,

		-- Number of minutes before declaring a user AFK
		movetime = 120,

		-- Message to send users
		warningmessage = "You have been idle for %s..</br>You will be moved to <i>%s</i> in %s!",

		-- Channel to move idle users to
		channel = {
			["Raspberry Pi"] = "AFK",
			["THIRD MUMBLE TIME"] = "Wee Willy Winkys Magical Bed of Sleep Town",
		}
	}
}