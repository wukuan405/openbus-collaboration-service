-- -*- coding: iso-8859-1-unix -*-

local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"
local msg = require "openbus.services.collaboration.messages"
local sqlite = require "lsqlite3"

local DBSession = oo.class()

local entity = {
  session = {
    create = [[
      CREATE TABLE session (
        objkey TEXT PRIMARY KEY, 
        creator TEXT
      );
    ]],
    delete = "DELETE FROM session WHERE objkey = ?;",
    insert = "INSERT INTO session (objkey, creator) VALUES (?,?);",
    selectAll = "SELECT objkey, creator FROM session;"
  },
  member = {
    create = [[
      CREATE TABLE member (
        name TEXT, 
        session_id TEXT, 
        ior TEXT,
        owner TEXT, 
        PRIMARY KEY (name, session_id), 
        CONSTRAINT "fk_member_session" FOREIGN KEY ("session_id") 
        REFERENCES "session" ("objkey") ON DELETE CASCADE
      );
    ]],
    delete = "DELETE FROM member WHERE session_id = ? AND name = ?;",
    insert = "INSERT INTO member (name, ior,  owner, session_id)"..
      " VALUES (?,?,?,?);",
    select = "SELECT owner, ior FROM member WHERE session_id = ? AND name = ?;",
    selectAll = "SELECT name, owner, ior FROM member WHERE session_id = ?;"
  },
  consumer = {
    create = [[
      CREATE TABLE consumer (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        ior TEXT NOT NULL, 
        owner TEXT, 
        session_id TEXT, 
        UNIQUE (id, session_id)
        CONSTRAINT "fk_consumer_session" FOREIGN KEY ("session_id") 
        REFERENCES "session" ("objkey") ON DELETE CASCADE
      );
    ]],
    delete = 'DELETE FROM consumer WHERE session_id = ? AND id = ?;',
    insert = 'INSERT INTO consumer (session_id, ior, owner) VALUES (?, ?, ?);',
    selectAll = 'SELECT id, ior, owner FROM consumer WHERE session_id = ?;'
  },
  observer = {
    create = [[
      CREATE TABLE observer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ior TEXT NOT NULL, 
        owner TEXT, 
        session_id TEXT, 
        UNIQUE (id, session_id)
        CONSTRAINT "fk_observer_session" FOREIGN KEY ("session_id")
        REFERENCES "session" ("objkey") ON DELETE CASCADE
      );
    ]],
    delete = 'DELETE FROM observer WHERE session_id = ? AND id = ?;',
    insert = 'INSERT INTO observer (session_id, ior, owner) VALUES (?, ?, ?);',
    selectAll = 'SELECT id, ior, owner FROM observer WHERE session_id = ?;'
  },
  collab = {
    create = [[
      CREATE TABLE collab (
        entity TEXT PRIMARY KEY,
        session_id TEXT,
        CONSTRAINT "fk_collab_session" FOREIGN KEY ("session_id")
        REFERENCES "session" ("objkey") ON DELETE CASCADE
      );
    ]],
    delete = 'DELETE FROM collab WHERE entity = ?;',
    insert = 'INSERT INTO collab (entity, session_id) VALUES (?, ?);',
    selectAll = 'SELECT entity, session_id FROM collab;'
  }
}

local stmts = {
  { stmt = "insertSessionStmt", sql = entity.session.insert },
  { stmt = "deleteSessionStmt", sql = entity.session.delete },
  { stmt = "getSessionsStmt", sql = entity.session.selectAll },
  { stmt = "deleteMemberStmt", sql = entity.member.delete },
  { stmt = "insertMemberStmt", sql = entity.member.insert },
  { stmt = "getMemberStmt", sql = entity.member.select },
  { stmt = "getMembersStmt", sql = entity.member.selectAll },
  { stmt = "addConsumerStmt", sql = entity.consumer.insert },
  { stmt = "deleteConsumerStmt", sql = entity.consumer.delete },
  { stmt = "getConsumersStmt", sql = entity.consumer.selectAll },
  { stmt = "addObserverStmt", sql = entity.observer.insert },
  { stmt = "deleteObserverStmt", sql = entity.observer.delete },
  { stmt = "getObserversStmt", sql = entity.observer.selectAll },
  { stmt = "addCollabStmt", sql = entity.collab.insert },
  { stmt = "deleteCollabStmt", sql = entity.collab.delete },
  { stmt = "getCollabsStmt", sql = entity.collab.selectAll }
}

local function open(filename)
  local db, errCode, errMsg = sqlite.open(filename)
  if (not db) then
    log:failure(msg.openDB:tag({
      filename = filename,
      errCode = errCode
    }))
  end
  return db
end

local function createTables(conn)
  for entity, sql in pairs(entity) do
    conn:exec(sql.create)
  end
end

