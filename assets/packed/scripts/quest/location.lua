require "/scripts/rect.lua"
require "/scripts/set.lua"

Location = {}
Location.__index = Location

function Location.new(uniqueId, locationType, region, optionalTags)
  local self = setmetatable({}, Location)
  self.uniqueId = uniqueId
  self.type = locationType
  self.region = region

  local locationConfig = Location.getLocationTypeConfig(locationType)
  self.name = locationConfig.name
  self.tags = optionalTags or locationConfig.tags
  self.range = locationConfig.range

  return self
end

function Location.fromJson(json)
  return Location.new(json.uniqueId, json.type, json.region, json.tags)
end

function Location:toJson()
  return {
      uniqueId = self.uniqueId,
      type = self.type,
      region = self.region,
      tags = self.tags,
      range = self.range
    }
end

local function locationKey(location)
  return location.uniqueId
end

local function locationTable()
  return PropertyTable.new("questLocations", locationKey, Location.toJson, Location.fromJson)
end

local function locationTagTable(tag)
  return PropertyTable.new("questLocationTag." .. tag, locationKey, Location.toJson, Location.fromJson)
end

function Location:register()
  locationTable():add(self)
  for _,tag in pairs(self.tags) do
    locationTagTable(tag):add(self)
  end
end

function Location:unregister()
  locationTable():remove(self)
  for _,tag in pairs(self.tags) do
    locationTagTable(tag):remove(self)
  end
end

function Location:isRegistered()
  if self.tags and #self.tags > 0 then
    return locationTagTable(self.tags[1]):contains(self)
  else
    return locationTable():contains(self)
  end
end

function Location.getLocationTypeConfig(locationType)
  return root.assetJson("/quests/generated/locations.config:" .. locationType)
end

function Location.search(position, optionalTags, optionalMinDistance, optionalMaxDistance)
  local locations = locationTable()

  local options = nil
  if optionalTags and #optionalTags > 0 then
    for _,tag in pairs(optionalTags or {}) do
      if options == nil then
        options = locationTagTable(tag):keySet()
      else
        options = set.intersection(options, locationTagTable(tag):keySet())
      end
    end
  else
    options = locations:keySet()
  end

  options = util.toList(util.mapWithKeys(options, function (uniqueId)
      return locations:get(uniqueId)
    end))

  return util.filter(options, function (location)
      local entityExists = world.findUniqueEntity(location.uniqueId):result()
      if not entityExists then
        location:unregister()
        return false
      end

      local locationPos = rect.center(location.region)
      local distance = world.magnitude(position, locationPos)

      local range = location.range or optionalMaxDistance
      if optionalMaxDistance and optionalMaxDistance < range then
        range = optionalMaxDistance
      end

      return (not range or distance <= range) and distance >= (optionalMinDistance or 0)
    end)
end

PropertyTable = {}
PropertyTable.__index = PropertyTable

function PropertyTable.new(propertyName, keyFunc, jsonConverter, constructor)
  local self = setmetatable({}, PropertyTable)
  self.propertyName = propertyName
  self.keyFunc = keyFunc
  self.jsonConverter = jsonConverter or function (x) return x end
  self.constructor = constructor or function (x) return x end
  return self
end

function PropertyTable:getProperty()
  return world.getProperty(self.propertyName) or jobject()
end

function PropertyTable:add(record)
  local table = self:getProperty()
  table[self.keyFunc(record)] = self.jsonConverter(record)
  world.setProperty(self.propertyName, table)
end

function PropertyTable:remove(record)
  local table = self:getProperty()
  table[self.keyFunc(record)] = nil
  world.setProperty(self.propertyName, table)
end

function PropertyTable:contains(record)
  return self:containsKey(self.keyFunc(record))
end

function PropertyTable:containsKey(key)
  local table = self:getProperty()
  return table[key] ~= nil
end

function PropertyTable:get(key)
  return self.constructor(self:getProperty()[key])
end

function PropertyTable:keySet()
  return self:getProperty()
end
