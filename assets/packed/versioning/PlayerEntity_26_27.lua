function update(data)
  data.inventory.itemBags = jobject()
  
  local bags = {"mainBag", "materialBag", "objectBag", "reagentBag", "foodBag"}
  for _,bag in ipairs(bags) do
    data.inventory.itemBags[bag] = data.inventory[bag]
    data.inventory[bag] = nil
  end

  return data
end
