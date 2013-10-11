-- -*- coding: iso-8859-1-unix -*-

require "openbus.test.configs"
local ComponentContext = require "scs.core.ComponentContext"
local openbus = require "openbus"
local idl = require "openbus.services.collaboration.idl"
local CollaborationRegistryFacet = idl.const.CollaborationRegistryFacet
local putsInstall = os.getenv("PUTS").."/install"

function setup()
  local orb = openbus:initORB()
  orb:loadidlfile(putsInstall.."/idl/collaboration.idl")
  local busCtx = orb.OpenBusContext
  local conn = busCtx:createConnection(bushost, busport)
  conn:loginByPassword(user, password)
  busCtx:setDefaultConnection(conn)

  local rgs = busCtx:getOfferRegistry()
  local props = {
    {
      name = "openbus.component.name", 
      value = "CollaborationService"
    }
  }
  local offers = rgs:findServices(props)
  while (not (#offers > 0 and not offers[1].service_ref:_non_existent())) do
    print("Waiting collaboration service...")
    socket.sleep(1)
    offers = rgs:findServices(props)
  end
  local component = offers[1].service_ref
  local facet = component:getFacetByName(CollaborationRegistryFacet)
  local registry = facet:__narrow()

  return {
    orb = orb,
    idl = idl,
    openbus = openbus,
    conn = conn,
    rgs = rgs,
    collaborationRegistry = registry,
    componentCtx = ComponentContext,
    busCtx = busCtx,
    bushost = bushost,
    busport = busport,
    user = user,
    password = password
  }
end
