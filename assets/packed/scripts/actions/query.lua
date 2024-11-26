
-- param position
-- param range
-- param entityTypes
-- param orderBy
-- param withoutEntity
-- output entity
-- output list
function queryEntity(args, board)
  if args.position == nil or args.range == nil then return false end

  local queryArgs = {
    includedTypes = args.entityTypes,
    order = args.orderBy,
    withoutEntityId = args.withoutEntity
  }
  local nearEntities = world.entityQuery(args.position, args.range, queryArgs)
  if #nearEntities > 0 then
    return true, {entity = nearEntities[1], list = nearEntities}
  end

  return false
end

-- param position
-- param range
-- param orderBy
-- output entity
-- output list
function findObject(args, board)
  if args.position == nil then return false end

  local objects = world.entityQuery(args.position, args.range, { includedTypes = {"object"}, order = args.orderBy })
  if args.name then
    local filtered = {}
    for _,objectId in pairs(objects) do
      if world.entityName(objectId) == args.name then
        table.insert(filtered, objectId)
      end
    end
    objects = filtered
  end

  if #objects > 0 then
    return true, {entity = objects[1], list = objects}
  end
  return false
end

-- param position
-- param range
-- param orderBy
-- param orientation
-- param unoccupied
-- output entity
-- output list
function findLoungable(args, board)
  if args.position == nil then return false end

  local queryArgs = {
    order = args.orderBy,
    withoutEntityId = args.withoutEntity
  }
  local loungables = world.loungeableQuery(args.position, args.range, { orientation = args.orientation }, queryArgs)

  if args.unoccupied then
    local unoccupied = {}
    for _,loungableId in pairs(loungables) do
      if not world.loungeableOccupied(loungableId) then
        table.insert(unoccupied, loungableId)
      end
    end
    loungables = unoccupied
  end

  if #loungables > 0 then
    return true, {entity = loungables[1], list = loungables}
  else
    return false
  end
end

-- param position
-- param range
-- param type
-- param orderBy
-- param exclude
-- output entity
-- output list
function findMonster(args, board)
  if args.position == nil then return false end

  local monsters = world.entityQuery(args.position, args.range, { includedTypes = {"monster"}, order = args.orderBy, withoutEntityId = args.exclude })
  if args.type then
    local filtered = {}
    for _,entityId in pairs(monsters) do
      if world.monsterType(entityId) == args.type then
        table.insert(filtered, entityId)
      end
    end
    monsters = filtered
  end

  if #monsters > 0 then
    return true, {entity = monsters[1], list = monsters}
  end
  return false
end

-- param position
-- param range
-- param type
-- param orderBy
-- output entity
-- output list
function findNpc(args, board)
  if args.position == nil then return false end

  local npcs = world.entityQuery(args.position, args.range, { includedTypes = {"npc"}, order = args.orderBy })
  if args.type then
    local filtered = {}
    for _,entityId in pairs(npcs) do
      if world.npcType(entityId) == args.type then
        table.insert(filtered, entityId)
      end
    end
    npcs = filtered
  end

  if #npcs > 0 then
    return true, {entity = npcs[1], list = npcs}
  end
  return false
end

-- param position
-- param range
-- param type
-- param orderBy
-- output entity
-- output list
function findStagehand(args, board)
  if args.position == nil then return false end

  local stagehands = world.entityQuery(args.position, args.range, { includedTypes = {"stagehand"}, order = args.orderBy })
  if args.type then
    local filtered = {}
    for _,entityId in pairs(stagehands) do
      if world.stagehandType(entityId) == args.type then
        table.insert(filtered, entityId)
      end
    end
    stagehands = filtered
  end

  if #stagehands > 0 then
    return true, {entity = stagehands[1], list = stagehands}
  end
  return false
end
