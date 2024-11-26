require "/scripts/versioningutils.lua"

function update(data)
  local universeMaps = jobject()

  data.universeMap = {}
  for _,p in pairs(data.bookmarks) do
    local serverUuid = p[1]
    local bookmarks = p[2]
    local universeMap = {
      systems = jarray(),
      teleportBookmarks = jarray()
    }

    for _,bookmark in pairs(bookmarks) do
      if bookmark.type == "teleport" then
        table.insert(universeMap.teleportBookmarks, toTeleportBookmark(bookmark))
      else
        local location = systemCoordinate(worldIdCoordinate(bookmark.targetWorld)).location
        local systemMap
        local existing = find(universeMap.systems, function(s) return compare(s[1], location) end)
        if existing then
          systemMap = existing[2]
        else
          systemMap = {
            mappedPlanets = jarray(),
            mappedObjects = jobject(),
            bookmarks = jarray()
          }
          table.insert(universeMap.systems, {location, systemMap})
        end

        table.insert(systemMap.bookmarks, toOrbitBookmark(bookmark))
        local planet = planetCoordinate(worldIdCoordinate(bookmark.targetWorld))
        if find(systemMap.mappedPlanets, function(p) return compare(planet, p) end) == nil then
          table.insert(systemMap.mappedPlanets, planet)
        end
      end
    end

    data.universeMap[serverUuid] = universeMap
  end

  data.bookmarks = nil

  return data
end

function toTeleportBookmark(oldBookmark)
  return {
    target = {oldBookmark.targetWorld, oldBookmark.spawnTarget},
    targetName = oldBookmark.planetName,
    bookmarkName = oldBookmark.name,
    icon = oldBookmark.icon
  }
end

function toOrbitBookmark(oldBookmark)
  return {
    target = worldIdCoordinate(oldBookmark.targetWorld),
    targetName = oldBookmark.planetName,
    bookmarkName = oldBookmark.name,
    icon = oldBookmark.icon
  }
end

function systemCoordinate(coordinate)
  local system = copy(coordinate)
  system.planet = 0
  system.satellite = 0
  return system
end

function planetCoordinate(coordinate)
  local planet = copy(coordinate)
  planet.satellite = 0
  return planet
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
