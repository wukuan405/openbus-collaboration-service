-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local Async = require "openbus.services.collaboration.Async"

local EventChannelInterface = idl.types.EventChannel
local EventCondumerInterface = idl.types.EventConsumer

local EventChannel = oo.class({
  __type = EventChannelInterface
})

function EventChannel:__init()
  self.consumers = {}
end

function EventChannel:destroy()
  for cookie, consumer in pairs(self.consumers) do
    self:unsubscribe(cookie)
  end
  self.registry.orb:deactivate(self)
end

function EventChannel:subscribe(consumer, cookie)
  local ior = tostring(consumer)
  if (not cookie) then
    local callerId = self.registry:callerId()
    cookie = self.dbSession:addConsumer(self.session.id, ior, callerId)
    self.registry:watchLogin(callerId, self.session, cookie, "consumers")
    log:action(msg.subscribeConsumer:tag({
      sessionId = self.session.id,
      ior = ior,
      owner = callerId
    }))
  end
  self.consumers[cookie] = consumer
  return cookie
end

function EventChannel:unsubscribe(cookie)
  if (self.consumers[cookie] == nil) then
    return false
  end      
  self.consumers[cookie] = nil
  local res = self.dbSession:delConsumer(self.session.id, cookie)
  log:action(msg.unsubscribeConsumer:tag({
    sessionId = self.session.id,
    cookie = cookie
  }))
  return true
end

function EventChannel:push(...)
  for _, consumer in pairs(self.consumers) do
    Async:call(consumer, "push", ...)
  end
end

return {
  EventChannel = EventChannel
}
