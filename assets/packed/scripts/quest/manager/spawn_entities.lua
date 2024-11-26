require("/scripts/quest/manager/plugin.lua")
require("/scripts/quest/location.lua")
require("/scripts/quest/text_generation.lua")
require("/scripts/util.lua")
require("/scripts/vec2.lua")
require("/scripts/rect.lua")

SpawnEntities = subclass(QuestPlugin, "SpawnEntities")

function SpawnEntities:init(...)
  QuestPlugin.init(self, ...)

  self.data.players = self.data.players or {}
  self.data.entitiesNeedReserving = self.data.entitiesNeedReserving or false
  self.data.entitiesAvailable = self.data.entitiesAvailable or false
  self.entityIds = {}
  self.justSpawned = false
end

function SpawnEntities:update()
  if not self.data.entities then return end

  if not self.justSpawned then
    if not self.data.entitiesAvailable then
      for uniqueId,_ in pairs(self.data.entities) do
        self.questManager.outbox.contactList:setEnabled(uniqueId, true)
      end
      self.data.entitiesAvailable = true
    end

    for uniqueId,_ in pairs(self.data.entities) do
      if not world.findUniqueEntity(uniqueId):result() then
        self.data.entities[uniqueId] = nil
      end
    end
  else
    -- Don't check uniqueIds yet as we've just spawned the entities and
    -- their uniqueIds may not be set up this tick.
    self.justSpawned = false
  end

  if isEmpty(self.data.entities) then
    self.data.entities = nil
    for player,_ in pairs(self.data.players) do
      self.questManager:sendToPlayer(player, "entitiesDead", self.config.group)
    end
    self.data.players = {}
  end
end

