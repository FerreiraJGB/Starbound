require "/scripts/versioningutils.lua"

function update(data)
  executeWhere(data, "typeName", "moon", function(moon)
      replaceInData(moon, "threatLevel", 10, 1)
      replaceInData(moon, "biome", "atmosphere", "void")
      replaceInData(moon, "biome", "asteroids", "barrenasteroids")
    end)

  return data
end
