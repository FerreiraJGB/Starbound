require "/scripts/util.lua"
require "/scripts/relationships.lua"

-- Stores behavior trees for this context so they don't need to be rebuilt every time
ReactionTreeCache = {}

function getReaction(influence, reactTarget)
  local variant = config.getParameter(string.format("reactions.%s", influence))
  if variant then
    return variant
  end

  local personality = personality()
  if personality.reactions[influence] and (not personality.additiveReactions or not contains(personality.additiveReactions, influence)) then
    return personality.reactions[influence]
  end

  local objectDefaults = {}
  if reactTarget and world.entityType(reactTarget) ~= "player" then
    objectDefaults = world.callScriptedEntity(reactTarget, "npcToy.getDefaultReactions") or {}
  end
  local reaction = objectDefaults[influence] or root.assetJson("/npcs/default_reactions.config:reactions")[influence] or root.assetJson("/npcs/default_reactions.config:reactions.default")

  -- additive personality reactions
  if personality.reactions[influence] then
    for _,personalityReaction in pairs(personality.reactions[influence]) do
      table.insert(reaction, personalityReaction)
    end
  end

  return reaction
end

function getFinalReactions()
  return root.assetJson("/npcs/default_reactions.config").finalReactions
end

-- param target
-- output influence
function getPersonality(args, board)
  if args.target == nil then return false end
  local influence = world.callScriptedEntity(args.target, "personalityType")
  if influence == nil then return false end
  return true, {influence = influence}
end

-- param relationship
-- param converse
-- param target
function entityRelationship(args, board)
  local uniqueId = world.entityUniqueId(args.target)
  if not uniqueId then return false end
  local result = hasRelationship(args.relationship, args.converse, uniqueId)
  return result
end

-- param influence
-- param target
-- output reaction
function chooseReaction(args, board)
  if args.influence == nil then return false end
  if args.target and not world.entityExists(args.target) then return false end

  local reactions = getReaction(args.influence, args.target)
  if reactions == nil then return false end
  reactions = filterReactions(reactions)

  local reaction = util.weightedRandom(reactions)
  if reaction then
    return true, {reaction = reaction}
  end
  return false
end

function filterReactions(reactions)
  local filtered = {}

  local include = function(reaction)
    if reaction[3] == nil then return true end
    local args = reaction[3]

    if args.timeRange then return util.isTimeInRange(world.timeOfDay(), args.timeRange) end
  end

  for _,reaction in ipairs(reactions) do
    if include(reaction) then
      table.insert(filtered, reaction)
    end
  end

  return filtered
end

-- output reaction
function resetReaction(args, board)
  return true, {reaction = nil}
end

-- param reactionVar
-- param reactionName
function isReaction(args, board)
  if args.reactionVar == nil then return false end
  return args.reactionVar == args.reactionName
end

-- param reaction
function isFinalReaction(args, board)
  for _,final in ipairs(getFinalReactions()) do
    if final == args.reaction or final == args.influence then
      return true
    end
  end
  return false
end

-- param list
-- output list
-- output influence
function listPopInfluence(args, board)
  local list = args.list or jarray()
  local value = list[1]
  if value == nil then return false end
  table.remove(list, 1)
  return true, {list = list, influence = value}
end

-- param target
function npcToyIsAvailable(args, board)
  if args.target == nil then return false end
  if world.callScriptedEntity(args.target, "npcToy.isAvailable") then
    if world.callScriptedEntity(args.target, "npcToy.isOwnerOnly") then
      return storage.homeBoundary ~= nil and world.polyContains(storage.homeBoundary, world.entityPosition(args.target))
    end
    return true
  end
  return false
end

-- param target
function npcToyIsAttractive(args, output)
  if args.target == nil then return false end
  local maxPlayTargetNpcs = personality().maxPlayTargetNpcs
  local maxNpcs = world.callScriptedEntity(args.target, "npcToy.getMaxNpcs")
  if maxPlayTargetNpcs ~= nil and (maxNpcs == nil or maxNpcs > maxPlayTargetNpcs) then
    -- NPC's personality type doesn't play with toys that accomodate this
    -- many NPCs at once.
    return false
  end
  return true
