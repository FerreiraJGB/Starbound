function update(data)
  if data.type == "questmanager" then
    if not data.scriptStorage.participantsReserved then
      data.scriptStorage.participantsReserved = true
    end
  end

  return data
end
