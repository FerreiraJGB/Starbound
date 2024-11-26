require("/scripts/util.lua")
require("/scripts/questgen/util.lua")
require("/scripts/questgen/planner.lua")
require("/scripts/questgen/predicands.lua")
require("/scripts/questgen/context.lua")
require("/scripts/questgen/relations.lua")
require("/scripts/questgen/pools.lua")

QuestGenerator = createClass("QuestGenerator")
function QuestGenerator:init()
  self.debug = false
  self.measureTime = false
  self.questPools = nil
  self.abortQuestCallback = nil
end

function QuestGenerator:debugLog(...)
  if self.debug then
    sb.logInfo(...)
  end
end

function QuestGenerator:withContext(func)
  local queryRange = config.getParameter("questGenerator.queryRange", 50)
  local queryCooldown = config.getParameter("questGenerator.queryCooldown", 60)

  local now = world.time()
  if not self._context or not self.lastQueryTime or self.lastQueryTime + queryCooldown < now then
    self.lastQueryTime = now
    self._context = QuestContext.new(self:position(), queryRange)
  end

  local result = func(self._context)

  self._context:clearUsedEntities()

  return result
end

function QuestGenerator:timeFunction(description, func)
  local startTime
  if self.measureTime then
    startTime = os.clock()
  end

  local result = func()

  if self.measureTime then
    local elapsed = os.clock() - startTime
    sb.logInfo("Time elapsed %s: %sms", description, elapsed * 1000)
  end

  return result
end

function QuestGenerator:generateStep()
  return self:timeFunction("during generation step", function ()
    if self._context then
      -- Check the entities the planner is using are still around. If not, the
      -- plan it's currently creating has to be thrown away.
      self._context:clearDeadEntities()
      if not self._context:validateUsedEntities() then
        self._context:clearUsedEntities()
        self.coroutine = nil
      end
    end

    if self.coroutine == nil or coroutine.status(self.coroutine) == "dead" then
      self.coroutine = coroutine.create(function () return self:generate() end)
    end

    local status, result = coroutine.resume(self.coroutine)
    if not status then
      sb.logInfo("Quest generator broke: %s", result)
      return nil
    end
    return result
  end)
end

