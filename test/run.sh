#!/bin/bash

putsInstall="$HOME/puts/install"
putsBuild="$HOME/puts/build"
console=$putsInstall/bin/busconsole
openbusTestLuaPath="$putsBuild/openbus-lua-2.0.0.0/test/?.lua"

LUA_PATH="?.lua;../lua/?.lua;$openbusTestLuaPath"
LUA_CPATH="$putsInstall/lib/lib?.so"

cases="interface persistence observer"

for case in $cases
do
  LUA_PATH=$LUA_PATH LUA_CPATH=$LUA_CPATH $console $case.lua
done