end

-- param target
function npcToyIsPriority(args, board)
  if args.target == nil then return false end
  if world.callScriptedEntity(args.target, "npcToy.isPriority") then
    return true
  end
  return false
end

-- param target
-- output position
-- output x
-- output y
function npcToyPreciseStandPosition(args, board)
  if args.target == nil then return false end

  local standPosition = world.callScriptedEntity(args.target, "npcToy.getPreciseStandPosition")

  if standPosition == nil then return false end
  local position = world.entityPosition(args.target)
  standPosition[1] = standPosition[1] + position[1]
  standPosition[2] = standPosition[2] + position[2]
  return true, {position = standPosition, x = standPosition[1], y = standPosition[2]}
end

-- param target
-- output position
-- output x
-- output y
function npcToyImpreciseStandPosition(args, board)
  if args.target == nil then return false end
  local standPosition = world.callScriptedEntity(args.target, "npcToy.getImpreciseStandPosition")

  if standPosition == nil then return false end
  local position = world.entityPosition(args.target)
  standPosition[1] = standPosition[1] + position[1]
  standPosition[2] = standPosition[2] + position[2]
  return true, {position = standPosition, x = standPosition[1], y = standPosition[2]}
end

-- param entity
-- output influences
function npcToyPlay(args, board)
  if args.entity == nil then return false end
  if not world.callScriptedEntity(args.entity, "npcToy.isAvailable") then
    return false
  end
  world.callScriptedEntity(args.entity, "npcToy.notifyNpcPlay", entity.id())
  self.playTarget = args.entity

  local influences = world.callScriptedEntity(args.entity, "npcToy.getInfluence")
  if influences == nil then
    return false
  end

  -- keep calling until no longer playing
  -- entity must call npcToy.notifyNpcPlayEnd on self.playTarget when self.playing
  -- is no longer being set to true
  while true do
    self.playing = true

    coroutine.yield(nil, {influences = influences})
  end
end

-- output influence
function receivedInfluenceNotification(args, board)
  for i,notification in pairs(self.notifications) do
    if notification.type == "influence" then
      table.remove(self.notifications, i)
      return true, {influence = notification.influence}
    end
  end
  return false
end

-- param reaction
-- param target
function sendInfluenceNotification(args, board)
  if args.reaction == nil then return false end
  if args.target == nil or not world.entityExists(args.target) or world.entityType(args.target) == "player" then return false end

  local notification = {
    sourceId = entity.id(),
    targetId = args.target,
    type = "influence",
    influence = args.reaction
  }
  world.callScriptedEntity(args.target, "notify", notification)
  return true
end

-- param influence
-- output influence
function setInfluence(args, board)
  return true, {influence = args.influence}
end

-- param reaction
function playSimpleReaction(args, board, _, dt)
  if args.reaction == nil then return false end
  local simpleReactions = root.assetJson("/npcs/default_reactions.config").simpleReactions
  local reactionConfig = simpleReactions[args.reaction]
  if reactionConfig == nil then return false end
  if reactionConfig.emote then
    npc.emote(reactionConfig.emote)
  end
  if reactionConfig.dance then
    npc.dance(reactionConfig.dance)
  end
  local duration = reactionConfig.duration
  while duration > 0 do
    dt = coroutine.yield()
    duration = duration - dt
  end
  return true
end

-- param reaction
function playBehaviorReaction(args, board, nodeId, dt)
  local reaction = root.assetJson("/npcs/default_reactions.config:behaviorReactions")[args.reaction]

  local key = string.format("playBehaviorReaction-%s-%s", args.reaction, nodeId)
  local tree = ReactionTreeCache[key]
  if not tree then
    local parameters = sb.jsonMerge(config.getParameter("behaviorConfig", {}), reaction.parameters or {})
    tree = behavior.behavior(reaction.behavior, parameters, _ENV, board)
    ReactionTreeCache[key] = tree
  else
    tree:clear()
  end

  while true do
    local result = tree:run(dt)
    if result == false or result == true then
      return result
    else
      dt = coroutine.yield()
    end
  end
end
