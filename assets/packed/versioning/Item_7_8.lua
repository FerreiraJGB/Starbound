function update(data)
  -- fossil collectables
  if data.name == "fossildisplay1" or data.name == "fossildisplay3" or data.name == "fossildisplay5" then
    if data.parameters.fossilComplete then
      local firstFossilConfig = root.itemConfig(data.parameters.fossilList[1]).config
      local setCollectables = firstFossilConfig.setCollectables
      if setCollectables then
        data.parameters.collectablesOnPickup = setCollectables
      end
    end
  end

  -- monster collectables
  if data.name == "filledcapturepod" then
    local pet = data.parameters.pets[1].config
    local petConfig = root.monsterParameters(pet.type)
    if petConfig.captureCollectables then
      data.parameters.collectablesOnPickup = petConfig.captureCollectables
    end
  end
  return data
end