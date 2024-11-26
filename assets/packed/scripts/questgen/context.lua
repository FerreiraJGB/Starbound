require("/scripts/spawnPoint.lua")

QuestContext = createClass("QuestContext")
function QuestContext:init(queryPosition, queryRange)
  local nearbyEntities = world.entityQuery(queryPosition, queryRange, { includedTypes = {"object", "npc"} })
  self._queryPosition = queryPosition
  self._entities = {}
  self._uniqueEntities = {}
  self._usedEntities = {}
  for _,entityId in ipairs(nearbyEntities) do
    if not self:ignoreEntity(entityId) then
      local uniqueId = world.entityUniqueId(entityId)
      if uniqueId then
        self._uniqueEntities[uniqueId] = QuestPredicands.Entity.new(self, entityId, uniqueId)
      else
        self._entities[entityId] = QuestPredicands.Entity.new(self, entityId, nil)
      end
    end
  end
end

function QuestContext:ignoreEntity(entityId)
  if not world.isNpc(entityId) then
    return false
  end
  -- Ignore NPCs that aren't enabled for quest participation. If they weren't
  -- configured to enable being participants in quests, the quest generator
  -- won't be able to assign them behavior overrides.
  -- Plus, a quest that gives a cake to a hostile NPC doesn't make sense anyway.
  return not world.callScriptedEntity(entityId, "participateInNewQuests")
end

function QuestContext:markEntityUsed(entity, used)
  if used then
    self._usedEntities[entity] = true
  else
    self._usedEntities[entity] = nil
  end
end

function QuestContext:clearUsedEntities()
  self._usedEntities = {}
end

function QuestContext:validateUsedEntities()
  for entity,_ in pairs(self._usedEntities) do
    if not entity:exists() then
      return false
    end
    if not entity:uniqueId() then
      local entityId = entity:entityId()
      local uniqueId = world.entityUniqueId(entityId)
      if uniqueId then
        -- Entity was assigned a uniqueId since the last time we checked
        entity._uniqueId = uniqueId
        self:entityBecameUnique(entity, uniqueId)
      end
    end
  end
  return true
end

function QuestContext:entityBecameUnique(entity, uniqueId)
  self._entities[entity._entityId] = nil
  self._uniqueEntities[uniqueId] = entity
end

function QuestContext:clearDeadEntities()
  for uniqueId, entity in pairs(self._uniqueEntities) do
    if not entity:exists() then
      self._uniqueEntities[uniqueId] = nil
    end
  end
  for entityId, entity in pairs(self._entities) do
    if not entity:exists() then
      self._entities[entityId] = nil
    end
  end
  for fieldName, valueEntities in pairs(self._entitiesBy or {}) do
    for fieldValue, entities in pairs(valueEntities) do
      self._entitiesBy[fieldName][fieldValue] = util.filter(entities, QuestPredicands.Entity.exists)
    end
  end
end

function QuestContext:entities()
  return self._entities
end

function QuestContext:uniqueEntities()
  return self._uniqueEntities
end

function QuestContext:entity(entityIdOrUniqueId)
  if type(entityIdOrUniqueId) ~= "string" then
    local entityId = entityIdOrUniqueId
    local uniqueId = world.entityUniqueId(entityId)
    if uniqueId then
      entityIdOrUniqueId = uniqueId
    else
      local entities = self:entities()
      if not entities[entityId] then
        entities[entityId] = QuestPredicands.Entity.new(self, entityId, nil)
      end
      return entities[entityId]
    end
  end

  local uniqueId = entityIdOrUniqueId
  local uniqueEntities = self:uniqueEntities()
  if not uniqueEntities[uniqueId] then
    uniqueEntities[uniqueId] = QuestPredicands.Entity.new(self, nil, uniqueId)
  end
  return uniqueEntities[uniqueId]
end

function QuestContext:queryNpcRelationships(relationship, converse, negated, npc)
  local relationships = npc:getRelationships(relationship, converse)
  if negated then
    local results = util.filter(self:entitiesByType()["npc"], function (nearbyNpc)
        return not nearbyNpc:uniqueId() or not relationships[nearbyNpc:uniqueId()]
      end)
    results[#results+1] = QuestPredicands.UnbornNpc.new()
    return results
  else
    local results = {}
    for uniqueId,_ in pairs(relationships) do
      results[#results+1] = self:entity(uniqueId)
    end
    return results
  end
end

function QuestContext:forEachEntity(func)
  for _,entity in pairs(self:entities()) do
    func(entity)
  end
  for _,entity in pairs(self:uniqueEntities()) do
    func(entity)
  end
end

function QuestContext:entitiesBy(fieldName, fieldGetter)
  if not self._entitiesBy then
    self._entitiesBy = {}
  end

  if not self._entitiesBy[fieldName] then
    self._entitiesBy[fieldName] = {}
    self:forEachEntity(function (entity)
        local fieldValue = fieldGetter(entity)
        if fieldValue then
          self._entitiesBy[fieldName][fieldValue] = self._entitiesBy[fieldName][fieldValue] or {}
          local list = self._entitiesBy[fieldName][fieldValue]
          list[#list+1] = entity
        end
      end)
  end
  return self._entitiesBy[fieldName]
end

function QuestContext:entitiesByType()
  return self:entitiesBy("type", QuestPredicands.Entity.entityType)
end

function QuestContext:entitiesByName()
  return self:entitiesBy("name", QuestPredicands.Entity.entityName)
end

function QuestContext:parentDeeds()
  if self._parentDeeds then return self._parentDeeds end
  self._parentDeeds = {}
  self._deeds = {}
  self._objectDeeds = {}

  local deeds = {}
  self:forEachEntity(function (deedEntity)
      local tenants = deedEntity:callScript("getTenants") or {}
      for _,tenant in pairs(tenants) do
        self._parentDeeds[tenant.uniqueId] = deedEntity
        deeds[deedEntity] = true
      end

      local objects = deedEntity:callScript("getOwnedObjectNames") or {}
      for objectName,count in pairs(objects) do
        self._objectDeeds[objectName] = self._objectDeeds[objectName] or {}
        local deedSet = self._objectDeeds[objectName]
        deedSet[deedEntity] = count
      end
    end)

  return self._parentDeeds
end

function QuestContext:deedsOwningObject(objectName)
  if not self._objectDeeds then
    self:parentDeeds()
  end
  return self._objectDeeds[objectName] or {}
end

function QuestContext:deeds()
  if not self._deeds then
    self:parentDeeds()
  end
  return self._deeds
end

function QuestContext:objectsUsedAsFurniture()
  if not self._objectDeeds then
    self:parentDeeds()
  end
  return self._objectDeeds
end
