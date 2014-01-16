-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local Async = require "openbus.services.collaboration.Async"
local sysex = require "openbus.util.sysex"

local EventChannelInterface = idl.types.EventChannel
local EventCondumerInterface = idl.types.EventConsumer

local EventChannel = oo.class({
  __type = EventChannelInterface
})

function EventChannel:__init()
  self.consumers = {}
  self.ctx = self.registry.orb.OpenBusContext
  self.async = Async.Async({
    ctx = self.ctx
  })
end

function EventChannel:destroy()
  for cookie, _ in pairs(self.consumers) do
    self:unsubscribe(cookie)
  end
  self.consumers = nil
  self.registry.orb:deactivate(self)
end

function EventChannel:subscribe(consumer, cookie)
  if (consumer == nil) then
    sysex.BAD_PARAM({completed = "COMPLETED_NO", minor = 0})
  end
  local ior = tostring(consumer)
  local callerId
  if (not cookie) then
    callerId = self.registry:callerId()
    cookie = self.dbSession:addConsumer(self.session.id, ior, callerId)
    self.registry:watchLogin(callerId, self.session, cookie, "consumers")
    log:action(msg.subscribeConsumer:tag({
      sessionId = self.session.id,
      ior = ior,
      owner = callerId
    }))
  end
  self.consumers[cookie] = {
    owner = callerId,
    consumer = consumer
  }
  return cookie
end

function EventChannel:unsubscribe(cookie)
  if (self.consumers[cookie] == nil) then
    return false
  end      
  self.dbSession:delConsumer(self.session.id, cookie)
  self.registry:unregisterLogin(self.consumers[cookie].owner, cookie, "consumers")
  self.consumers[cookie] = nil
  log:action(msg.unsubscribeConsumer:tag({
    sessionId = self.session.id,
    cookie = cookie
  }))
  return true
end

function EventChannel:getConsumers()
  local seq = {}
  for cookie, consumer in pairs(self.consumers) do
    seq[#seq+1] = {
      cookie = cookie,
      owner = consumer.owner,
      consumer = consumer.consumer
    }
  end
  return seq
end

function EventChannel:push(...)
  local chain = ctx:getCallerChain()
  for _, o in pairs(self.consumers) do
    self.async:call(o.consumer, "push", chain, ...)
  end
end

return {
  EventChannel = EventChannel
}
