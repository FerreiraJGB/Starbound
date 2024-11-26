require "/scripts/versioningutils.lua"

function update(data)
  -- set spawn time of permanent objects
  -- remove non-permanent objects
  local keep = jarray()
  for _,object in pairs(data.objects) do
    if root.systemObjectTypeConfig(object.name).permanent then
      object.spawnTime = 0
      table.insert(keep, object)
    end
  end
  data.objects = keep

  -- set last spawn to be at the beginning of time
  -- this is later clamped to be a minimum of systemworld.config::objectSpawnCycle in the past
  data.lastSpawn = 0;
  return data
end