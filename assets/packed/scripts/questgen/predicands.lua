require("/scripts/util.lua")
require("/scripts/set.lua")
require("/scripts/spawnPoint.lua")

QuestPredicands = {}
QuestPredicands.Player = createClass("Player")
QuestPredicands.UnbornNpc = createClass("UnbornNpc")
QuestPredicands.NullEntity = createClass("NullEntity")
QuestPredicands.Entity = createClass("Entity")

function QuestPredicands.Entity:init(context, entityId, uniqueId)
  self.context = context
  self._entityId = entityId
  self._uniqueId = uniqueId
end

function QuestPredicands.Entity:position()
  if self._entityId and world.entityExists(self._entityId) then
    return world.entityPosition(self._entityId)
  end
  assert(self._uniqueId)
  -- If this entity has no uniqueId and doesn't exist, the QuestContext should
  -- have removed this entity from consideration already.
  return world.findUniqueEntity(self._uniqueId):result()
end

function QuestPredicands.Entity:setUsed(used)
  if self.context then
    self.context:markEntityUsed(self, used)
  end
end

function QuestPredicands.Entity:entityId()
  if self._entityId and not world.entityExists(self._entityId) then
    self._entityId = nil
  end
  if self._uniqueId and not self._entityId then
    self._entityId = world.loadUniqueEntity(self._uniqueId)
    if not world.entityExists(self._entityId) then
      self._entityId = nil
    end
  end
  return self._entityId
end

function QuestPredicands.Entity:uniqueId()
  return self._uniqueId
end

function QuestPredicands.Entity:setUniqueId(uniqueId)
  self._uniqueId = uniqueId
  world.setUniqueId(self._entityId, uniqueId)
  self.context:entityBecameUnique(self, uniqueId)
end

function QuestPredicands.Entity:exists()
  if self._entityId and world.entityExists(self._entityId) then
    return true
  end
  if self._uniqueId then
    return world.findUniqueEntity(self._uniqueId):result() ~= nil
  end
  return false
end

function QuestPredicands.Entity:entityType()
  if not self._type then
    local entityId = self:entityId()
    if not entityId then return nil end
    self._type = world.entityType(entityId)
  end
  return self._type
end

function QuestPredicands.Entity:entityName()
  local entityId = self:entityId()
  if not entityId then return nil end
  return world.entityName(entityId)
end

function QuestPredicands.Entity:entitySpecies()
  local entityId = self:entityId()
  if not entityId then return nil end
  return world.entitySpecies(entityId)
end

function QuestPredicands.Entity:setLabel(label)
  self._label = label
end

function QuestPredicands.Entity:label()
  return self._label
end

function QuestPredicands.Entity:callScript(...)
  local entityId = self:entityId()
  if not entityId then return nil end
  return world.callScriptedEntity(self:entityId(), ...)
end

function QuestPredicands.Entity:hasRelationship(relationName, converse, otherEntity)
  if not otherEntity:uniqueId() then
    return false
  end
  return self:callScript("hasRelationship", relationName, converse, otherEntity:uniqueId())
end

function QuestPredicands.Entity:getRelationships(relationName, converse)
  return self:callScript("getRelationships", relationName, converse) or {}
end

function QuestPredicands.Entity:toString()
  if self:label() then
    return self:label()
  end
  local id = self._uniqueId or self._entityId
  return getmetatable(self).className.."{"..id.."}"
end

QuestPredicands.TemporaryNpc = createClass("TemporaryNpc")

function QuestPredicands.TemporaryNpc:init(species, typeName, spawnRegion)
  self.species = species
  self.typeName = typeName
  self.spawnRegion = spawnRegion
end

function QuestPredicands.TemporaryNpc:spawn()
  local seed = generateSeed()
  local overrides = {
      damageTeamType = "assistant",
      scriptConfig = {
        behaviorConfig = {
          beamOutWhenNotInUse = true
        },
        questGenerator = {
          pools = {},
          enableParticipation = false
        }
      }
    }
  local entityId = world.spawnNpc(entity.position(), self.species, self.typeName, world.threatLevel(), seed, overrides)
  local boundBox = world.callScriptedEntity(entityId, "mcontroller.boundBox")
  world.callScriptedEntity(entityId, "mcontroller.setPosition", findSpaceInRect(self.spawnRegion, boundBox) or rect.center(self.spawnRegion))
  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
  return entityId