function DBSession:__init()
  self.conn = open(self.dbPath)
  createTables(self.conn)

  for _, s in ipairs(stmts) do
    local res, emsg = self.conn:prepare(s.sql)
    if (res) then
      self[s.stmt] = res
    else
      log:failure(msg.prepareDB:tag({
        sql = s.sql,
        errCode = emsg
      }))
    end
  end
end

function DBSession:close()
  if (self.conn) then
    for _, s in ipairs(stmts) do
      local errCode = self[s.stmt]:finalize()
      if (errCode ~= sqlite.OK) then
        log:failure(msg.finalizeDB:tag({
          stmt = s.stmt,
          errCode = errCode
        }))
      end      
    end
    if (self.conn:close() ~= sqlite.OK) then
      return false
    end
  end
  return true
end

function DBSession:addSession(objkey, creator)
  self.insertSessionStmt:bind_values(objkey, creator)
  self.insertSessionStmt:step()
  self.insertSessionStmt:reset()
end

function DBSession:delSession(objkey)
  self.deleteSessionStmt:bind_values(objkey)
  local res = self.deleteSessionStmt:step()
  self.deleteSessionStmt:reset()
  if (res ~= sqlite.DONE) then
    return false
  end
  return true
end

function DBSession:getSessions()
  local sessions = {}
  for row in self.getSessionsStmt:nrows() do
    sessions[row.objkey] = row.creator
  end
  self.getSessionsStmt:reset()
  return sessions
end

function DBSession:delMember(sessionId, name)
  self.deleteMemberStmt:bind_values(sessionId, name)
  local res = self.deleteMemberStmt:step()
  self.deleteMemberStmt:reset()
  if (res ~= sqlite.DONE) then
    return false
  end
  return true
end

function DBSession:addMember(sessionId, name, ior, owner)
  self.insertMemberStmt:bind_values(name, ior, owner, sessionId)
  self.insertMemberStmt:step()
  self.insertMemberStmt:reset()
end

function DBSession:getMember(sessionId, name)
  self.getMemberStmt:bind_values(sessionId, name)
  self.getMemberStmt:step()
  local member = self.getMemberStmt:get_named_values()
  self.getMemberStmt:reset()
  return member
end

function DBSession:getMembers(sessionId)
  self.getMembersStmt:bind_values(sessionId)
  local members = {}
  for row in self.getMembersStmt:nrows() do
    members[#members+1] = {
      name = row.name,
      owner = row.owner,
      ior = row.ior
    }
  end
  self.getMembersStmt:reset()  
  return members
end

function DBSession:addConsumer(sessionId, ior, owner)
  self.addConsumerStmt:bind_values(sessionId, ior, owner)
  self.addConsumerStmt:step()
  local id = self.conn:last_insert_rowid()
  self.addConsumerStmt:reset()
  return id
end

function DBSession:delConsumer(sessionId, cookie)
  self.deleteConsumerStmt:bind_values(sessionId, cookie)
  local res = self.deleteConsumerStmt:step()
  self.deleteConsumerStmt:reset()
  if (res ~= sqlite.DONE) then
    return false
  end
  return true
end

function DBSession:getConsumers(sessionId)
  self.getConsumersStmt:bind_values(sessionId)
  local consumers = {}
  for row in self.getConsumersStmt:nrows() do
    consumers[row.id] = {
      ior = row.ior,
      owner = row.owner
    }
  end
  self.getConsumersStmt:reset()
  return consumers
end

function DBSession:addObserver(sessionId, ior, owner)
  self.addObserverStmt:bind_values(sessionId, ior, owner)
  self.addObserverStmt:step()
  local observerId = self.conn:last_insert_rowid()
  self.addObserverStmt:reset()
  return observerId
end

function DBSession:delObserver(sessionId, cookie)
  self.deleteObserverStmt:bind_values(sessionId, cookie)
  local res = self.deleteObserverStmt:step()
  self.deleteObserverStmt:reset()
  if (res ~= sqlite.DONE ) then
    return false
  end
  return true
end

function DBSession:getObservers(sessionId)
  self.getObserversStmt:bind_values(sessionId)
  local observers = {}
  for row in self.getObserversStmt:nrows() do
    observers[row.id] = {
      ior = row.ior,
      owner= row.owner
    }
  end
  self.getObserversStmt:reset()
  return observers
end

function DBSession:addCollab(entity, sessionId)
  self.addCollabStmt:bind_values(entity, sessionId)
  self.addCollabStmt:step()
  self.addCollabStmt:reset()
end

function DBSession:delCollab(entity)
  self.deleteCollabStmt:bind_values(entity)
  local res = self.deleteCollabStmt:step()
  self.deleteCollabStmt:reset()
  if (res ~= sqlite.DONE ) then
    return false
  end
  return true
end

function DBSession:getCollabs()
  local collabs = {}
  for row in self.getCollabsStmt:nrows() do
    collabs[row.entity] = row.session_id
  end
  self.getCollabsStmt:reset()
  return collabs
end

return DBSession
