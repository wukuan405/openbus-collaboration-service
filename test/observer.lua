-- -*- coding: iso-8859-1-unix -*-

require "setup"

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

local observer = {}
function observer:memberAdded(name, member)
  called["memberAdded"][name] = member
end
function observer:memberRemoved(name)
  called["memberRemoved"][name] = true
end
function observer:destroyed()
  called["destroyed"] = true
end
observer = env.orb:newservant(observer, nil, 
                              env.idl.types.CollaborationObserver)

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local cookie = session:subscribeObserver(observer)
  local members = {"m1", "m2", "m3"}
  for _, v in ipairs(members) do 
    session:addMember(v, component.IComponent)
    -- ugly!
    oil.sleep(1)
    assert(called["memberAdded"][v])
  end
  for _, v in ipairs(members) do
    session:removeMember(v)
    -- ugly!
    oil.sleep(1)
    assert(called["memberRemoved"][v])
  end
  session:destroy()
  -- ugly!
  oil.sleep(1)
  assert(called["destroyed"])
end

env.conn:logout()
env.orb:shutdown()
