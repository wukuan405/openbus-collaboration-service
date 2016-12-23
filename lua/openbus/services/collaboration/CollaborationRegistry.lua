-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local cothread = require "cothread"

local sysex = require "openbus.util.sysex"  -- CORBA system exceptions
local NO_PERMISSION = sysex.NO_PERMISSION

local coreidl = require "openbus.core.idl"  -- OpenBus types
local InvalidLoginsType = coreidl.types.services.access_control.InvalidLogins
local ServiceFailure = coreidl.throw.services.ServiceFailure

local libidl = require "openbus.idl"        -- OpenBus Lib types
local AlreadyLoggedIn = libidl.types.AlreadyLoggedIn

local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local CollaborationSession = 
  require "openbus.services.collaboration.CollaborationSession"
local dbSession = require "openbus.services.collaboration.DBSession"
local uuid = require "uuid"

local collabidl = require "openbus.services.collaboration.idl"
local collabtypes = collabidl.types
local collabconst = collabidl.const
local MemberInterface = "::scs::core::IComponent"
local CollaborationObserverInterface = collabtypes.CollaborationObserver
local EventConsumerInterface = collabtypes.EventConsumer
local CollaborationRegistryInterface = collabtypes.CollaborationRegistry
local CollaborationRegistryFacetName = collabconst.CollaborationRegistryFacet

local CollaborationRegistry = {
  __type = CollaborationRegistryInterface,
  __objkey = CollaborationRegistryFacetName,
}

local function tryToDestroySession(login2entity, login, session)
  if (#session:getMembers() == 0 and 
     (session.creator==login.id or not login2entity[session.creator]) and
     (#session:getObservers() == 0) and 
     (#session.channel:getConsumers() == 0))
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
          tryToDestroySession(login2entity, login, session)
        end
        for key, session in pairs(entities.observers) do
          session:unsubscribeObserver(key)
          tryToDestroySession(login2entity, login, session)
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
  local task = function()
    conn:loginByCertificate(registry.entity, registry.prvKey)
    local rgs = conn.orb.OpenBusContext:getOfferRegistry()
    local ok, emsg = pcall(rgs.registerService, rgs,registry.context.IComponent,
                           {})
    if (not ok) then
      ServiceFailure({
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
       if (emsg._repid ~= InvalidLoginsType) then
         ServiceFailure({
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
  task() -- will stop the process if it fails

  local blocked = {}
  local choosed = false
  conn.onInvalidLogin = function() -- will retry undefinely
    local running = cothread.running()
    if not choosed or choosed == running then
      choosed = choosed or running
      while conn.login == nil do
        local ok, errmsg = pcall(task)
        if ok or (errmsg._repid == AlreadyLoggedIn) then
          break
        else
          log:exception(errmsg)
          pcall(conn.logout, conn)
          openbus.sleep(1)
        end
      end
      for i, thread in ipairs(blocked) do
        log:action(msg.WakingUpAfterLoginCompleted:tag{thread=tostring(thread)})
        cothread.last(thread)
        blocked[i] = nil
      end
      choosed = false
    else
      log:action(msg.YieldingToWaitLoginBeCompleted:tag{thread=tostring(running)})
      blocked[#blocked+1] = running
      cothread.yield()
    end
  end
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

function CollaborationRegistry:unregisterLogin(loginId, key, entity)
  if (self.login2entity[loginId] and self.login2entity[loginId][entity]) then
    self.login2entity[loginId][entity][key] = nil
  end
end

function CollaborationRegistry:watchLogin(loginId, session, key, entity)
  self:registerLogin(loginId, session, key, entity)
  local ok, emsg = pcall(self.subscription.watchLogin,self.subscription,loginId)
  if (not ok) then
    NO_PERMISSION({
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
  self.entity = o.entity
  self.dbSession = dbSession({
    dbPath = o.dbPath
  })
  self.login2entity = {}
  self.sessions = {}
  self.collabSessions = {} 

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
    end
    for cookie, observer in pairs(self.dbSession:getObservers(sessionId)) do
      observerServ = self.orb:newproxy(observer.ior, nil, 
                           CollaborationObserverInterface)
      session:subscribeObserver(observerServ, cookie)
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
    self.orb:newservant(session)
    self.collabSessions[sessionId] = session 
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
