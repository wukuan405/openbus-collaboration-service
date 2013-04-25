#ifndef EXTRALIBRARIES_H
#define EXTRALIBRARIES_H

#include "lua.h"

extern char const* OPENBUS_MAIN;
extern char const* OPENBUS_PROGNAME;

void luapreload_extralibraries(lua_State*);

#endif
