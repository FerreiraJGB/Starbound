require "/scripts/versioningutils.lua"

function update(data)
  data.shipUpgrades.maxFuel = root.assetJson("/ships/shipupgrades.config:maxFuel")
  data.shipUpgrades.fuelEfficiency = root.assetJson("/ships/shipupgrades.config:fuelEfficiency")
  data.shipUpgrades.shipSpeed = root.assetJson("/ships/shipupgrades.config:shipSpeed")

  return data
end