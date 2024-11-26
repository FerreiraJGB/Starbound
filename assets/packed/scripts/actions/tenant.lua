require "/scripts/tenant.lua"

function hasGrumbles(args, board)
  return storage.grumbles and #storage.grumbles > 0
end

function sayGrumble(args, board)
  if storage.grumbles and #storage.grumbles > 0 then
    local grumble = storage.grumbles[math.random(#storage.grumbles)][1]
    return sayToEntity({ dialogType = "dialog.tenant.grumbles." .. grumble, entity = entity.id(), tags = {} })
  end
  return false
end

function spawnRentTreasure(args, board)
  local promise = world.sendEntityMessage(storage.respawner, "getRent")
  while not promise:finished() do
    coroutine.yield()
  end

  local rent = promise:result()
  world.spawnTreasure(args.position, rent.pool, rent.level)
  return true
end

function replaceNpc(args, board)
  local npcType = args.npcType
  if type(npcType) == "table" then
    npcType = npcType[math.random(#npcType)]
  end

  tenant.setNpcType(npcType)
  return true
end
