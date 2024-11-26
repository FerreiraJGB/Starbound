require("/scripts/util.lua")

-- Stores behavior trees for this context so they don't need to be rebuilt every time
OverridesTreeCache = {}

function getOverrides()
  storage.behaviorOverrides = storage.behaviorOverrides or {}
  return storage.behaviorOverrides
end

function getOverrideTypes()
  if not self.behaviorOverrideTypes then
    self.behaviorOverrideTypes = {}
    for overrideType, overrides in pairs(getOverrides()) do
      for id,_ in pairs(overrides) do
        self.behaviorOverrideTypes[id] = overrideType
      end
    end
  end
  return self.behaviorOverrideTypes
end

function addOverride(overrideId, override)
  getOverrideTypes()[overrideId] = override.type
  local overrides = getOverrides()
  overrides[override.type] = overrides[override.type] or {}
  overrides[override.type][overrideId] = override
end

function removeOverride(overrideId)
  local overrideType = getOverrideTypes()[overrideId]
  if not overrideType then return end
  local overrides = getOverrides()
  overrides[overrideType] = overrides[overrideType] or {}
  overrides[overrideType][overrideId] = nil
  getOverrideTypes()[overrideId] = nil
end

function hasOverride(overrideId)
  local overrideType = getOverrideTypes()[overrideId]
  return overrideType ~= nil
end

function hasAnyOverride()
  return not isEmpty(getOverrideTypes())
end

-- param overrideName
-- output list
function matchingOverrides(args, board)
  local overrides = getOverrides()[args.overrideName] or {}

  local list = util.filter(util.toList(overrides), function (override)
      if override.questId and override.questFlag then
        return self.quest:getQuestValue(override.questId, override.questFlag) and true or false
      end
      return true
    end)

  if isEmpty(list) then return false end
  return true, {list = list}
end

-- param override
-- param argumentName
-- output entity
function overrideEntity(args, output)
  if not args.override then return false end

  local uniqueId = args.override[args.argumentName]
  if not uniqueId then return false end
  local entityId = world.loadUniqueEntity(uniqueId)
  if not world.entityExists(entityId) then return false end

  return true, {entity = entityId}
end

-- param override
-- param argumentName
-- output behavior
function overrideBehavior(args, board)
  if not args.override then return false end
  return true, {behavior = args.override[args.argumentName]}
end

function playBehavior(args, board, nodeId, dt)
  if not args.behavior then return false end

  local key = string.format("playBehavior-%s-%s", args.behavior.name, nodeId)
  local tree = OverridesTreeCache[key]
  if not tree then
    tree = behavior.behavior(args.behavior.name, sb.jsonMerge(config.getParameter("behaviorConfig", {}), args.behavior.parameters or {}), _ENV, board)
    OverridesTreeCache[key] = tree
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