function QuestGenerator:questPool()
  if not self._questPool then
    self:timeFunction("loading operator json", function ()
      self._questPool = {
          ends = {},
          quests = {}
        }
      for _,poolName in pairs(self.questPools or config.getParameter("questGenerator.pools", {})) do
        local pool = root.assetJson("/quests/generated/questpools/"..poolName..".config")
        for _,entry in pairs(pool.ends) do
          self._questPool.ends[#self._questPool.ends+1] = entry
        end
        for key,quest in pairs(pool.quests) do
          self._questPool.quests[key] = quest
        end
      end
    end)
  end
  return self._questPool
end

function QuestGenerator:position()
  -- Works for objects as well as NPCs:
  return entity.position()
end

function QuestGenerator:entityName(entityId)
  if world.entityType(entityId) == "object" then
    return world.getObjectParameter(entityId, "shortdescription")
  else
    return world.entityName(entityId)
  end
end

function QuestGenerator:createPoolRelations()
  if not self._poolRelations then
    self._poolRelations = {}

    for name, poolConfig in pairs(root.assetJson("/quests/generated/pools/pools.config")) do
      local relation = PoolRelations[poolConfig.relation]
      self._poolRelations[name] = defineRelation(name, true, relation)(poolConfig)
    end
  end
  return self._poolRelations
end

function QuestGenerator:createPlanner(context)
  return self:timeFunction("creating planner", function ()
    if not self.operatorTable then
      self:timeFunction("loading operators", function ()
        self.operatorTable = OperatorTable.new()
        self.operatorTable:addOperators(self:questPool().quests)
      end)
    end

    local maxCost = config.getParameter("questGenerator.maxPlanCost", 5)
    local planner = Planner.new(maxCost)
    self:timeFunction("adding relations to the planner", function ()
      planner:addRelations(QuestRelations)
      planner:addRelations(self:createPoolRelations())
    end)
    planner.operators = self.operatorTable

    planner.debug = self.debug
    planner.context = context
    context.planner = planner

    self:timeFunction("setting up the questgiver", function ()
      local questGiver = context:entity(self.questGiver or entity.id())
      questGiver:setLabel("questGiver")
      questGiver:setUsed(true)
      planner:setConstants({
        questGiver = questGiver,
        player = QuestPredicands.Player.new()
      })
    end)

    return planner
  end)
end

function QuestGenerator:planSequence(questSpec)
  -- There are two kinds of quest sequences in the quest pools, defined by
  -- their end-goals:
  --  * Template sequences, which always end in fixed quest template.
  --  * Subquest sequences, which end in a quest pulled from the subquest pool.
  return self:withContext(function (context)
      coroutine.yield()
      local planner = self:createPlanner(context)
      coroutine.yield()
      if questSpec.subquestSequence then
        return self:planSubquestSequence(planner, questSpec)
      else
        return self:planTemplateSequence(planner, questSpec)
      end
    end)
end

function QuestGenerator:planSubquestSequence(planner, questSpec)
  self:debugLog("Planning a sequence for %s", questSpec.name)
  local endGoal = Operator.new(questSpec.name, questSpec):createOperation(planner)
  local initialState = Conjunction.new()
  planner:generateAssignments(initialState, endGoal:preconditions())
  if not endGoal:isGround() then return nil end
  local plan = planner:generatePlan(initialState, endGoal:postconditions():withImplications(), nil)
  if not plan or (questSpec.minLength and #plan < questSpec.minLength) then return nil end
  return self:postprocess(planner, plan)
end

function QuestGenerator:planTemplateSequence(planner, questSpec)
  self:debugLog("Planning a sequence for %s", questSpec.name)
  local finalQuest = Operator.new(questSpec.name, questSpec):createOperation(planner)
  local initialState = Conjunction.new()
  planner:generateAssignments(initialState, finalQuest:preconditions())
  local plan = planner:generatePlan(initialState, finalQuest:preconditions():withImplications(), nil)
  if not plan then return nil end
  if not finalQuest:isGround() then return nil end

  plan[#plan+1] = finalQuest
  return self:postprocess(planner, plan)
end

function QuestGenerator:mergeSymbols(operationName, mergeConfig, firstOpSymbols, secondOpSymbols)
  local merged = PrintableTable.new(firstOpSymbols)

  local op1Input = mergeConfig.input and Predicand.value(firstOpSymbols[mergeConfig.input])
  local op1Output = mergeConfig.output and Predicand.value(firstOpSymbols[mergeConfig.output])
  local op2Input = mergeConfig.input and Predicand.value(secondOpSymbols[mergeConfig.input])
  local op2Output = mergeConfig.output and Predicand.value(secondOpSymbols[mergeConfig.output])

  if op1Output and op2Input then
    -- Output from the first op are used as inputs in the second op.
    -- Remove the common elements from both sets.
    local newOp1Output = op1Output:mergeSubtract(op2Input)
    local newOp2Input = op2Input:mergeSubtract(op1Output)
    op1Output, op2Input = newOp1Output, newOp2Input
  end

  if mergeConfig.input then
    merged[mergeConfig.input] = op1Input:merged(op2Input)
  end
  if mergeConfig.output then
    merged[mergeConfig.output] = op1Output:merged(op2Output)
  end
  if mergeConfig.extraMerge then
    for _,fieldName in ipairs(mergeConfig.extraMerge) do
      local firstField = Predicand.value(firstOpSymbols[fieldName])
      local secondField = Predicand.value(secondOpSymbols[fieldName])
      merged[fieldName] = firstField:merged(secondField)
    end
  end

  return merged
end

function QuestGenerator:postprocess(planner, operations)
  -- Merge operations that can be combined
  if not operations then return nil end

  -- Final chance to discard this quest before it affects the world
  if self.abortQuestCallback and self.abortQuestCallback() then
    return nil
  end

  local state = Conjunction.new()
  local skips = {}
  local plan = {}
  for i,operation in ipairs(operations) do
    if not skips[i] then
      local symbols = operation.symbols

      state = operation:apply(state)

      if operation.config.merging then
        for j = i+1, #operations do
          local lateOp = operations[j]
          if not skips[j] and lateOp.name == operation.name then
            local preconds = lateOp:preconditions():withImplications()
            if preconds:satisfyWithState(state) and preconds:isGround() then
              symbols = self:mergeSymbols(operation.name, operation.config.merging, symbols, lateOp.symbols)
              skips[j] = true
              state = lateOp:apply(state)
              assert(state ~= nil)
            end
          end
        end
      end

      plan[#plan+1] = operation.operator:createOperation(planner, symbols)
      coroutine.yield()
    end
  end

  return self:generateUniqueIds(planner, plan)
end

function QuestGenerator:generateUniqueIds(planner, plan)
  for _, operation in ipairs(plan) do
    for key, symbol in pairs(operation.symbols) do
      local predicand = Predicand.value(operation.symbols[key])
      match (predicand) {
        [QuestPredicands.Entity] = function (entity)
            local uniqueId = entity:uniqueId()
            if not uniqueId then
              uniqueId = sb.makeUuid()
              entity:setUniqueId(uniqueId)
            end
          end,

        [QuestPredicands.TemporaryNpc] = function (npc)
            local entityId = npc:spawn()
            local uniqueId = sb.makeUuid()
            npc.entityId = entityId
            npc.uniqueId = uniqueId
            world.setUniqueId(entityId, uniqueId)
            local entity = QuestPredicands.Entity.new(planner.context, entityId, uniqueId)
            planner.context:markEntityUsed(entity, true)
          end,

        default = function () end
      }
    end
  end

  -- Wait one more tick so that any uniqueIds we've just set are ready for use.
  coroutine.yield()

  return plan
end

function QuestGenerator:chooseFinalQuest()
  local ends = self:questPool().ends
  if #ends == 0 then return nil end
  local choice = util.weightedRandom(ends)
  return self:questPool().quests[choice]
end

function QuestGenerator:generateParameters(templateId, parameterDefs, opSymbols)
  local parameters = {}
  for key, parameterDef in pairs(parameterDefs) do
    parameters[key] = self:generateParameter(templateId, key, parameterDef, opSymbols[key])
  end
  return parameters
end

function QuestGenerator:generateParameter(templateId, paramName, parameterDef, predicand)
  local value = Predicand.value(predicand)
  local param = match (value) {
    [QuestPredicands.Item] = function (item)
        return {
            type = "item",
            item = {
                name = item.itemName,
                parameters = item.parameters
              },
            name = root.itemConfig(item.itemName).shortdescription
          }
      end,

    [QuestPredicands.ItemTag] = function (itemTag)
        return {
            type = "itemTag",
            tag = itemTag.tag,
            name = itemTag.name
          }
      end,

    [QuestPredicands.ItemList] = function (itemList)
        return {
            type = "itemList",
            items = itemList:toJson()
          }
      end,

    [QuestPredicands.NullEntity] = function ()
        return {
            type = "entity"
          }
      end,

    [QuestPredicands.Entity] = function (entity)
        local uniqueId = entity:uniqueId()
        assert(uniqueId ~= nil)
        local entityId = entity:entityId()
        return {
            type = "entity",
            uniqueId = uniqueId,
            species = world.entitySpecies(entityId),
            gender = world.entityGender(entityId),
            name = world.entityName(entityId),
            portrait = world.entityPortrait(entityId, "full")
          }
      end,

    [QuestPredicands.TemporaryNpc] = function (npc)
        local uniqueId = npc.uniqueId
        local entityId = npc.entityId
        assert(uniqueId ~= nil and entityId ~= nil and world.entityExists(entityId))
        return {
            type = "entity",
            uniqueId = uniqueId,
            species = world.entitySpecies(entityId),
            gender = world.entityGender(entityId),
            name = world.entityName(entityId),
            portrait = world.entityPortrait(entityId, "full")
          }
      end,

    [QuestPredicands.Location] = function (location)
        return {
            type = "location",
            region = location.region,
            name = location.name,
            uniqueId = location.uniqueId
          }
      end,

    [QuestPredicands.NpcType] = function (npcType)
        local seed = npcType.seed
        if seed == "stable" then
          seed = generateSeed()
        end
        return {
            type = "npcType",
            name = npcType.name,
            species = npcType.species,
            typeName = npcType.typeName,
            parameters = npcType.parameters,
            seed = seed,
            portrait = npcType:portrait(seed)
          }
      end,

    [QuestPredicands.MonsterType] = function (monsterType)
        local parameters = shallowCopy(monsterType.parameters)
        if parameters.seed == "stable" then
          parameters.seed = generateSeed()
        end
        return {
            type = "monsterType",
            name = monsterType.name,
            typeName = monsterType.typeName,
            parameters = parameters,
            portrait = monsterType:portrait(parameters.seed)
          }
      end,

    default = function ()
        if type(value) == "string" then
          return {
              type = "noDetail",
              name = value
            }
        else
          error("Invalid "..paramName.." parameter for quest "..templateId..": "..tostring(value))
        end
      end
  }

  if parameterDef.type and parameterDef.type ~= param.type then
    error("Quest generator expected param type "..parameterDef.type.." but generated "..param.type)
  end

  -- Fill in defaults from the param def (e.g. the indicator icon)
  for key, value in pairs(parameterDef) do
    if not param[key] and key ~= "example" then
      param[key] = value
    end
  end

  return param
end

function QuestGenerator:generateParticipants(operation, parameters, questId)
  local participants = shallowCopy(operation.config.participants or {})

  local uniqueIds = {}
  for paramName, paramValue in pairs(parameters) do
    if not participants[paramName] and paramValue.uniqueId then
      participants[paramName] = {}
    end
    if paramValue.uniqueId then
      uniqueIds[paramValue.uniqueId] = paramName
    end
  end

  for paramName, participant in pairs(participants) do
    participant.stateDeltas = participant.stateDeltas or {}
  end

  -- Add state deltas to the participant data. This is so that participants
  -- can change their relationships with other npcs as defined by the
  -- postconditions of the quest.
  for _,term in ipairs(operation:postconditions():terms()) do
    if term.npcStateDeltas then
      local deltas = term:npcStateDeltas()
      for npc, delta in pairs(deltas) do
        if uniqueIds[npc] then
          local participant = participants[uniqueIds[npc]]
          participant.stateDeltas[#participant.stateDeltas+1] = delta
        end
      end
    end
  end

  return participants
end

function QuestGenerator:createRewardBag(overallDifficulty)
  local rewardPools = root.assetJson("/quests/generated/generator.config:rewardPools")

  local bestMatch = -1
  local rewardPool = nil
  for _,entry in ipairs(rewardPools) do
    local threshold, poolName = table.unpack(entry)
    if threshold > bestMatch and threshold <= overallDifficulty then
      bestMatch = threshold
      rewardPool = poolName
    end
  end

  if not rewardPool then return nil end
  return {
      type = "itemList",
      items = { {
          name = "rewardbag",
          count = 1,
          parameters = {
              treasure = {
                  pool = rewardPool,
                  level = world.threatLevel()
                }
            }
        } },
    }
end

function QuestGenerator:generate(questSpec)
  questSpec = questSpec or self:chooseFinalQuest()
  if not questSpec then return nil end

  local plan = self:planSequence(questSpec)
  if plan then
    self:debugLog("Quest sequence:")
    for _,quest in ipairs(plan) do
      self:debugLog("  %s %s", quest.name, tostring(quest.symbols))
    end
  else
    self:debugLog("No quest sequence.")
    return nil
  end

  local quests = {}
  local participants = {}
  local managerPlugins = {}
  local overallDifficulty = 0
  local suppressRewardBag = false

  for _,operation in ipairs(plan) do
    local templateId = operation.config.templateId
    if not templateId then
      error("Operation "..operation.name.." has no templateId and cannot be part of a quest sequence")
    end

    local parameterDefs = root.questConfig(templateId).parameters
    local parameters = self:generateParameters(templateId, parameterDefs, operation.symbols)

    local questDesc = {
        questId = operation.config.questId or sb.makeUuid(),
        templateId = templateId,
        parameters = parameters,
        seed = generateSeed()
      }
    quests[#quests+1] = questDesc
    participants[questDesc.questId] = self:generateParticipants(operation, parameters, questDesc.questId)

    managerPlugins[questDesc.questId] = operation.config.managerPlugins

    overallDifficulty = overallDifficulty + (operation.config.difficulty or 0)

    if operation.config.generateRewardBag ~= nil then
      if not operation.config.generateRewardBag then
        suppressRewardBag = true
      end
    end
  end

  if not suppressRewardBag then
    quests[#quests].parameters.rewards = self:createRewardBag(overallDifficulty)
  end

  for _,opParticipants in pairs(participants) do
    opParticipants.questGiver = opParticipants.questGiver or {}
    opParticipants.questGiver.offerQuest = true
    opParticipants.questGiver.critical = true
  end

  return {
      questArc = {
          quests = quests,
          stagehandUniqueId = sb.makeUuid()
        },
      participants = participants,
      managerPlugins = managerPlugins
    }
end
