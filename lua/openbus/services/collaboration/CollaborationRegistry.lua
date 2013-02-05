-- -*- coding: iso-8859-1-unix -*-
-- $Id$

local _G = require "_G"
local ipairs = _G.ipairs
local pairs = _G.pairs
local rawset = _G.rawset

local cothread = require "cothread"
cothread.plugin(require "cothread.plugin.socket")
local time = cothread.now

local uuid = require "uuid"
local newid = uuid.new

local openbus = require "openbus"
local newthread = openbus.newthread

local autotable = require "openbus.util.autotable"
local newautotab = autotable.create
local delautotab = autotable.remove
local log = require "openbus.util.logger"
local oo = require "openbus.util.oo"
local class = oo.class
local sysex = require "openbus.util.sysex"
local NO_PERMISSION = sysex.NO_PERMISSION
local BAD_PARAM = sysex.BAD_PARAM

local idl = require "openbus.core.idl"
local InvalidLoginMinorCode = idl.const.services.access_control.InvalidLoginCode
local InvalidLoginsRepId = idl.types.services.access_control.InvalidLogins

local msg = require "openbus.services.collaboration.messages"
local idl = require "openbus.services.collaboration.idl"
local NameInUseException = idl.throw.NameInUse
local CollaborationSessionInterface = idl.types.CollaborationSession
local EventChannelInterface = idl.types.EventChannel
local CollaborationObserverInterface = idl.types.CollaborationObserver
local EventConsumerInterface = idl.types.EventConsumer
local CollaborationRegistryInterface = idl.types.CollaborationRegistry
local CollaborationRegistryFacetName = idl.const.CollaborationRegistryFacet
local CollaborationServiceName = idl.const.CollaborationServiceName

