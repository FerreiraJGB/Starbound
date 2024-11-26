require "/scripts/versioningutils.lua"

function update(data)
  transformInData(data, "worldParameters", function(worldParameters)
      if worldParameters.type == "AsteroidsWorldParameters" then
        worldParameters.worldEdgeForceRegions = "TopAndBottom"
        worldParameters.gravity = 0
      else
        worldParameters.worldEdgeForceRegions = "Top"
      end

      return worldParameters
    end)

  return data
end
