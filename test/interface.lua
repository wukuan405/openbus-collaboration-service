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

do 
  local session = env.collaborationRegistry:createCollaborationSession()
  assert(session.__type.repID == env.idl.types.CollaborationSession)
  session:destroy()
  local ok, ex = pcall(session.destroy, session)
  assert(ok == false)
  assert(ex._repid == "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0")
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  assert(session:removeMember("dummy") == false)
  assert(session:getMember("dummy") == nil)
  assert(#session:getMembers() == 0)
  session:destroy()
end  

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local ret, ex = pcall(session.addMember, session, "m1", nil)
  assert(ret == false)
  assert(ex._repid == "IDL:omg.org/CORBA/BAD_PARAM:1.0")
  session:destroy()
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local memberName = "Hello"
  session:addMember(memberName, component.IComponent)
  assert(#session:getMembers() == 1)
  assert(session:getMember(memberName) ~= nil)
  local _, ex = pcall(session.addMember, session, memberName, 
                      component.IComponent)
  assert(ex._repid == env.idl.types.NameInUse)
  assert(session:removeMember(memberName))
  assert(session:getMember("dummy") == nil)
  assert(#session:getMembers() == 0)
  session:destroy()
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local members = { "m1", "m2", "m3" }
  for _, v in pairs(members) do
    session:addMember(v, component.IComponent)
  end
  assert(#session:getMembers() == 3)
  for i, v in pairs(members) do
    session:removeMember(v)
    assert(#session:getMembers() == #members-i)
  end
  assert(#session:getMembers() == 0)
  for _, v in pairs(members) do
    assert(session:getMember(v) == nil)
  end
  session:destroy()
end

local observer = {}
function observer:memberAdded(name, member)
end
function observer:memberRemoved(name)
end
function observer:destroyed()
end
observer = env.orb:newservant(observer, nil, 
                              env.idl.types.CollaborationObserver)

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local cookie = session:subscribeObserver(observer)
  assert(session:unsubscribeObserver(cookie))
  assert(session:unsubscribeObserver(cookie) == false)
  assert(session:unsubscribeObserver(cookie+1) == false)
  cookie = session:subscribeObserver(observer)
  assert(session:unsubscribeObserver(cookie))
  session:destroy()
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local channel = session:_get_channel()
  local ret, ex = pcall(channel.subscribe, channel, nil)
  assert(ret == false)
  assert(ex._repid == "IDL:omg.org/CORBA/BAD_PARAM:1.0")
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local channel = session:_get_channel()
  local thread = coroutine.running()
  local pushed
  local cookie = channel:subscribe({
    push = function(self, any)
      pushed = true
      local chain = env.orb.OpenBusContext:getCallerChain()
      assert(#chain.originators == 1)
      if (thread) then 
        cothread.next(thread) 
      end
    end
  })
  channel:push("string")
  if (not pushed) then
    cothread.suspend()
    thread = nil
  end
  assert(pushed)
  assert(channel:unsubscribe(cookie))
  assert(channel:unsubscribe(cookie) == false)
  session:destroy()
end

env.conn:logout()
env.orb:shutdown()
