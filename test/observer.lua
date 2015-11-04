-- -*- coding: iso-8859-1-unix -*-

require "setup"

local cothread = require "cothread"

local env = setup()
env.openbus.newThread(env.orb.run, env.orb)

local hello = {}
function hello:sayHello()
  print("Hello")
end
local iface = env.orb:loadidl([[
  interface Hello 
  { 
    void sayHello(); 
  };
]])
local component = env.componentCtx(env.orb, {
  name= iface.name,
  major_version = 1,
  minor_version = 0,
  patch_version = 0,
  platform_spec = "Lua"
})
component:addFacet("Hello", iface.repID, hello)
env.rgs:registerService(component.IComponent, {
  {
    name = "offer.domain",
    value = "Demo Hello"
  }
})

local called = {
  memberAdded = {},
  memberRemoved = {},
}

local thread

local observer = {}
function observer:memberAdded(name, member)
  called["memberAdded"][name] = member
  if thread ~= nil then
    cothread.next(thread)
  end
end
function observer:memberRemoved(name)
  called["memberRemoved"][name] = true
  if thread ~= nil then
    cothread.next(thread)
  end
end
function observer:destroyed()
  called["destroyed"] = true
  if thread ~= nil then
    cothread.next(thread)
  end
end
observer = env.orb:newservant(observer, nil, 
                              env.idl.types.CollaborationObserver)

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local cookie = session:subscribeObserver(observer)
  local members = {"m1", "m2", "m3"}
  --cothread.verbose:level(5)
  for _, v in ipairs(members) do 
    session:addMember(v, component.IComponent)
    if (not called["memberAdded"][v]) then
      thread = coroutine.running()
      cothread.suspend()
      thread = nil
    end
    assert(called["memberAdded"][v])
  end
  for _, v in ipairs(members) do
    session:removeMember(v)
    if (not called["memberRemoved"][v]) then
      thread = coroutine.running()
      cothread.suspend()
      thread = nil
    end
    assert(called["memberRemoved"][v])
  end
  session:destroy()
  if (not called["destroyed"]) then
    thread = coroutine.running()
    cothread.suspend()
    thread = nil
  end
  assert(called["destroyed"])
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local ret, ex = pcall(session.subscribeObserver, session, nil)
  assert(ret == false)
  assert(ex._repid == "IDL:omg.org/CORBA/BAD_PARAM:1.0")
  session:destroy()
end

env.conn:logout()
env.orb:shutdown()
