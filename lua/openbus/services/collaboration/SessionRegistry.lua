-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local busIdl = require "openbus.core.idl"
local sysex = require "openbus.util.sysex"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local dbSession = require "openbus.services.collaboration.DBSession"
local uuid = require "uuid"
local CollaborationSession = 
  require "openbus.services.collaboration.CollaborationSession"

local MemberInterface = "::scs::core::IComponent"
local CollaborationObserverInterface = idl.types.CollaborationObserver
local EventConsumerInterface = idl.types.EventConsumer
local SessionRegistryInterface = idl.types.SessionRegistry
local SessionRegistryFacetName = idl.const.SessionRegistryFacet
local InvalidLoginsRepId = busIdl.types.services.access_control.InvalidLogins

-- Observador de sessão que possui a mesma interface do observador de
-- colaboração e sobreescreve o método destroyed para que a sessão seja
-- retirada do registro e o observador seja removido.

local SessionRegistry = {
  __type = SessionRegistryInterface,
  __objkey = SessionRegistryFacetName,
}

function SessionRegistry:__init(o)
  self.busCtx = o.busCtx
  self.conn = o.conn
  self.orb = self.conn.orb
  self.prvKey = o.prvKey
  self.entity = o.entity
  self.dbSession = dbSession({
    dbPath = o.dbPath
  })
  self.entity2session = {}
  self.deactivation = {}
  -- require("loop.debug.Viewer"){maxdepth = 2}:write("Sessions: ", o.collabSessions); print()
  local collabs = self.dbSession:getCollabs()
  for entity, collabId in pairs(self.dbSession:getCollabs()) do
    local recovered = false
    for sessionId, session in pairs(o.collabSessions) do
      if sessionId == collabId then
        self:registerSessionToEntity(session, entity)
        recovered = true
      end
    end
    if not recovered then
      self.dbSession:delCollab(entity) -- Remover sessão obsoleta, caso exista
    end
  end
end

function SessionRegistry:callerInfo()
  local chain = self.busCtx:getCallerChain()
  local caller = chain.caller;
  if #chain.originators > 0
  then
    caller = chain.originators[1]
  end
  return caller
end

function SessionRegistry:registerSession(session)
  local caller = self:callerInfo()
  self:registerSessionToEntity(session, caller.entity)
end

function SessionRegistry:registerSessionToEntity(session, entity)
  self.entity2session[entity] = session
  local sessionObserver = {}
  function sessionObserver.destroyed()
    -- TODO capturar excecao SessionDoesNotExist e logar ocorrencia
    self:removeSession(entity)
    rawset(session.publisher, sessionObserver, nil) -- remover observador local da sessão
  end
  rawset(session.publisher, sessionObserver, sessionObserver) -- inserir observador local da sessão
  if(session.persist) then
    self.dbSession:addCollab(entity, session.id)
  end
end

function SessionRegistry:removeSession(entity)
  self.dbSession:delCollab(entity)
  local session = self.entity2session[entity]
  if (session == nil)
  then
    idl.throw.SessionDoesNotExist({
      entity = entity
    })
  end
  self.entity2session[entity] = nil
end

-- TODO thread to clean observer objects
function SessionRegistry:deactivateObservers()

end

function SessionRegistry:findSession(entity)
  local session = self.entity2session[entity]
  if (session == nil)
  then
    idl.throw.SessionDoesNotExist({
      entity = entity
    })
  end
  return session
end

function SessionRegistry:getSession()
  local entity = self:callerInfo().entity
  return self:findSession(entity) 
end

return {
  SessionRegistry = SessionRegistry,
}
