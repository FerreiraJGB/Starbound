require "/scripts/versioningutils.lua"

function update(data)
  if data.worldTemplate.worldParameters and data.worldTemplate.worldParameters.typeName == "moon" then
    replaceInData(data, "threatLevel", 10, 1)
    replaceInData(data, "spawnTypes", nil, jarray())
  end

  return data
end
