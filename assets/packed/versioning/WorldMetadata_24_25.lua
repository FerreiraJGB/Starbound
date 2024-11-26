require "/scripts/versioningutils.lua"

function update(data)
  data.dungeonIdGravity = {}
  -- Add all the dungeon gravity values
  for _,p in pairs(data.dungeonIdMap) do
    local dungeon = root.dungeonMetadata(p[2])
    if dungeon.gravity then
      table.insert(data.dungeonIdGravity, {p[1], dungeon.gravity})
    end
  end
  data.dungeonIdMap = nil

  -- Also add ZeroGDungeonId and ProtectedZeroGDungeonId
  table.insert(data.dungeonIdGravity, {65524, 0.0})
  table.insert(data.dungeonIdGravity, {65525, 0.0})

  return data
end
