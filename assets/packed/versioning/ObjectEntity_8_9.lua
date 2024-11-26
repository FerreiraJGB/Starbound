function update(data)
  if data.name == "fossildisplay1" or data.name == "fossildisplay3" or data.name == "fossildisplay5" then
    if data.parameters.fossilComplete then
      local firstFossilConfig = root.itemConfig(data.parameters.fossilList[1]).config
      local setCollectables = firstFossilConfig.setCollectables
      if setCollectables then
        data.parameters.collectablesOnPickup = setCollectables
      end
    end
  end
  return data
end