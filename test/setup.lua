-- -*- coding: iso-8859-1-unix -*-

require "openbus.test.configs"
local ComponentContext = require "scs.core.ComponentContext"
local openbus = require "openbus"
local idl = require "openbus.services.collaboration.idl"
local CollaborationRegistryFacet = idl.const.CollaborationRegistryFacet
local putsInstall = os.getenv("PUTS").."/install"

function setup()
  local orb = openbus:initORB()
  orb:loadidlfile(putsInstall.."/idl/collaboration-service-1.0/collaboration.idl")
  local busCtx = orb.OpenBusContext
  local conn = busCtx:createConnection(bushost, busport)
  conn:loginByPassword(user, password)
  busCtx:setDefaultConnection(conn)

  local rgs = busCtx:getOfferRegistry()
  local offers = rgs:findServices(
    {
      {
        name = "openbus.component.name", 
        value = "CollaborationService"
      }
    })

  local facet = offers[1].service_ref:getFacetByName(CollaborationRegistryFacet)
  local registry = facet:__narrow()

  return {
    orb = orb,
    idl = idl,
    openbus = openbus,
    conn = conn,
    rgs = rgs,
    collaborationRegistry = registry,
    componentCtx = ComponentContext
  }
end
