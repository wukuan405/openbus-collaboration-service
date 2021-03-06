-- -*- coding: iso-8859-1-unix -*-

local Publisher = require "loop.object.Publisher"
local openbus = require "openbus"
local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local dbSession = require "openbus.services.collaboration.DBSession"
local EventChannel = require "openbus.services.collaboration.EventChannel"
local Async = require "openbus.services.collaboration.Async"
local sysex = require "openbus.util.sysex"
local BAD_PARAM = sysex.BAD_PARAM

local idl = require "openbus.services.collaboration.idl"
local CollaborationSessionInterface = idl.types.CollaborationSession
local NameInUse = idl.throw.NameInUse

local CollaborationSession = oo.class({ 
  __type = CollaborationSessionInterface,
})

function CollaborationSession:__init()
  self.id = self.__objkey
  local registry = self.registry
  local dbSession = registry.dbSession
  self.channel = EventChannel.EventChannel({
    session = self,
    dbSession = dbSession,
    registry = registry
  })
  self.members = {}
  self.observers = {}
  self.publisher = Publisher()
  registry.sessions[self] = true
  if (self.persist) then
    dbSession:addSession(self.id, self.creator)
    self.registry:watchLogin(self.creator, self, self.id, "sessions")
  end
  self.ctx = self.registry.orb.OpenBusContext
  self.async = Async.Async({
    ctx = self.ctx
  })
end

function CollaborationSession:destroy()
  if (not self.registry.sessions[self]) then
    return
  end
  for name, _ in pairs(self.members) do
    self:removeMember(name)
  end
  self:notifyObservers("destroyed")
  for cookie, _ in pairs(self.observers) do
    self:unsubscribeObserver(cookie)
  end
  self.publisher:destroyed()
  self.channel:destroy()
  self.registry.dbSession:delSession(self.id)
  self.registry.sessions[self] = nil
  self.registry:unregisterLogin(self.creator, self.id, "sessions")
  self.registry.orb:deactivate(self)
  log:action(msg.delSession:tag({
    sessionId = self.id
  }))
end

function CollaborationSession:addMember(name, member, owner)
  if (member == nil) then
    BAD_PARAM({completed = "COMPLETED_NO", minor = 0})
  end
  if (self.members[name]) then
    NameInUse({
      name = name
    })
  end
  if (not owner) then
    owner = self.registry:callerId()
    self.registry.dbSession:addMember(self.id, name, tostring(member), owner)
    self:notifyObservers("memberAdded", name, member)
    self.registry:watchLogin(owner, self, name, "members")
    log:action(msg.addMember:tag({
      sessionId = self.id,
      name = name,
      owner = owner
    }))
  end
  self.members[name] = {
    sessionId = self.id,
    proxy = member,
    owner = owner
  }
end

function CollaborationSession:removeMember(name)
  if (self.members[name] == nil) then
    return false
  end
  local owner = self.members[name].owner
  local res = self.registry.dbSession:delMember(self.id, name)
  if (not res) then
    return false
  end
  self.members[name] = nil
  self:notifyObservers("memberRemoved", name)
  self.registry:unregisterLogin(owner, name, "members")
  log:action(msg.delMember:tag({
    sessionId = self.id,
    name = name
  }))
  return true
end

function CollaborationSession:getMember(name)
  local member = self.members[name]
  if (member) then
    return member.proxy
  end
  return nil
end

function CollaborationSession:getMembers()
  local seq = {}
  for name, member in pairs(self.members) do
    seq[#seq+1] = {
      name = name,
      member = member.proxy
    }
  end
  return seq
end

function CollaborationSession:subscribeObserver(observer, cookie)
  if (observer == nil) then
    BAD_PARAM({completed = "COMPLETED_NO", minor = 0})
  end
  local ior = tostring(observer)
  local callerId
  if (not cookie) then
    callerId = self.registry:callerId()
    cookie = self.registry.dbSession:addObserver(self.id, ior, callerId)
    self.registry:watchLogin(callerId, self, cookie, "observers")
    log:action(msg.subscribeObserver:tag({
      sessionId = self.id,
      ior = ior,
      owner = callerId
    }))
  end
  self.observers[cookie] = {
    owner = callerId,
    observer = observer
  }
  return cookie
end

function CollaborationSession:unsubscribeObserver(cookie)
  if (self.observers[cookie] == nil) then
    return false
  end      
  local res = self.registry.dbSession:delObserver(self.id, cookie)
  if (not res) then
    return false
  end
  self.registry:unregisterLogin(self.observers[cookie].owner,cookie,"observers")
  self.observers[cookie] = nil
  log:action(msg.unsubscribeObserver:tag({
    sessionId = self.id,
    cookie = cookie
  }))
  return true
end

function CollaborationSession:getObservers()
  local seq = {}
  for cookie, observer in pairs(self.observers) do
    seq[#seq+1] = {
      cookie = cookie,
      owner = observer.owner,
      observer = observer.observer
    }
  end
  return seq
end

function CollaborationSession:notifyObservers(action, ...)
  local chain = self.ctx:getCallerChain()
  for _, o in pairs(self.observers) do
    self.async:call(o.observer, action, chain, ...)
  end
end

return {
  CollaborationSession = CollaborationSession,
}