end

QuestPredicands.Item = createClass("Item")

-- Represents just a single item and its parameters, hence no 'count'
function QuestPredicands.Item:init(item, parameters)
  if type(item) == "table" then
    assert(type(item.name) == "string")
    assert(parameters == nil)
    self.itemName = item.name
    self.parameters = item.parameters or {}
  else
    assert(type(item) == "string")
    self.itemName = item
    self.parameters = parameters or {}
  end
end

function QuestPredicands.Item:toJson()
  return {
      name = self.itemName,
      parameters = self.parameters
    }
end

function QuestPredicands.Item:descriptor(count)
  return {
      name = self.itemName,
      count = count or 1,
      parameters = self.parameters
    }
end

function QuestPredicands.Item:type()
  return root.itemType(self.itemName)
end

function QuestPredicands.Item:price()
  local itemConfig = root.itemConfig(self.itemName)
  return itemConfig.config.price or 0
end

function QuestPredicands.Item:itemTags()
  local itemConfig = root.itemConfig(self.itemName)
  return itemConfig.config.itemTags or {}
end

function QuestPredicands.Item:objectTags()
  local itemConfig = root.itemConfig(self.itemName)
  return itemConfig.config.colonyTags or {}
end

function QuestPredicands.Item:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  return self.itemName == other.itemName and compare(self.parameters, other.parameters)
end

QuestPredicands.ItemTag = createClass("ItemTag")

function QuestPredicands.ItemTag:init(tag, name, type)
  self.tag = tag
  self.name = name
  self._type = type
end

function QuestPredicands.ItemTag.fromJson(json)
  return QuestPredicands.ItemTag.new(json.tag, json.name, json.type)
end

function QuestPredicands.ItemTag:type()
  return self._type
end

function QuestPredicands.ItemTag:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  return self.tag == other.tag
end

QuestPredicands.Recipe = createClass("Recipe")
function QuestPredicands.Recipe:init(json)
  self.output = json.output
  self.inputs = util.filter(json.input, function (itemDescriptor)
      -- Don't include money in recipes
      return itemDescriptor.name ~= "money"
    end)

  self.groups = {}
  for _,group in ipairs(json.groups) do
    self.groups[group] = true
  end
end

function QuestPredicands.Recipe:hasGroup(group)
  return self.groups[group] or false
end

local function equalItemDesc(a, b)
  return a.name == b.name and a.count == b.count
end

function QuestPredicands.Recipe:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  if not equalItemDesc(self.output, other.output) then
    return false
  end
  if #self.inputs ~= #other.inputs then return false end
  for i, input in ipairs(self.inputs) do
    if not equalItemDesc(input, other.inputs[i]) then
      return false
    end
  end
  return true
end

QuestPredicands.ItemList = createClass("ItemList")

function QuestPredicands.ItemList:init(descriptors)
  self.itemsByName = {}
  for _,item in ipairs(descriptors or {}) do
    -- O(N^2) if the input list has multiple descriptors with the same name
    -- but different parameters. Not expected to be a common case though.
    self:add(item)
  end
end

function QuestPredicands.ItemList:toJson()
  return self:descriptors()
end

