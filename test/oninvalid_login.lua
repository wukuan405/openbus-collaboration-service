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

local sleep_time = 3

do
  local c1 = env.busCtx:createConnection(bushost, busport)
  c1:loginByPassword(env.user, env.password)
  env.busCtx:setDefaultConnection(c1)
  local session = env.collaborationRegistry:createCollaborationSession()
  local c2 = env.busCtx:createConnection(bushost, busport)
  c2:loginByPassword(env.user, env.password)
  env.busCtx:setDefaultConnection(c2)
  local m1 = session:addMember("m1", component.IComponent)
  c2:logout()
  oil.sleep(sleep_time)
  assert(#getRows("session") == 1)
  assert(#getRows("member") == 0)
  c1:logout()
  oil.sleep(sleep_time)
  assert(#getRows("session") == 0)  
end

do
  local c1 = env.busCtx:createConnection(bushost, busport)
  c1:loginByPassword(env.user, env.password)
  env.busCtx:setDefaultConnection(c1)
  local session = env.collaborationRegistry:createCollaborationSession()
  local c2 = env.busCtx:createConnection(bushost, busport)
  c2:loginByPassword(env.user, env.password)
  env.busCtx:setDefaultConnection(c2)
  local m1 = session:addMember("m1", component.IComponent)
  env.busCtx:setDefaultConnection(c1)
  c1:logout()
  oil.sleep(sleep_time)
  assert(#getRows("session") == 1)
  assert(#getRows("member") == 1)
  env.busCtx:setDefaultConnection(c2)
  c2:logout()
  oil.sleep(sleep_time)
  assert(#getRows("session") == 0)
  assert(#getRows("member") == 0)
end

do
  local c1 = env.busCtx:createConnection(bushost, busport)
  c1:loginByPassword(env.user, env.password)
  env.busCtx:setDefaultConnection(c1)
  local s1 = env.collaborationRegistry:createCollaborationSession()
  local s2 = env.collaborationRegistry:createCollaborationSession()
  local m1 = s1:addMember("m1", component.IComponent)
  local m2 = s2:addMember("m2", component.IComponent)
  c1:logout()
  oil.sleep(sleep_time)
  assert(#getRows("session") == 0)
  assert(#getRows("member") == 0)
end

env.conn:logout()  
db:close()
env.orb:shutdown()