local function callerId(conn)
	local callers = conn:getCallerChain().callers
	return callers[#callers].id
end

local function logCallError(objref, opname, ...)
	local ok, errmsg = pcall(objref[opname], objref, ...)
	if not ok then
		log:exception(msg.AsyncCallError:tag{
			operation = opname,
			error = errmsg,
		})
	end
end

local function asyncGroupCall(entries, opname, ...)
	for _, entry in pairs(entries) do
		newthread(logCallError, entry.objref, opname, ...)
	end
end

------------------------------------------------------------------------------
-- Faceta CollaborationRegistry
------------------------------------------------------------------------------

local EventChannel = class{ __type = EventChannelInterface }

-- IDL operations

function EventChannel:subscribe(consumer)
	local session = self.session
	local cookie = #session.consumers+1
	session:addEntry("consumers", cookie, consumer)
	return cookie
end

function EventChannel:unsubscribe(cookie)
	return self.session:removeEntry("consumers", cookie)
end

function EventChannel:push(...)
	asyncGroupCall(self.session.consumers, "push", ...)
end



local CollaborationSession = class{ __type = CollaborationSessionInterface }

-- local operations

function CollaborationSession:__init()
	if self.members == nil then self.members = {} end
	if self.observers == nil then self.observers = {} end
	if self.consumers == nil then self.consumers = {} end
	self.channel = EventChannel(self.channel)
end

function CollaborationSession:checkAutoDestroy()
	if next(self.members) == nil
	and next(self.observers) == nil
	and next(self.consumers) == nil
	and self.creator == nil
	then
		self:destroy()
	end
end

function CollaborationSession:addEntry(group, key, objref)
	local registry = self.registry
	local login = callerId(registry.connection)
	local entry = {
		login = login,
		ior = tostring(objref),
	}
	local sessionId = self.__objkey
	local database = registry[group]
	assert(database:setentryfield(sessionId, key, entry))
	entry.objref = objref
	local subscription = registry.subscription
	local ok, errmsg = pcall(subscription.watchLogin, subscription, login)
	if ok then
		registry.login2Session[login][self][key] = group
		self[group][key] = entry
	else
		database:setentryfield(sessionId, key, nil) -- rollback database change
		NO_PERMISSION{ minor = InvalidLoginMinorCode }
		log:exception(msg.UnableToWatchLogin:tag{
			login = login,
			error = errmsg,
		})
	end
end

function CollaborationSession:removeEntry(group, key, cancelforget)
	local entries = self[group]
	local entry = entries[key]
	if entry ~= nil then
		local registry = self.registry
		local database = registry[group]
		if database:setentryfield(self.__objkey, key, nil) then
			local login = entry.login
			local subscription = registry.subscription
			if not cancelforget then
				local ok, errmsg = pcall(subscription.forgetLogin, subscription, login)
				if not ok then
					log:exception(msg.UnableToStopWatchingLogin:tag{
						login = login,
						error = errmsg,
					})
				end
			end
			delautotab(login2Session, login, self, key)
			entries[name] = nil
			self:checkAutoDestroy()
			return true
		end
	end
	return false
end

-- IDL operations

function CollaborationSession:destroy()
	local id = self.__objkey
	local registry = self.registry
	registry.members:removeentry(id)
	registry.observers:removeentry(id)
	registry.consumers:removeentry(id)
	registry.creators:removeentry(id)
	local orb = self.orb
	orb:deactivate(self.channel)
	orb:deactivate(self)
	asyncGroupCall(self.observers, "destroyed")
end

function CollaborationSession:addMember(name, member)
	if member == nil then
		BAD_PARAM{}
	end
	if self.members[name] ~= nil then
		NameInUseException{ name = name }
	end
	self:addEntry("members", name, member)
	asyncGroupCall(self.observers, "memberAdded", name, member)
end

function CollaborationSession:removeMember(name)
	local success = self:removeEntry("members", name)
	asyncGroupCall(self.observers, "memberRemoved", name)
	return success
end

function CollaborationSession:getMember(name)
	local entry = self.members[name]
	if entry ~= nil then
		return entry.objref
	end
end

function CollaborationSession:getMembers()
	local seq = {}
	for name, entry in pairs(self.members) do
		seq[#seq+1] = {
			name = name,
			member = entry.objref,
		}
	end
	return seq
end


function CollaborationSession:subscribeObserver(observer)
	if observer == nil then
		BAD_PARAM{}
	end
	local cookie = #self.observers+1
	self:addEntry("observers", cookie, observer)
	return cookie
end

function CollaborationSession:unsubscribeObserver(cookie)
	return self:removeEntry("observers", cookie)
end



local Group2Interface = {
	members = "::scs::core::IComponent",
	observers = CollaborationObserverInterface,
	consumers = EventConsumerInterface,
}



local CollaborationObserver = {
	
}




local CollaborationRegistry = {
	__type = CollaborationRegistryInterface,
	__objkey = CollaborationRegistryFacetName,
}

-- local operations

function CollaborationRegistry:__init(data)
	local conn = data.connection
	local database = data.database
	local prvkey = data.privateKey
	local login2Session = newautotab()
	
	self.connection = conn
	self.database = database
	self.login2Session = login2Session
	
	local observer = {
		entityLogout = function(_, login)
			local sessions = login2Session[login.id]
			if sessions ~= nil then
				for session, keys in pairs(sessions) do
					if keys == "creator" then
						delautotab(login2Session, login.id, session)
						self.creators:removeentry(session.__objkey)
						session.creator = nil
						session:checkAutoDestroy()
					else
						for key, group in pairs(keys) do
							session:removeEntry(group, key, "cancelforget")
						end
					end
				end
			else
				log:exception(msg.GotUnsolicitedLogoutNotification:tag{
					login = login.id,
					entity = login.entity,
				})
			end
		end
	}
	
	function conn.onInvalidLogin()
		conn:loginByCertificate(CollaborationServiceName, prvkey)
		local rgs = conn.orb.OpenBusContext:getOfferRegistry();
		local ok, res = pcall(rgs.registerService, rgs, self.context.IComponent, {})
		if not ok then
			ServiceFailure{
				message = msg.UnableToRegisterService:tag{ error = res },
			}
			return false
		end
		local subscription = conn.orb.OpenBusContext:getLoginRegistry()
			:subscribeObserver(observer)
		local logins = {}
		for login in pairs(self.login2Session) do
			logins[#logins+1] = login
		end
		ok, res = pcall(subscription.watchLogins, subscription, logins)
		if not ok then
			if res._repid ~= InvalidLoginsRepId then
				ServiceFailure{
					message = msg.UnableToWatchMultipleLogins:tag{ error = res },
				}
			end
			for _, login in ipairs(res.loginIds) do
				self:entityLogout({id=login})
			end
		end
		self.subscription = subscription
		return "retry"
	end
	
	local membersDB = assert(database:gettable("Members"))
	local observersDB = assert(database:gettable("Observers"))
	local consumersDB = assert(database:gettable("Consumers"))
	local creatorDB = assert(database:gettable("Creators"))
	local orb = conn.orb
	for id, members in assert(membersDB:ientries()) do
		local creator = creatorDB:getentry(id)
		local session = CollaborationSession{
			registry = self,
			__objkey = id,
			members = members,
			observers = observersDB:getentry(id),
			consumers = consumersDB:getentry(id),
			creator = creator,
		}
		local login2Session = registry.login2Session
		if creator ~= nil then
			login2Session[creator][session] = "creator"
		end
		for group, interface in pairs(Group2Interface) do
			local entries = session[group]
			for key, entry in pairs(entries) do
				local login = entry.login
				entry.objref = orb:newproxy(entry.ior, nil, interface)
				login2Session[login][session][key] = group
			end
		end
		orb:newservant(session)
	end
	
	conn.onInvalidLogin() -- log to the bus and watch for all logins
end

-- IDL operations

function CollaborationRegistry:createCollaborationSession()
	local creator = callerId(self.connection)
	local id = newid("new")
	self.members:setentry(id, {})
	self.observers:setentry(id, {})
	self.consumers:setentry(id, {})
	self.creators:setentry(id, creator)
	return CollaborationSession{
		registry = self,
		__objkey = id,
		creator = creator,
	}
end



return {
	CollaborationRegistry = CollaborationRegistry,
}
