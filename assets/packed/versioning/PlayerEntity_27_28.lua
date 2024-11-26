function update(data)
  data.inventory.currencies = {
    money = data.inventory.money
  }

  data.inventory.money = nil

  return data
end
