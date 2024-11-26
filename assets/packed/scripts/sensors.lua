sensors = {}

-- Creates a lazy-execution container for reading environment data at sensor
-- locations. Can be accessed like a normal table, but will populate the
-- requested reading on the first access and use the result for subsequent
-- accesses (until clear is called).
--
-- Example usage:
--
--  -- in init:
--  self.sensors = sensors.create()
--
--  -- in update:
--  for i, reading in ipairs(self.sensors["environmentSensors"].light) do
--    sb.logInfo("reading: %s at %s", reading.value, reading.position)
--  end
--
--  -- can be at beginning or end of update
--  self.sensors.clear()
--
function sensors.create()
  -- Each probe function takes a world coordinate and returns some reading
  local probes = {
    light = world.lightLevel,
    wind = world.windLevel,
    temp = world.temperature,
    breathe = world.breathable,
    collision = function(position)
      return world.pointTileCollision(position, {"Null", "Block", "Dynamic", "Slippery"})
    end,
    collisionTrace = function(position)
      return world.lineTileCollision(mcontroller.position(), position, {"Null", "Block", "Dynamic", "Slippery"})
    end
  }

  -- Get a reading for the given probe type at all sensor positions in the
  -- given group
  local createReadings = function(sensorGroup, probeType)
    local readings = {}

    local probeFunction = probes[probeType]
    if probeFunction ~= nil then
      for i, sensor in ipairs(config.getParameter(sensorGroup)) do
        local sensorPosition = monster.toAbsolutePosition(sensor)
        table.insert(readings, {
          position = sensorPosition,
          value = probeFunction(sensorPosition)
        })
      end
    end

    readings.any = function(value)
      for i, reading in ipairs(readings) do
        if reading.value == value then
          return true
        end
      end

      return false
    end

    return readings
  end

  -- This is the actual storage for sensor data, there are two levels of proxies
  -- wrapped around this table:
  --  1. The proxy around the sensor group
  --  2. The proxy around each set of readings (a "probe") in a sensor group
  -- Both are read-only, lazily loading the requested data as it is accessed.
  local sensorGroups = {}

  local clear = function()
    for k, v in pairs(sensorGroups) do
      sensorGroups[k] = nil
    end
  end

  local sensorProxyMetatable = {
    __index = function(t, sensorGroup)
      if sensorGroup == "clear" then return clear end

      local probeProxy = sensorGroups[sensorGroup]
      if probeProxy == nil then
        local probe = {}
        local probeProxyMetatable = {
          __index = function(t, readingType)
            local readings = probe[readingType]

            if readings == nil then
              readings = createReadings(sensorGroup, readingType)
              probe[readingType] = readings
            end

            return readings
          end,

          __newindex = function(t, key, val) end
        }

        probeProxy = {}
        setmetatable(probeProxy, probeProxyMetatable)
        sensorGroups[sensorGroup] = probeProxy
      end

      return probeProxy
    end,

    __newindex = function(t, key, val) end
  }

  local sensorProxy = {}
  setmetatable(sensorProxy, sensorProxyMetatable)
  return sensorProxy
end