function QuestPredicands.ItemList:descriptors()
  local descriptors = jarray()
  for itemName, descriptorList in pairs(self.itemsByName) do
    for _,descriptor in pairs(descriptorList) do
      descriptors[#descriptors+1] = descriptor
    end
  end
  return descriptors
end

function QuestPredicands.ItemList.fromJson(itemDescriptors)
  return QuestPredicands.ItemList.new(itemDescriptors)
end

function QuestPredicands.ItemList:add(newDescriptor, multiplier)
  if type(newDescriptor) == "string" then
    newDescriptor = { name = newDescriptor }
  end
  newDescriptor = {
      name = newDescriptor.name,
      count = (newDescriptor.count or 1) * (multiplier or 1),
      parameters = newDescriptor.parameters or {}
    }
  
  self.itemsByName[newDescriptor.name] = self.itemsByName[newDescriptor.name] or {}
  local descriptorList = self.itemsByName[newDescriptor.name]
  for i,descriptor in ipairs(descriptorList) do
    if compare(descriptor.parameters, newDescriptor.parameters) then
      descriptor.count = descriptor.count + newDescriptor.count
      if descriptor.count <= 0 then
        table.remove(descriptorList, i)
      end
      return
    end
  end

  if newDescriptor.count > 0 then
    local descriptorList = self.itemsByName[newDescriptor.name]
    descriptorList[#descriptorList+1] = newDescriptor
  end
end

function QuestPredicands.ItemList:count(searchDescriptor)
  if type(searchDescriptor) == "string" then
    searchDescriptor = { name = searchDescriptor }
  end
  searchDescriptor = {
      name = searchDescriptor.name,
      parameters = searchDescriptor.parameters or {}
    }

  self.itemsByName[searchDescriptor.name] = self.itemsByName[searchDescriptor.name] or {}
  local descriptorList = self.itemsByName[searchDescriptor.name]
  for i,descriptor in ipairs(descriptorList) do
    if compare(descriptor.parameters, searchDescriptor.parameters) then
      return descriptor.count
    end
  end
  return 0
end

function QuestPredicands.ItemList:contains(descriptor)
  return self:count(descriptor) >= (descriptor.count or 1)
end

function QuestPredicands.ItemList:price()
  local price = 0
  for itemName, descriptorList in pairs(self.itemsByName) do
    for _,descriptor in pairs(descriptorList) do
      local itemConfig = root.itemConfig(descriptor)
      price = price + (itemConfig.config.price or 0)
    end
  end
  return price
end

function QuestPredicands.ItemList:merged(other)
  if getmetatable(other) ~= getmetatable(self) then
    error("Cannot merge ItemList with "..tostring(other))
  end
  local merged = QuestPredicands.ItemList.new(self:descriptors())
  for _,descriptor in pairs(other:descriptors()) do
    merged:add(descriptor)
  end
  return merged
end

function QuestPredicands.ItemList:mergeSubtract(other)
  if getmetatable(other) ~= getmetatable(self) then
    error("Cannot merge ItemList with "..tostring(other))
  end
  local merged = QuestPredicands.ItemList.new(self:descriptors())
  for _,descriptor in pairs(other:descriptors()) do
    merged:add(descriptor, -1)
  end
  return merged
end

function QuestPredicands.ItemList:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  for _,descriptor in pairs(self:descriptors()) do
    if not other:contains(descriptor) then
      return false
    end
  end
  for _,descriptor in pairs(other:descriptors()) do
    if not self:contains(descriptor) then
      return false
    end
  end
  return true
end

function QuestPredicands.ItemList:toString()
  return self.className .. util.tableToString(self:descriptors())
end

QuestPredicands.Location = createClass("Location")

function QuestPredicands.Location:init(region, name, uniqueId, tags)
  self.region = region
  self.name = name
  self.uniqueId = uniqueId
  self.tags = tags or {}
end

QuestPredicands.NpcType = createClass("NpcType")

function QuestPredicands.NpcType:init(json)
  self.name = json.name
  self.species = json.species
  self.typeName = json.typeName
  self.parameters = json.parameters or {}
  self.seed = json.seed

  if self.seed and not self.name then
    local npcVariant = root.npcVariant(self.species, self.typeName, self.parameters.level or 1, self.seed, self.parameters)
    self.name = npcVariant.humanoidIdentity.name
  end
end

function QuestPredicands.NpcType:portrait(seed)
  seed = seed or self.seed or generateSeed()
  return root.npcPortrait("full", self.species, self.typeName, self.parameters.level or 1, seed, self.parameters)
end

function QuestPredicands.NpcType:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  return compare(self, other)
end

QuestPredicands.MonsterType = createClass("MonsterType")

function QuestPredicands.MonsterType:init(json)
  self.name = json.name
  self.typeName = json.typeName
  self.parameters = json.parameters or {}
end

function QuestPredicands.MonsterType:portrait(seed)
  local parameters = shallowCopy(self.parameters)
  parameters.seed = seed or parameters.seed
  return root.monsterPortrait(self.typeName, parameters)
end

function QuestPredicands.MonsterType:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  return compare(self, other)
end

QuestPredicands.TagSet = createClass("TagSet")

function QuestPredicands.TagSet:init(json)
  self.tags = set.new(json)
end

function QuestPredicands.TagSet:equals(other)
  if getmetatable(other) ~= getmetatable(self) then return false end
  return set.equals(self.tags, other.tags)
end

function QuestPredicands.TagSet:values()
  return set.values(self.tags)
end
