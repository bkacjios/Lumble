# !/bin/sh

g++ -fPIC -c CryptState.cpp
g++ -fPIC -c main.cpp -I/usr/local/include/luajit-2.1 -o ocb.o
g++ -shared -o ocb.so ocb.o CryptState.o -lssl -lcrypto