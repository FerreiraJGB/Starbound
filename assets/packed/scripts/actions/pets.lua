require "/scripts/companions/capturable.lua"

-- param owner
function hasOwner(args, board)
  return (args.owner ~= nil and world.entityExists(args.owner)) or capturable.ownerUuid() ~= nil
end

-- param owner
-- output entity
function ownerEntity(args, board)
  local owner = args.owner
  if args.owner == nil then
    local uuid = capturable.ownerUuid()
    if not uuid then return false end

    owner = world.loadUniqueEntity(uuid)
  end
  if not owner or not world.entityExists(owner) then return false end
  return true, {entity = owner}
end

-- output entity
function tetherEntity(args, output)
  local uniqueId = capturable.tetherUniqueId() or storage.respawner
  if not uniqueId then return false end

  local entityId = world.loadUniqueEntity(uniqueId)
  if not entityId or not world.entityExists(entityId) then return false end

  return true, {entity = entityId}
end
