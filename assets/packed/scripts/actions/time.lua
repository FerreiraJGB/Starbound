require "/scripts/util.lua"

function timeRange(time)
  if time == nil then return nil end
  if type(time) == "table" then
    return math.random() * (time[2] - time[1]) + time[1]
  else
    return time
  end
end

-- param time
-- output ratio
function timer(args, board, _, dt)
  local timer = timeRange(args.time)
  local max = timer

  while timer > 0 do
    timer = timer - dt
    dt = coroutine.yield(nil, {ratio = (max - timer) / max})
  end

  return true, {ratio = 1.0}
end

-- param range
function withinTimeRange(args, board)
  local timeOfDay = world.timeOfDay()
  return util.isTimeInRange(timeOfDay, args.range)
end
