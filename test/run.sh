#!/bin/bash

collaboration_service_pkg="collaboration-service-1.0.0.2"
openbus_lua_pkg="openbus-lua-2.0.0.1"

puts_install="${PUTS}/install"
puts_build="${PUTS}/build"
console=${puts_install}/bin/busconsole
collaboration_service=${puts_build}/${collaboration_service_pkg}
openbus_lua=${puts_build}/${openbus_lua_pkg}
lua_path="?.lua;${openbus_lua}/test/?.lua;"\
"${collaboration_service}/lua/?.lua;${collaboration_service}/dist/?.lua"
lua_cpath="${puts_install}/lib/lib?.so;${puts_install}/lib/lib?.dylib"

cases="interface persistence observer oninvalid_login"

for case in $cases
do
  LUA_PATH=$lua_path LUA_CPATH=$lua_cpath $console $case.lua
done
