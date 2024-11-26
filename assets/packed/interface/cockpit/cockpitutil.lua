function existingBookmark(system, bookmark)
  for _,b in pairs(player.systemBookmarks(system)) do
    if compare(b.target, bookmark.target) then
      return b
    end
  end
end

function closestSystemInRange(position, systems, range)
  systems = util.filter(systems, function (s)
      return systemDistance(s, position) < range
    end)
  table.sort(systems, function(a, b)
      return systemDistance(a, position) < systemDistance(b, position)
    end)
  return systems[1]
end

function closestLocationInRange(position, parent, range, exclude)
  local locations = util.map(celestial.children(parent), function(p) return {"coordinate", p} end)
  local objectPositions = {}
  local objectOrbits = {}

  if compare(celestial.currentSystem(), coordinateSystem(parent)) then
    -- current system, use all current objects even temporary
    for _,uuid in pairs(celestial.systemObjects()) do
      local orbit = celestial.objectOrbit(uuid)
      if orbit then
        objectPositions[uuid] = celestial.orbitPosition(orbit)
      else
        objectPositions[uuid] = celestial.objectPosition(uuid)
      end
      table.insert(locations, {"object", uuid})
    end
  elseif parent.planet == 0 then
    -- another system, use permanent mapped objects
    for uuid,object in pairs(player.mappedObjects(parent)) do
      if celestial.objectTypeConfig(object.typeName).permanent then
        if object.orbit then
          objectPositions[uuid] = celestial.orbitPosition(object.orbit)
          table.insert(locations, {"object", uuid})
        end
      end
    end
  end
  -- include parent if it's a planet
  if parent.planet > 0 then
    table.insert(locations, {"coordinate", parent})
  end

  locations = util.filter(locations, function(location)
    if location[1] == "coordinate" then
      local parameters = celestial.planetParameters(location[2])
      if parameters and parameters.worldType == "Asteroids" then
        return false
      end
    end
    return true
  end)

  local distance = function(location, first)
    local second
    if location[1] == "coordinate" then
      second = celestial.planetPosition(location[2])
    elseif location[1] == "object" then
      second = objectPositions[location[2]]
    end

    return vec2.mag(vec2.sub(first, second))
  end
  locations = util.filter(locations, function(s)
      return distance(s, position) < range and not compare(s, exclude)
    end)
  table.sort(locations, function(a, b)
      return distance(a, position) < distance(b, position)
    end)
  return locations[1]
end

function planetDistance(planet, position)
  return vec2.mag(vec2.sub(position, celestial.planetPosition(planet)))
end

function systemDistance(system, position)
  return vec2.mag(vec2.sub(systemPosition(system), position))
end

function systemPosition(system)
  return {system.location[1], system.location[2]}
end

function objectPosition(system, uuid)
  if compare(celestial.currentSystem(), system) then
    return celestial.objectPosition(uuid)
  else
    local object = player.mappedObjects(system)[uuid]
    if object then
      return celestial.orbitPosition(object.orbit)
    end
  end
end

function locationCoordinate(location)
  return {
    location = location,
    planet = 0,
    satellite = 0
  }
end

function coordinatePlanet(coordinate)
  local planet = copy(coordinate)
  planet.satellite = 0
  return planet
end

function coordinateSystem(coordinate)
  local system = coordinatePlanet(coordinate)
  system.planet = 0
  return system
end


function newObjectBookmark(uuid, typeName)
  local parameters = celestial.objectTypeConfig(typeName).parameters;
  return {
    target = uuid,
    targetName = parameters.displayName,
    bookmarkName = "",
    icon = parameters.bookmarkIcon or ""
  }
end

function newPlanetBookmark(planet)
  local parameters = celestial.visitableParameters(planet)
  if parameters then
    return {
      target = planet,
      targetName = celestial.planetName(planet),
      bookmarkName = "",
      icon = parameters.typeName
    }
  end
end

function worldIdCoordinate(worldId)
  local parts = {}
  for p in string.gmatch(worldId, "-?[%a%d]+") do
    table.insert(parts, p)
  end
  if parts[1] == "CelestialWorld" then
    local coordinate = {
      location = {tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])},
      planet = tonumber(parts[5] or 0),
      satellite = tonumber(parts[6] or 0)
    }
    return coordinate
  end
end

function coordinateWorldId(coordinate)
  worldId = string.format("CelestialWorld:%s:%s:%s", coordinate.location[1], coordinate.location[2], coordinate.location[3])
  if coordinate.planet ~= 0 then
    worldId = string.format("%s:%s", worldId, coordinate.planet)
  end
  if coordinate.satellite ~= 0 then
    worldId = string.format("%s:%s", worldId, coordinate.satellite)
  end
  return worldId
end

function locationVisitable(location)
  if location[1] == "coordinate" then
    local parameters = celestial.planetParameters(location[2])
    if parameters and parameters.worldType == "GasGiant" then
      return false
    end
  end
  return true
end

celestialWrap = {}

function celestialWrap.objectWarpActionWorld(uuid)
  while true do
    local world = celestial.objectWarpActionWorld(uuid)
    if world ~= nil then
      return world
    end
    coroutine.yield()
  end
end

function celestialWrap.planetParameters(p)
  while true do
    local parameters = celestial.planetParameters(p)
    if parameters ~= nil then
      return parameters
    end
    coroutine.yield()
  end
end

function celestialWrap.visitableParameters(p)
  while true do
    local parameters = celestial.visitableParameters(p)
    -- visitableParameters can return nil if the planet isn't available (not generated/not fetched from master)
    -- or if the planet isn't visitable, planetParameters only returns nil if the planet isn't available 
    -- use planetParameters to see if the planet is available
    if celestial.planetParameters(p) ~= nil then
      return parameters
    end
    coroutine.yield()
  end
end

function celestialWrap.planetName(p)
  while true do
    local name = celestial.planetName(p)
    if name ~= nil then
      return name
    end
    coroutine.yield()
  end
end

function celestialWrap.children(p)
  while celestial.hasChildren(p) == nil do
    coroutine.yield()
  end
  return celestial.children(p)
end

function celestialWrap.scanSystems(region, includedTypes)
  while true do
    local systems = celestial.scanSystems(region, includedTypes)
    if celestial.scanRegionFullyLoaded(region) then
      return systems
    end
    coroutine.yield()
  end
end

function celestialWrap.scanConstellationLines(region)
  while true do
    local systems = celestial.scanConstellationLines(region)
    if celestial.scanRegionFullyLoaded(region) then
      return systems
    end
    coroutine.yield()
  end
end
