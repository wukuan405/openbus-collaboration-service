-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"

local Async = oo.class()

function Async:job(objref, opname, chain, ...)
  if chain then
    ctx:joinChain(chain)
  end
  local ok, errMsg = pcall(objref[opname], objref, ...)
  if not ok then
    --[DOUBT] devo reportar? eu acho que nao
    -- log:exception(msg.AsyncCallError:tag({
    --   operation = opname,
    --   error = errMsg
    -- }))
  end
end

function Async:__init()
  ctx = self.ctx
end

function Async:call(obj, method, chain, ...)
  openbus.newThread(self.job, self, obj, method, chain, ...)
end

return {
  Async = Async
}
