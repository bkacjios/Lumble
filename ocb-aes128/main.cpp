#include "lua.hpp"

#include "CryptState.h"

#include <string.h>
#include <iostream>

#define LUA_OCB_AES128 "AES128"

// Create & return CryptState instance to Lua
static int ocb_aes128_new(lua_State* L) {
	*reinterpret_cast<CryptState**>(lua_newuserdata(L, sizeof(CryptState*))) = new CryptState();
	luaL_setmetatable(L, LUA_OCB_AES128);
	return 1;
}

// Free MyObject instance by Lua garbage collection
static int ocb_aes128_delete(lua_State* L) {
	//delete *reinterpret_cast<CryptState**>(lua_touserdata(L, 1));
	return 0;
}

static int ocb_aes128_isValid(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	crypeState->isValid();
	return 1;
}

static int ocb_aes128_genKey(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	crypeState->genKey();
	return 0;
}

static int ocb_aes128_setKey(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));

	std::string rkey(luaL_checkstring(L, 2));
	std::string eiv(luaL_checkstring(L, 3));
	std::string div(luaL_checkstring(L, 4));

	lua_pushboolean(L, crypeState->setKey(rkey, eiv, div));
	return 1;
}

static int ocb_aes128_setRawKey(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	std::string raw_key(luaL_checkstring(L, 2));
	lua_pushboolean(L, crypeState->setRawKey(raw_key));
	return 1;
}

static int ocb_aes128_setEncryptIV(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	std::string iv(luaL_checkstring(L, 2));
	lua_pushboolean(L, crypeState->setEncryptIV(iv));
	return 1;
}

static int ocb_aes128_setDecryptIV(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	std::string iv(luaL_checkstring(L, 2));
	lua_pushboolean(L, crypeState->setDecryptIV(iv));
	return 1;
}

static int ocb_aes128_getRawKey(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	std::string raw_key = crypeState->getRawKey();
	lua_pushlstring(L, (const char*) raw_key.c_str(), raw_key.length());
	return 1;
}

static int ocb_aes128_getEncryptIV(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	std::string encrypt_iv = crypeState->getEncryptIV();
	lua_pushlstring(L, (const char*) encrypt_iv.c_str(), encrypt_iv.length());
	return 1;
}

static int ocb_aes128_getDecryptIV(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));
	std::string decrypt_iv = crypeState->getDecryptIV();
	lua_pushlstring(L, (const char*) decrypt_iv.c_str(), decrypt_iv.length());
	return 1;
}

static int ocb_aes128_getGood(lua_State* L) {
	lua_pushinteger(L, (*reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128)))->getGood());
	return 1;
}

static int ocb_aes128_getLate(lua_State* L) {
	lua_pushinteger(L, (*reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128)))->getLate());
	return 1;
}

static int ocb_aes128_getLost(lua_State* L) {
	lua_pushinteger(L, (*reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128)))->getLost());
	return 1;
}

static int ocb_aes128_encrypt(lua_State* L) {
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));

	size_t size;
	const unsigned char* plaintext = reinterpret_cast<const unsigned char *>(luaL_checklstring(L, 2, &size));

	unsigned char* encrypted = new unsigned char[size + 4];
	memset(encrypted, 0, size + 4);

	bool succ = crypeState->encrypt(plaintext, encrypted, size);

	lua_pushboolean(L, succ);

	if (succ)
		lua_pushlstring(L, (const char*) encrypted, size + 4);
	else
		lua_pushnil(L);

	delete encrypted;
	return 2;
}

static int ocb_aes128_decrypt(lua_State* L){
	CryptState* crypeState = *reinterpret_cast<CryptState**>(luaL_checkudata(L, 1, LUA_OCB_AES128));

	size_t size;
	const unsigned char* encrypted = reinterpret_cast<const unsigned char *>(luaL_checklstring(L, 2, &size));

	unsigned char* plaintext = new unsigned char[size - 4];
	memset(plaintext, 0, size - 4);

	bool succ = crypeState->decrypt(encrypted, plaintext, size);

	lua_pushboolean(L, succ);

	if (succ)
		lua_pushlstring(L, (const char*) plaintext, size - 4);
	else
		lua_pushnil(L);

	delete plaintext;
	return 2;
}

const luaL_Reg osb_table[] = {
	{"new", ocb_aes128_new},
	{NULL, NULL}
};

const luaL_Reg ocb_aes128[] = {
	{"__gc", ocb_aes128_delete},
	{"isValid", ocb_aes128_isValid},
	{"genKey", ocb_aes128_genKey},
	{"setKey", ocb_aes128_setKey},
	{"setRawKey", ocb_aes128_setRawKey},
	{"setEncryptIV", ocb_aes128_setEncryptIV},
	{"setDecryptIV", ocb_aes128_setDecryptIV},
	{"getRawKey", ocb_aes128_getRawKey},
	{"getEncryptIV", ocb_aes128_getEncryptIV},
	{"getDecryptIV", ocb_aes128_getDecryptIV},
	{"getGood", ocb_aes128_getGood},
	{"getLate", ocb_aes128_getLate},
	{"getLost", ocb_aes128_getLost},
	{"encrypt", ocb_aes128_encrypt},
	{"decrypt", ocb_aes128_decrypt},
	{NULL, NULL}
};

extern "C" int luaopen_ocb_aes128(lua_State *L) {

	luaL_register(L, "ocb", osb_table);
	{
		// Register client metatable
		luaL_newmetatable(L, LUA_OCB_AES128);
		{
			lua_pushvalue(L, -1);
			lua_setfield(L, -2, "__index");
		}
		luaL_register(L, NULL, ocb_aes128);
		lua_setfield(L, -2, LUA_OCB_AES128);

		lua_pushinteger(L, AES_KEY_SIZE_BITS); lua_setfield(L, -2, "AES_KEY_SIZE_BITS");
		lua_pushinteger(L, AES_KEY_SIZE_BYTES); lua_setfield(L, -2, "AES_KEY_SIZE_BYTES");
		lua_pushinteger(L, AES_BLOCK_SIZE); lua_setfield(L, -2, "AES_BLOCK_SIZE");
	}

	return 1;
}
