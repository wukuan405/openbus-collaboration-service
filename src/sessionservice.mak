PROJNAME= sessionservice
APPNAME= $(PROJNAME)

OPENBUSIDL= ${OPENBUS_HOME}/idl/v2_00
OPENBUSINC= ${OPENBUS_HOME}/include
OPENBUSLIB= ${OPENBUS_HOME}/lib

SRC= \
	launcher.c \
	sessionservlibs.c \
	$(PRELOAD_DIR)/$(APPNAME).c

LUADIR= ../lua
LUASRC= \
	$(LUADIR)/openbus/services/session/idl/parsed.lua \
	$(LUADIR)/openbus/services/session/idl.lua \
	$(LUADIR)/openbus/services/session/main.lua \
	$(LUADIR)/openbus/services/session/messages.lua \
	$(LUADIR)/openbus/services/session/SessionRegistry.lua

IDLDIR= ../idl
IDL= $(IDLDIR)/session.idl

include ${OIL_HOME}/openbus/base.mak

LIBS= \
	dl crypto \
	lua5.1 luuid lce lfs luavararg luastruct luasocket \
	loop luatuple luacoroutine luacothread luainspector luaidl oil luascs \
	luaopenbus

DEFINES= \
	TECMAKE_APPNAME=\"$(APPNAME)\"

INCLUDES+= . $(SRCLUADIR) \
	$(OPENBUSINC)/luuid \
	$(OPENBUSINC)/lce \
	$(OPENBUSINC)/luafilesystem \
	$(OPENBUSINC)/luavararg \
	$(OPENBUSINC)/luastruct \
	$(OPENBUSINC)/luasocket2 \
	$(OPENBUSINC)/loop \
	$(OPENBUSINC)/oil \
	$(OPENBUSINC)/scs/lua \
	$(OPENBUSINC)/openbus/lua
LDIR+= $(OPENBUSLIB)

ifneq "$(TEC_SYSNAME)" "Darwin"
	LIBS += uuid
endif
ifeq "$(TEC_SYSNAME)" "Linux"
	LFLAGS = -Wl,-E
endif
ifeq "$(TEC_SYSNAME)" "SunOS"
	USE_CC=Yes
	CFLAGS= -g -KPIC -mt -D_REENTRANT
	ifeq ($(TEC_WORDSIZE), TEC_64)
		CFLAGS+= -m64
	endif
	LFLAGS= $(CFLAGS) -xildoff
	LIBS += rt
endif

$(LUADIR)/openbus/services/session/idl/parsed.lua: $(IDL2LUA) $(IDL)
	$(OILBIN) $(IDL2LUA) -I $(OPENBUSIDL) -o $@ $(IDL)

$(PRELOAD_DIR)/$(APPNAME).c $(PRELOAD_DIR)/$(APPNAME).h: $(LUAPRELOADER) $(LUASRC)
	$(LOOPBIN) $(LUAPRELOADER) -l "$(LUADIR)/?.lua" \
	                           -d $(PRELOAD_DIR) \
	                           -h $(APPNAME).h \
	                           -o $(APPNAME).c \
	                           $(LUASRC)

sessionservlibs.c: $(PRELOAD_DIR)/$(APPNAME).h
