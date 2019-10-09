function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local ocbaes128 = require("ocb.aes128")

local c = ocbaes128.new()

--c:genKey()

c:setKey(string.fromhex("D310DA8A4CC20E1C83723621F52762F7"), string.fromhex("715F4873F0F5F00288B2D6DBE5F5BEBA"), string.fromhex("C545531A6B1367F176E3BA58B02E6311"))

c:decrypt(c:encrypt("I don't even know anymore"))