local function spawnEntity(spawnConfig)
  local parameters = shallowCopy(spawnConfig.parameters)
  parameters.level = (parameters.level or world.threatLevel()) + (spawnConfig.levelBoost or 0)

  local typeName = spawnConfig.typeName
  local species = spawnConfig.species
  if type(typeName) == "table" then
    typeName = typeName[math.random(#typeName)]
  end
  if type(species) == "table" then
    species = species[math.random(#species)]
  end

  local statusEffects = shallowCopy(spawnConfig.statusEffects)
  local entityId = nil
  if spawnConfig.entityType == "monster" then

    if spawnConfig.miniboss then
      parameters.level = parameters.level + 1
      parameters.aggressive = true
      parameters.capturable = false

      local minibossConfig = root.assetJson("/quests/quests.config:spawnEntities.minibosses")
      parameters.scale = minibossConfig.scale
      statusEffects.miniboss = minibossConfig.statusEffects
    end

    if spawnConfig.evolve then
      local monsterEvolution = root.assetJson("/quests/quests.config:spawnEntities.monsterEvolution")
      typeName = monsterEvolution[typeName] or typeName
      parameters.level = parameters.level + 1
    end

    entityId = world.spawnMonster(typeName, entity.position(), parameters)
  else
    assert(spawnConfig.entityType == "npc")
    entityId = world.spawnNpc(entity.position(), species, typeName, parameters.level, spawnConfig.seed, parameters)
  end

  for category, effects in pairs(statusEffects) do
    world.callScriptedEntity(entityId, "status.addPersistentEffects", category, effects)
  end
  return entityId
end

function SpawnEntities:spawnUnique(evolve, miniboss, statusEffects, extraDrops)
  local entitySpawnConfig = {
      evolve = evolve,
      miniboss = miniboss
    }

  if self.config.spawnParameter then
    local param = self.questParameters[self.config.spawnParameter]
    if param.type == "npcType" then
      entitySpawnConfig.entityType = "npc"
    else
      assert(param.type == "monsterType")
      entitySpawnConfig.entityType = "monster"
    end
    entitySpawnConfig.species = param.species
    entitySpawnConfig.typeName = param.typeName
    entitySpawnConfig.parameters = param.parameters or {}
    entitySpawnConfig.seed = param.seed
  else
    entitySpawnConfig.entityType = self.config.entityType
    entitySpawnConfig.species = self.config.species
    entitySpawnConfig.typeName = self.config.typeName
    entitySpawnConfig.parameters = self.config.parameters or {}
  end
  if self.config.persistent then
    entitySpawnConfig.parameters.persistent = true
  end
  entitySpawnConfig.levelBoost = self.config.levelBoost
  entitySpawnConfig.statusEffects = statusEffects
  local entityId = spawnEntity(entitySpawnConfig)

  if entitySpawnConfig.entityType == "npc" then
    world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
  end

  if self.config.drops then
    local drops = self.config.drops
    if type(drops) == "string" then
      drops = self.questParameters[drops].items
    end
    assert(drops ~= nil)
    world.callScriptedEntity(entityId, "addDrops", drops)
  end
  if extraDrops then
    world.callScriptedEntity(entityId, "addDrops", extraDrops)
  end

  local uniqueId = sb.makeUuid()
  world.setUniqueId(entityId, uniqueId)

  for _,relationship in pairs(self.config.relationships or {}) do
    local relationName, converse, relatee = table.unpack(relationship)
    local relateeUniqueId = self.questParameters[relatee].uniqueId
    local relateeEntityId = relateeUniqueId and world.loadUniqueEntity(relateeUniqueId)
    if relateeEntityId and world.entityExists(relateeEntityId) then
      world.callScriptedEntity(entityId, "addRelationship", relationName, converse, relateeUniqueId)
      world.callScriptedEntity(relateeEntityId, "addRelationship", relationName, not converse, uniqueId)
    end
  end

  self.justSpawned = true
  self.data.entitiesNeedReserving = entitySpawnConfig.entityType == "npc"
  self.data.entitiesAvailable = entitySpawnConfig.entityType ~= "npc"
  return uniqueId, entityId
end

-- Find a position for an entity with the given space requirements
function SpawnEntities:findPosition(boundBox)
  assert(self.config.positionParameter ~= nil)
  local positionParam = self.questParameters[self.config.positionParameter]
  assert(positionParam.uniqueId ~= nil)

  if positionParam.type == "location" then
    local locationEntityId = world.loadUniqueEntity(positionParam.uniqueId)
    local position = world.callScriptedEntity(locationEntityId, "findPosition", boundBox)
    if position then
      return position
    end

    assert(positionParam.region)
    return rect.center(positionParam.region)
  else
    return world.findUniqueEntity(positionParam.uniqueId):result()
  end
end

function SpawnEntities:spawnTreasure(config)
  local searchCenter = rect.center(self.questParameters[self.config.positionParameter].region)
  if not searchCenter then return nil end
  local locations = Location.search(searchCenter, nil, config.minDistance, config.maxDistance)
  if #locations == 0 then return nil end

  local location = locations[math.random(#locations)]
  local entityId = world.loadUniqueEntity(location.uniqueId)
  if world.callScriptedEntity(entityId, "addTreasure", config.treasurePool) then
    return location
  end
end

function SpawnEntities:generateTreasureNote(location)
  local textGenerator = questTextGenerator(self.questDescriptor)
  local templates = questNoteTemplates(self.templateId, "treasureNote")
  return generateNoteItem(templates, nil, textGenerator)
end

function SpawnEntities:questStarted()
  self.entityIds = {}
  self.data.entities = {}
  self.data.entityParameterNames = {}

  local spawnCount = util.randomIntInRange(self.config.spawnCount or 1)

  -- Determine which (if any) monsters to evolve or turn into minibosses
  local evolve = {}
  local evolvedIndices = {}
  local minibossIndex = nil
  for i = 1, spawnCount do
    if math.random() < (self.config.evolutionChance or 0) then
      evolve[i] = true
      table.insert(evolvedIndices, i)
    end
  end
  if #evolvedIndices > 0 and math.random() < (self.config.minibossChance or 0) then
    minibossIndex = evolvedIndices[math.random(#evolvedIndices)]
  end

  local statusEffects = {}
  if math.random() < (self.config.randomStatusEffectChance or 0) then
    local effect = self.config.randomStatusEffect[math.random(#self.config.randomStatusEffect)]
    statusEffects["spawner"] = {effect}
  end

  local treasureNoteItem = nil
  local treasureIndex = nil
  if self.config.treasureTrail then
    local treasureLocation = self:spawnTreasure(self.config.treasureTrail)
    if treasureLocation then
      self.questManager:setQuestParameter(self.questId, "treasureLocation", {
          type = "location",
          name = treasureLocation.name,
          uniqueId = treasureLocation.uniqueId,
          region = treasureLocation.region
        })
      treasureNoteItem = self:generateTreasureNote(treasureLocation)
      treasureIndex = math.random(spawnCount)
    end
  end

  for i = 1, spawnCount do
    local drops = {}
    if i == treasureIndex then
      table.insert(drops, treasureNoteItem)
    end

    local isMiniboss = i == minibossIndex
    local uniqueId, entityId = self:spawnUnique(evolve[i], isMiniboss, statusEffects, drops)

    local boundBox = world.callScriptedEntity(entityId, "mcontroller.boundBox")
    local position = self:findPosition(boundBox)
    world.callScriptedEntity(entityId, "mcontroller.setPosition", position)

    self.data.entities[uniqueId] = true
    self.entityIds[uniqueId] = entityId

    local entityParameterFormat = self.config.addEntityParameter or sb.makeUuid()
    local entityParam = self:entityParam(uniqueId)
    local paramName = string.format(entityParameterFormat, i)
    table.insert(self.data.entityParameterNames, paramName)
    self.questManager:setQuestParameter(self.questId, paramName, entityParam)
  end
end

function SpawnEntities:questFinished()
  if self.data.failed or self.config.despawnOnCompletion then
    for uniqueId,_ in pairs(self.data.entities or {}) do
      local entityId = world.loadUniqueEntity(uniqueId)
      if world.entityExists(entityId) then
        world.callScriptedEntity(entityId, "tenant.despawn", true)
      end
    end
  end
end

function SpawnEntities:entityParam(uniqueId)
  local entityId = self.entityIds[uniqueId] or world.loadUniqueEntity(uniqueId)
  if not world.entityExists(entityId) then return nil end

  return {
      type = "entity",
      uniqueId = uniqueId,
      name = self.config.name or world.entityName(entityId),
      species = world.entitySpecies(entityId),
      gender = world.entityGender(entityId),
      portrait = world.entityPortrait(entityId, "full")
    }
end

function SpawnEntities:playerStarted(player)
  self.data.players[player] = true

  assert(self.data.entities ~= nil)

  if self.data.entitiesNeedReserving then
    for uniqueId,_ in pairs(self.data.entities) do
      self.questManager.outbox.contactList:registerWorldEntity(uniqueId)
      self.questManager.outbox.contactList:setEnabled(uniqueId, false)
      self.questManager:reserveParticipant(self.questId, uniqueId, self.config.participantDef)
    end
    self.data.entitiesNeedReserving = false
  end

  local entityParams = {}
  for uniqueId,_ in pairs(self.data.entities) do
    local entityParam = self:entityParam(uniqueId) 
    if entityParam then
      table.insert(entityParams, entityParam)
    end
  end

  self.questManager:sendToPlayer(player, "entitiesSpawned", self.config.group, self.data.entityParameterNames)
end

function SpawnEntities:playerFailed(player)
  QuestPlugin.playerFailed(self, player)
  self.data.failed = true
end

function SpawnEntities:playerFinished(player)
  self.data.players[player] = nil
end
