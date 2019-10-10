local bit = require("bit")

local permission = {
	type = {
		Text = 0,
		Permission = 1,
		SuperUser = 2,
		ChannelName = 3,
		TextTooLong = 4,
		H9K = 5,
		TemporaryChannel = 6,
		MissingCertificate = 7,
		UserName = 8,
		ChannelFull = 9,
		NestingLimit = 10,
		ChannelLimit = 11,
	},
	type_name = {
		[0] = "Text",
		[1] = "Permission",
		[2] = "SuperUser",
		[3] = "ChannelName",
		[4] = "TextTooLong",
		[5] = "H9K",
		[6] = "TemporaryChannel",
		[7] = "MissingCertificate",
		[8] = "UserName",
		[9] = "ChannelFull",
		[10] = "NestingLimit",
		[11] = "ChannelLimit",
	},
	enum = {
		NONE = 0x0,
		WRITE = 0x1,
		TRAVERSE = 0x2,
		ENTER = 0x4,
		SPEAK = 0x8,
		MUTE_DEAFEN = 0x10,
		MOVE = 0x20,
		MAKE_CHANNEL = 0x40,
		LINK_CHANNEL = 0x80,
		WHISPER = 0x100,
		TEXT_MESSAGE = 0x200,
		MAKE_TEMP_CHANNEL = 0x400,

		-- Root channel only
		KICK = 0x10000,
		BAN = 0x20000,
		REGISTER = 0x40000,
		SELF_REGISTER = 0x80000,

		CACHED = 0x8000000,
		ALL = 0xf07ff,
	},
	enum_name = {
		[0x0] = "None",
		[0x1] = "Write",
		[0x2] = "Traverse",
		[0x4] = "Enter",
		[0x8] = "Speak",
		[0x10] = "Mute/Deafen",
		[0x20] = "Move",
		[0x40] = "Make Channel",
		[0x80] = "Link Channel",
		[0x100] = "Whisper",
		[0x200] = "Text Message",
		[0x400] = "Make Temp Channel",
		[0x10000] = "Kick",
		[0x20000] = "Ban",
		[0x40000] = "Register",
		[0x80000] = "Self Register",
		[0xf07ff] = "All",
	}
}

function permission.getName(id)
	return permission.enum_name[id] or "Unknown"
end

function permission.getType(id)
	return permission.type_name[id] or "NONE"
end

function permission.getDefaults()
	local enum = permission.enum
	return enum.TRAVERSE + enum.ENTER + enum.SPEAK + enum.WHISPER + enum.TEXT_MESSAGE
end

return permission