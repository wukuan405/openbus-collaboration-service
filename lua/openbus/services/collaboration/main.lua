-- -*- coding: iso-8859-1-unix -*-

local oil = require "oil"
local oillog = require "oil.verbose"
local openbus = require "openbus"
local log = require "openbus.util.logger"
local server = require "openbus.util.server"
local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local CollaborationRegistry = 
  require "openbus.services.collaboration.CollaborationRegistry"

local CollaborationServiceName = idl.const.CollaborationServiceName

local function defaultConfig()
  return server.ConfigArgs(
  {
    host = "*",
    port = 2090,
    
    busHost = "localhost",
    busPort = 2089,
  
    database = "db.sqlite3",
    privatekey = "collab.key",
  
    loglevel = 4,
    logfile = "",
    oilloglevel = 0,
    oillogfile = "",
  })
end

local function parseConfigFile(config)
  config:configs("configs", os.getenv("OPENBUS_SESSION_CONFIG") or 
                 "collab.cfg")
end

local function parseCmdLine(config, ...)
  do
    io.write(msg.CopyrightNotice, "\n")
    local argidx, errmsg = config(...)
    if (not argidx or argidx <= select("#", ...)) then
      if (errmsg ~= nil) then
        io.stderr:write(errmsg,"\n")
      end
      io.stderr:write("\nUsage:  ", OPENBUS_PROGNAME, msg.CommandLineOptions)
      return false
    end
  end
  return true
end

return function(...)
  local config = defaultConfig()
  parseConfigFile(config)
  if (not parseCmdLine(config, ...)) then
    return 1
  end

  server.setuplog(log, config.loglevel, config.logfile)
  server.setuplog(oillog, config.oilloglevel, config.oillogfile)
  
  local ctx = openbus.initORB(
  {
    host = config.host, 
    port = config.port,
  }).OpenBusContext
  local conn = ctx:createConnection(config.busHost, config.busPort)
  ctx:setDefaultConnection(conn)
  
  local orb = conn.orb
  idl.loadto(orb)
  oil.newthread(orb.run, orb)
  
  local comp = server.newSCS(
  {
    orb = orb,
    objkey = CollaborationServiceName,
    name = CollaborationServiceName,
    facets = CollaborationRegistry,
    init = function()
      CollaborationRegistry.CollaborationRegistry:__init(
      {
        conn = conn,
        busCtx = ctx,
        dbPath = config.database,
        prvKey = assert(server.readprivatekey(config.privatekey)),
      })
    end,
  })
  log:uptime(msg.ServiceSuccessfullyStarted)
end
