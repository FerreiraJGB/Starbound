function update(data)
  data.shipCoordinate = data.celestialLog.currentWorld
  data.systemLocation = {"coordinate", data.celestialLog.currentWorld}
  data.celestialLog = nil
  return data
end
