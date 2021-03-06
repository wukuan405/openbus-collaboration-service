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
local SessionRegistry = 
  require "openbus.services.collaboration.SessionRegistry"

local coreidl = require "openbus.core.idl"
local BusEntity = coreidl.const.BusEntity

local sysex = require "openbus.util.sysex"
local NO_PERMISSION = sysex.NO_PERMISSION

local function defaultConfig()
  return server.ConfigArgs(
  {
    host = "*",
    port = 2090,    
    bushost = "localhost",
    busport = 2089,  
    database = "db.sqlite3",
    privatekey = "collab.key",
    entity = idl.const.CollaborationServiceName,
    loglevel = 4,
    logfile = "",
    oilloglevel = 0,
    oillogfile = "",
    nodnslookup = false,
    noipaddress = false,
    alternateaddr = {},
  })
end

local function parseConfigFile(config)
  config:configs("configs", os.getenv("COLLAB_CONFIG") or 
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

  -- validate oil objrefaddr configuration
  local objrefaddr = {
    hostname = (not config.nodnslookup),
    ipaddress = (not config.noipaddress),
  }
  local additional = {}
  for _, address in ipairs(config.alternateaddr) do
    local host, port = address:match("^([%w%-%_%.]+):(%d+)$")
    port = tonumber(port)
    if (host ~= nil) and (port ~= nil) then
      additional[#additional+1] = { host = host, port = port }
    else
      log:misconfig(msg.WrongAlternateAddressSyntax:tag{
        value = address,
        expected = "host:port or ip:port",
      })
      return 1
    end
  end
  if (#additional > 0) then
    objrefaddr.additional = additional
  end
  log:config(msg.AdditionalInternetAddressConfiguration:tag(objrefaddr))
  
  local ctx = openbus.initORB(
  {
    host = config.host, 
    port = config.port,
    objrefaddr = objrefaddr,
  }).OpenBusContext
  local conn = ctx:createConnection(config.bushost, config.busport)
  ctx:setDefaultConnection(conn)
  
  local orb = conn.orb
  idl.loadto(orb)
  
  local comp = server.newSCS(
  {
    orb = orb,
    objkey = config.entity,
    name = config.entity,
    facets = {
        CollaborationRegistry = CollaborationRegistry.CollaborationRegistry,
        SessionRegistry = SessionRegistry.SessionRegistry,
    },
    init = function()
      CollaborationRegistry.CollaborationRegistry:__init(
      {
        conn = conn,
        busCtx = ctx,
        dbPath = config.database,
        prvKey = assert(server.readprivatekey(config.privatekey)),
        entity = config.entity,
      })

      SessionRegistry.SessionRegistry:__init(
      {
        conn = conn,
        busCtx = ctx,
        dbPath = config.database,
        prvKey = assert(server.readprivatekey(config.privatekey)),
        entity = config.entity,
        collabSessions = CollaborationRegistry.CollaborationRegistry.collabSessions,
      })
    end,
    shutdown = function(self)
      local caller = ctx:getCallerChain().caller
      if caller.entity ~= config.entity and caller.entity ~= BusEntity then
        NO_PERMISSION{ completed = "COMPLETED_NO" }
      end
      self.context:deactivateComponent()
      conn:logout()
      orb:shutdown()
      log:uptime(msg.ServiceTerminated)
    end,
  })
  comp.IComponent:startup()
  log:uptime(msg.ServiceSuccessfullyStarted)
end
