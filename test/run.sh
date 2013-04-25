#!/bin/bash

openbusTestLuaPath="$HOME/puts/build/openbus-lua-2.0.0.0/test/?.lua"
lsqlite3LuaCPath="$HOME/build/lsqlite3_svn08/?.so"
console=$HOME/puts/install/bin/busconsole

LUA_PATH="?.lua;../lua/?.lua;$openbusTestLuaPath"
LUA_CPATH="$lsqlite3LuaCPath"

cases="interface persistence observer"

for case in $cases
do
  LUA_PATH=$LUA_PATH LUA_CPATH=$LUA_CPATH $console $case.lua
done
