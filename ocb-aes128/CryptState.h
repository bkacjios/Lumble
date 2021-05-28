/* Copyright (C) 2005-2010, Thorvald Natvig <thorvald@natvig.com>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef _CRYPTSTATE_H
#define _CRYPTSTATE_H

#include <openssl/aes.h>
#include <string>

#define AES_KEY_SIZE_BITS   128
#define AES_KEY_SIZE_BYTES  (AES_KEY_SIZE_BITS/8)

class CryptState {
	private:
		unsigned char raw_key[AES_KEY_SIZE_BYTES];
		unsigned char encrypt_iv[AES_BLOCK_SIZE];
		unsigned char decrypt_iv[AES_BLOCK_SIZE];
		unsigned char decrypt_history[0x100];

		unsigned int uiGood;
		unsigned int uiLate;
		unsigned int uiLost;
		unsigned int uiResync;

		AES_KEY encrypt_key;
		AES_KEY decrypt_key;
		bool bInit;

	public:
		CryptState();

		bool isValid() const;
		void genKey();
		bool setKey(const std::string &rkey, const std::string &eiv, const std::string &div);
		bool setRawKey(const std::string &rkey);
		bool setEncryptIV(const std::string &iv);
		bool setDecryptIV(const std::string &iv);

		std::string getRawKey();
		std::string getEncryptIV();
		std::string getDecryptIV();

		unsigned int getGood();
		unsigned int getLate();
		unsigned int getLost();

		bool ocb_encrypt(const unsigned char* plain, unsigned char* encrypted, unsigned int len, const unsigned char* nonce, unsigned char* tag, bool modifyPlainOnXEXStarAttack = true);
		bool ocb_decrypt(const unsigned char* encrypted, unsigned char* plain, unsigned int len, const unsigned char* nonce, unsigned char* tag);

		bool decrypt(const unsigned char* source, unsigned char* dst, unsigned int crypted_length);
		bool encrypt(const unsigned char* source, unsigned char* dst, unsigned int plain_length);
};


#endif