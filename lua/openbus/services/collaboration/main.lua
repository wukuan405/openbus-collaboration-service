-- $Id$
-- -*- coding: iso-8859-1-unix -*-

local _G = require "_G"
local assert = _G.assert
local select = _G.select

local io = require "io"
local stderr = io.stderr

local os = require "os"
local getenv = os.getenv

local oil = require "oil"
local oillog = require "oil.verbose"

local log = require "openbus.util.logger"
local database = require "openbus.util.database"
local opendb = database.open
local server = require "openbus.util.server"
local ConfigArgs = server.ConfigArgs
local newSCS = server.newSCS
local setuplog = server.setuplog
local readprivatekey = server.readprivatekey

local openbus = require "openbus"

local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local CollaborationServiceName = idl.const.CollaborationServiceName
local loadidl = idl.loadto
local CollaborationRegistry = require "openbus.services.collaboration.CollaborationRegistry"

return function(...)
	-- configuration parameters parser
	local Configs = ConfigArgs{
		host = "*",
		port = 2090,
		
		bushost = "localhost",
		busport = 2089,
	
		database = "collab.db",
		privatekey = "collab.key",
	
		loglevel = 3,
		logfile = "",
		oilloglevel = 0,
		oillogfile = "",
	}

	-- parse configuration file
	Configs:configs("configs", getenv("OPENBUS_SESSION_CONFIG") or "collab.cfg")

	-- parse command line parameters
	do
		io.write(msg.CopyrightNotice, "\n")
		local argidx, errmsg = Configs(...)
		if not argidx or argidx <= select("#", ...) then
			if errmsg ~= nil then
				stderr:write(errmsg,"\n")
			end
			stderr:write([[
Usage:  ]],OPENBUS_PROGNAME,[[ [options]
Options:

  -host <address>            endereço de rede usado pelo serviço de colaboração
  -port <number>             número da porta usada pelo serviço de colaboração

  -bushost <address>         endereço de rede de acesso ao barramento
  -busport <number>          número da porta de acesso ao barramento

  -database <path>           arquivo de dados do serviço de colaboração
  -privatekey <path>         arquivo com chave privada do serviço de colaboração

  -loglevel <number>         nível de log gerado pelo serviço de colaboração
  -logfile <path>            arquivo de log gerado pelo serviço de colaboração
  -oilloglevel <number>      nível de log gerado pelo OiL (debug)
  -oillogfile <path>         arquivo de log gerado pelo OiL (debug)

  -configs <path>            arquivo de configurações do serviço de colaboração

]])
			return 1 -- program's exit code
		end
	end

	-- setup log files
	setuplog(log, Configs.loglevel, Configs.logfile)
	setuplog(oillog, Configs.oilloglevel, Configs.oillogfile)

  local ctx = openbus.initORB().OpenBusContext
	local conn = ctx:createConnection(Configs.bushost, Configs.busport)
  ctx:setDefaultConnection(conn)

	local orb = conn.orb
	loadidl(orb)
	oil.newthread(orb.run, orb)
	
	-- create SCS component
	local comp = newSCS{
		orb = orb,
		objkey = CollaborationServiceName,
		name = CollaborationServiceName,
		facets = CollaborationRegistry,
		init = function()
			CollaborationRegistry.CollaborationRegistry:__init({
				connection = conn,
				database = assert(opendb(Configs.database)),
				privateKey = assert(readprivatekey(Configs.privatekey)),
			})
		end,
	}

	-- start ORB
	log:uptime(msg.ServiceSuccessfullyStarted)
end
