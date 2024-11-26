interp = {}

function interp.linear(ratio, a, b)
  return a + ((b - a) * ratio)
end

function interp.sin(ratio, a, b)
  return a + (b - a) * math.sin(ratio * math.pi / 2)
end

function interp.cos(ratio, a, b)
  return a + (b - a) * math.cos(ratio * math.pi / 2)
end

function interp.reverse(func)
  return function(ratio, a, b)
    return func(1 - ratio, a, b)
  end
end

-- Takes a list of ranges to interpolate through in the format
-- {maxRatio, interpolationFunction, fromValue, toValue}
--
-- Example:
-- interp.ranges(ratio, {
--   {0.5, interp.linear, 3, 8},
--   {0.75, interp.linear, 8, 5},
--   {1.0, interp.linear, 5, 6}
-- })
function interp.ranges(ratio, ranges)
  for i,range in pairs(ranges) do
    if ratio <= range[1] then
      local startRatio = 0
      if ranges[i - 1] then startRatio = ranges[i - 1][1] end
      local subRatio = (ratio - startRatio) / (range[1] - startRatio)
      return range[2](subRatio, range[3], range[4])
    end
  end
end

-- returns the shortest angle difference for interpolating between angles
-- angles are in radians
function interp.angleDiff(from, to)
  return ((((to - from) % (2 * math.pi)) + (3 * math.pi)) % (2 * math.pi)) - math.pi
end
