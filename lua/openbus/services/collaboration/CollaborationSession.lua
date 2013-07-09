-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local dbSession = require "openbus.services.collaboration.DBSession"
local idl = require "openbus.services.collaboration.idl"
local EventChannel = require "openbus.services.collaboration.EventChannel"
local Async = require "openbus.services.collaboration.Async"

local CollaborationSessionInterface = idl.types.CollaborationSession

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
  registry.sessions[self] = true
  if (self.persist) then
    dbSession:addSession(self.id, self.creator)
    self.registry:watchLogin(self.creator, self, self.id, "sessions")
  end
end

function CollaborationSession:notifyObservers(action, ...)
  for _, o in pairs(self.observers) do
    Async:call(o.observer, action, ...)
  end
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
  if (self.members[name]) then
    idl.throw.NameInUse({
      name = name
    })
  end
  local ior = tostring(member)
  if (not owner) then
    owner = self.registry:callerId()
    self.registry.dbSession:addMember(self.id, name, ior, owner)
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
    ior = ior,
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
    return self.registry.conn.orb:newproxy(member.ior)
  end
  return nil
end

function CollaborationSession:getMembers()
  local seq = {}
  for name, member in pairs(self.members) do
    seq[#seq+1] = {
      name = name,
      member = self.registry.conn.orb:newproxy(member.ior)
    }
  end
  return seq
end

function CollaborationSession:subscribeObserver(observer, cookie)
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

return {
  CollaborationSession = CollaborationSession,
}
