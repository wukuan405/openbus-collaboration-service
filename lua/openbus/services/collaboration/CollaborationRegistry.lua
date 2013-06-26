-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local busIdl = require "openbus.core.idl"
local sysex = require "openbus.util.sysex"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local CollaborationSession = 
  require "openbus.services.collaboration.CollaborationSession"
local dbSession = require "openbus.services.collaboration.DBSession"
local uuid = require "uuid"

local MemberInterface = "::scs::core::IComponent"
local CollaborationObserverInterface = idl.types.CollaborationObserver
local EventConsumerInterface = idl.types.EventConsumer
local CollaborationRegistryInterface = idl.types.CollaborationRegistry
local CollaborationRegistryFacetName = idl.const.CollaborationRegistryFacet
local CollaborationServiceName = idl.const.CollaborationServiceName
local InvalidLoginsRepId = busIdl.types.services.access_control.InvalidLogins

local CollaborationRegistry = {
  __type = CollaborationRegistryInterface,
  __objkey = CollaborationRegistryFacetName,
}

local function tryToDestroySession(login2entity, login, session)
  if (#session:getMembers() == 0 and 
     (session.creator==login.id or not login2entity[session.creator]))
  then
    session:destroy()
  end
end

local function registerOnInvalidLogin(registry)
  local login2entity = registry.login2entity
  registry.observer = {
    entityLogout = function(_, login)
      local entities = login2entity[login.id]
      if (not entities) then
         --[DOUBT] assert?
        log:unexpected(msg.GotUnsolicitedLogoutNotification:tag({
          login = login.id,
          entity = login.entity,
        }))
      else
        for key, session in pairs(entities.consumers) do
          session.channel:unsubscribe(key)
        end
        for key, session in pairs(entities.observers) do
          session:unsubscribeObserver(key)
        end
        for key, session in pairs(entities.members) do
          session:removeMember(key)
          tryToDestroySession(login2entity, login, session)
        end
        for key, session in pairs(entities.sessions) do
          tryToDestroySession(login2entity, login, session)
        end
        login2entity[login.id] = nil
        local ok, emsg = pcall(registry.subscription.forgetLogin, 
                               registry.subscription, login.id)
        if (not ok) then
          log:exception(msg.UnableToStopWatchingLogin:tag({
            login = login.id,
            error = emsg,
          })) 
        end
      end
    end
  }

  local conn = registry.conn
  conn.onInvalidLogin = function()
    conn:loginByCertificate(CollaborationServiceName, registry.prvKey)
    local rgs = conn.orb.OpenBusContext:getOfferRegistry()
    local ok, emsg = pcall(rgs.registerService, rgs,registry.context.IComponent,
                           {})
    if (not ok) then
      sysex.ServiceFailure({
        message = msg.UnableToRegisterService:tag({
          error = emsg
        })
      })
    end
    local subscription = registry.busCtx:getLoginRegistry():subscribeObserver(
      registry.observer)
    registry.subscription = subscription
    local loginSeq = {}
    for login, _ in pairs(registry.login2entity) do
      loginSeq[#loginSeq+1] = login
    end
    local ok, emsg = pcall(subscription.watchLogins, subscription, loginSeq)
    if (not ok) then
       if (emsg._repid ~= InvalidLoginsRepId) then
         sysex.ServiceFailure({
           message = msg.UnableToWatchMultipleLogins:tag({ 
             error = emsg 
           })
         })
       end
       for _, login in ipairs(emsg.loginIds) do
         registry.observer:entityLogout({
           id = login
         })
       end
    end
  end
  conn.onInvalidLogin()
end

function CollaborationRegistry:registerLogin(loginId, session, key, entity)
  if (self.login2entity[loginId] == nil) then
    self.login2entity[loginId] = {
      sessions = {},
      members = {},
      consumers = {},
      observers = {}      
    }
  end
  self.login2entity[loginId][entity][key] = session
end

function CollaborationRegistry:forgetLogin(logindId)
  local ok, emsg = pcall(self.subscription.forgetLogin,
                         self.subscription, loginId)
  if (not ok) then
    log:exception(msg.UnableToStopWatchingLogin:tag({
      login = loginId,
      error = emsg,
    })) 
   end
end

function CollaborationRegistry:watchLogin(loginId, session, key, entity)
  self:registerLogin(loginId, session, key, entity)
  local ok, emsg = pcall(self.subscription.watchLogin,self.subscription,loginId)
  if (not ok) then
    sysex.NO_PERMISSION({ 
      minor = InvalidLoginMinorCode 
    })
    log:exception(msg.UnableToWatchLogin:tag({
      login = loginId,
      error = emsg,
    }))
  end
end

function CollaborationRegistry:__init(o)
  self.busCtx = o.busCtx
  self.conn = o.conn
  self.orb = self.conn.orb
  self.prvKey = o.prvKey
  self.dbSession = dbSession({
    dbPath = o.dbPath
  })
  self.login2entity = {}
  self.sessions = {}

  for sessionId, creator in pairs(self.dbSession:getSessions()) do
    local session = CollaborationSession.CollaborationSession({
      __objkey = sessionId,
      creator = creator,
      registry = self
    })
    self:registerLogin(creator, session, session, "sessions")
    log:admin(msg.recoverySession:tag({
      sessionId = sessionId,
      creator = creator
    }))
    for _, member in ipairs(self.dbSession:getMembers(sessionId)) do
      session:addMember(member.name, 
                        self.orb:newproxy(member.ior, nil, MemberInterface),
                        member.owner)
      self:registerLogin(member.owner, session, member.name, "members")
      log:admin(msg.recoveryMember:tag({
        name = member.name,
        owner = member.owner,
        sessionId = sessionId
      }))
      for cookie, observer in pairs(self.dbSession:getObservers(sessionId)) do
        session:subscribeObserver(
           self.orb:newproxy(observer.ior, nil, 
                             CollaborationObserverInterface), cookie)
        self:registerLogin(observer.owner, session, cookie, "observers")
        log:admin(msg.recoveryObserver:tag({
          sessionId = sessionId,
          cookie = cookie,
          ior = observer.ior,
          owner = observer.owner
        }))
      end
      for cookie, consumer in pairs(self.dbSession:getConsumers(sessionId)) do
        session.channel:subscribe(
          self.orb:newproxy(consumer.ior, nil, EventConsumerInterface), cookie)
        self:registerLogin(consumer.owner, session, cookie, "consumers")
        log:admin(msg.recoveryConsumer:tag({
          sessionId = sessionId,
          cookie = cookie,
          ior = consumer.ior,
          owner = consumer.owner
        }))
      end
    end
    self.orb:newservant(session)
  end
  registerOnInvalidLogin(self)
end

function CollaborationRegistry:callerId()
  return self.busCtx:getCallerChain().caller.id
end

function CollaborationRegistry:createCollaborationSession()
  local creator = self:callerId()
  local session = CollaborationSession.CollaborationSession({
    __objkey = uuid.new(),
    registry = self,
    creator = creator,
    persist = true
  })
  log:admin(msg.createCollaborationSession:tag({
    sessionId = session.__objkey,
    creator = creator
  }))
  return session
end

return {
  CollaborationRegistry = CollaborationRegistry,
}
