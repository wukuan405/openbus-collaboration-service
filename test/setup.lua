-- -*- coding: iso-8859-1-unix -*-

require "openbus.test.configs"
local ComponentContext = require "scs.core.ComponentContext"
local openbus = require "openbus"
local oil = require "oil"
local idl = require "openbus.services.collaboration.idl"
local CollaborationRegistryFacet = idl.const.CollaborationRegistryFacet
local SessionRegistryFacet = idl.const.SessionRegistryFacet

function setup()
  local orb = openbus:initORB()
  idl.loadto(orb)
  local busCtx = orb.OpenBusContext
  local conn = busCtx:createConnection(bushost, busport)
  conn:loginByPassword(user, password, "testing")
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
    oil.sleep(1)
    offers = rgs:findServices(props)
  end
  local component = offers[1].service_ref
  local facet1 = component:getFacetByName(CollaborationRegistryFacet)
  local facet2 = component:getFacetByName(SessionRegistryFacet)
  local registry = facet1:__narrow()
  local sessionreg = facet2:__narrow()

  return {
    orb = orb,
    idl = idl,
    openbus = openbus,
    conn = conn,
    rgs = rgs,
    collaborationRegistry = registry,
    sessionRegistry = sessionreg,
    componentCtx = ComponentContext,
    busCtx = busCtx,
    bushost = bushost,
    busport = busport,
    user = user,
    password = password
  }
end
