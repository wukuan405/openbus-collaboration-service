-- -*- coding: iso-8859-1-unix -*-

local openbus = require "openbus"
local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"

local Async = {}

local function job(objref, opname, ...)
  local ok, errMsg = pcall(objref[opname], objref, ...)
  if not ok then
    --[DOUBT] devo reportar? eu acho que nao
    -- log:exception(msg.AsyncCallError:tag({
    --   operation = opname,
    --   error = errMsg
    -- }))
  end
end

function Async:call(obj, method, ...)
  openbus.newThread(job, obj, method, ...)
end

return Async
