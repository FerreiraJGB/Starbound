require "/scripts/versioningutils.lua"

function update(data)
  local gp = {}

  local sp = data.statusController.statusProperties

  for _, propertyName in pairs({
      "vaultKeySeed",
      "mechUnlocked",
      "mechItemSet",
      "mechPrimaryColorIndex",
      "mechSecondaryColorIndex"
    }) do

    gp[propertyName] = sp[propertyName]
    sp[propertyName] = nil
  end

  data.genericProperties = gp

  return data
end
