-- -*- coding: iso-8859-1-unix -*-

require "setup"

local env = setup()
env.openbus.newThread(env.orb.run, env.orb)

local sqlite = require "lsqlite3"

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

local dbFilename = os.getenv("DB_SQLITE3")
local db = sqlite.open(dbFilename)
assert(db)

local function getRows(entity)
  local rows = {}
  for row in db:nrows('SELECT * FROM '..entity..';') do
    rows[#rows+1] = row
  end
  return rows
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local sessions = getRows("session")
  assert(#sessions == 1)
  assert(sessions[1].creator == env.conn.login.id)
  session:destroy()
  assert(#getRows("session") == 0)
end

do 
  local session = env.collaborationRegistry:createCollaborationSession()
  local memberAId = "memberA"
  local memberBId = "memberB"
  session:addMember(memberAId, component.IComponent)
  session:addMember(memberBId, component.IComponent)
  local members = getRows("member")
  assert(#members == 2)
  session:removeMember(memberAId)
  assert(#getRows("member") == 1)
  session:removeMember(memberBId)
  assert(#getRows("member") == 0)
  session:destroy()
  assert(#getRows("member") == 0)
  assert(#getRows("session") == 0)
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
  local memberId = "member"
  session:addMember(memberId, component.IComponent)
  local cookies = {}
  for i=1, 3 do
    cookies[#cookies+1] = session:subscribeObserver(observer)
  end
  assert(#getRows("observer") == 3)
  session:unsubscribeObserver(cookies[1])
  assert(#getRows("observer") == 2)
  session:unsubscribeObserver(cookies[2])
  assert(#getRows("observer") == 1)
  session:destroy()
  assert(#getRows("observer") == 0)
  assert(#getRows("member") == 0)
  assert(#getRows("session") == 0)
end

local consumer = {}
function consumer:push(any)
end
consumer = env.orb:newservant(consumer, nil, env.idl.types.EventChannel)

do
  local session = env.collaborationRegistry:createCollaborationSession()
  local memberId = "member"
  session:addMember(memberId, component.IComponent)
  local cookie = session:_get_channel():subscribe(consumer)
  session:_get_channel():subscribe(consumer)
  assert(#getRows("consumer") == 2)
  session:_get_channel():unsubscribe(cookie)
  assert(#getRows("consumer") == 1)
  session:destroy()
  assert(#getRows("consumer") == 0)
end

do
  local session = env.collaborationRegistry:createCollaborationSession()
  env.sessionRegistry:registerSession(session)
  local collabs = getRows("collab")
  assert(#collabs == 1)
  assert(collabs[1].entity == user)
  session:destroy()
  assert(#getRows("collab") == 0)
  local ok, ex = pcall(env.sessionRegistry.removeSession, env.sessionRegistry, user)
end

db:close()
env.conn:logout()
env.orb:shutdown()
