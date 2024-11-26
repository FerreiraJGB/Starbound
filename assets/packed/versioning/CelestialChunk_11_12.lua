require "/scripts/versioningutils.lua"

function update(data)
  local systemTypes = {}
  for name,type in pairs(root.assetJson("/celestial.config:systemTypes")) do
    systemTypes[type.baseParameters.typeName] = type
  end

  for _,star in pairs(data.systemParameters) do
    local coordinate, systemParameters = star[1], star[2]
    local threatLevel = systemTypes[systemParameters.parameters.typeName].baseParameters.spaceThreatLevel
    if threatLevel == nil then
      error(string.format("No spaceThreatLevel specified for system with typeName %s in celestial.config", systemParameters.parameters.typeName))
    end
    systemParameters.parameters.spaceThreatLevel = threatLevel
  end

  return data
end
