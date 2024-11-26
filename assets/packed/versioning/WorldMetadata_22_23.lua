require "/scripts/versioningutils.lua"

function update(data)
  transformInData(data, "weatherPool", function(pool)
      local newPool = jarray()
      for i, weatherPair in ipairs(pool) do
        table.insert(newPool, {weatherPair[1], weatherPair[2].name})
      end
      return newPool
    end)

  return data
end
