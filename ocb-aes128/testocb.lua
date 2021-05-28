function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local ocbaes128 = require("ocb.aes128")

local server = ocbaes128.new()
local client = ocbaes128.new()

-- "Send" keys to the client
server:genKey()
assert(client:setKey(server:getRawKey(), server:getDecryptIV(), server:getEncryptIV()), "CryptState: Cipher resync failed: Invalid key/nonce from the server")

assert(server:isValid(), "server cryptstate invalid")
assert(client:isValid(), "client cryptstate invalid")

local TEST_MESSAGE = "Hello world!"

print("TESTING CLEINT -> SERVER")

local succ, encrypted = client:encrypt(TEST_MESSAGE)

assert(succ, "failed to encrypt data")
print(string.format("string: %q\nencrypted: %q", TEST_MESSAGE, string.tohex(encrypted)))

local succ, decrypted = server:decrypt(encrypted)

assert(succ, "failed to decrypt data")
print(string.format("decrypted: %q", decrypted))

assert(decrypted == TEST_MESSAGE, "failed to decrypt data encrypted by client")

print("TESTING SERVER -> CLIENT")

local succ, encrypted = server:encrypt(TEST_MESSAGE)

assert(succ, "failed to encrypt data")
print(string.format("string: %q\nencrypted: %q", TEST_MESSAGE, string.tohex(encrypted)))

local succ, decrypted = client:decrypt(encrypted)

assert(succ, "failed to decrypt data")
print(string.format("decrypted: %q", decrypted))

assert(decrypted == TEST_MESSAGE, "failed to decrypt data encrypted by server")

print("SERVER")
print("\tGood:", server:getGood())
print("\tLate:", server:getLate())
print("\tLost:", server:getLost())

print("CLIENT")
print("\tGood:", client:getGood())
print("\tLate:", client:getLate())
print("\tLost:", client:getLost())

print("PASSED")