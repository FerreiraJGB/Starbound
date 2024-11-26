require "/scripts/vec2.lua"

rect = {}

function rect.zero()
  return {0,0,0,0}
end

function rect.translate(rectangle, offset)
  return {
    rectangle[1] + offset[1], rectangle[2] + offset[2],
    rectangle[3] + offset[1], rectangle[4] + offset[2]
  }
end

function rect.ll(rectangle)
  return {rectangle[1], rectangle[2]}
end

function rect.lr(rectangle)
  return {rectangle[3], rectangle[2]}
end

function rect.ur(rectangle)
  return {rectangle[3], rectangle[4]}
end

function rect.ul(rectangle)
  return {rectangle[1], rectangle[4]}
end

function rect.fromVec2(min, max)
  return {min[1], min[2], max[1], max[2]}
end

function rect.withSize(min, size)
  return {min[1], min[2], min[1] + size[1], min[2] + size[2]}
end

function rect.withCenter(center, size)
  return {center[1] - size[1] / 2, center[2] - size[2] / 2, center[1] + size[1] / 2, center[2] + size[2] / 2}
end

function rect.size(rectangle)
  return {
    rectangle[3] - rectangle[1],
    rectangle[4] - rectangle[2]
  }
end

function rect.center(rectangle)
  return {
    rectangle[1] + (rectangle[3] - rectangle[1]) * 0.5,
    rectangle[2] + (rectangle[4] - rectangle[2]) * 0.5
  }
end

function rect.randomPoint(rectangle)
  return {
    math.random() * (rectangle[3] - rectangle[1]) + rectangle[1],
    math.random() * (rectangle[4] - rectangle[2]) + rectangle[2]
  }
end

function rect.intersects(first, second)
  if first[1] > second[3]
     or first[3] < second[1]
     or first[2] > second[4]
     or first[4] < second[2] then
    return false
  else
    return true
  end
end

function rect.rotate(rectangle, angle)
  local ll = rect.ll(rectangle)
  local ur = rect.ur(rectangle)
  ll = vec2.rotate(ll, angle)
  ur = vec2.rotate(ur, angle)

  return {
    math.min(ll[1], ur[1]), math.min(ll[2], ur[2]),
    math.max(ll[1], ur[1]), math.max(ll[2], ur[2])
  }
end

function rect.flipX(rectangle)
  return {-rectangle[3], rectangle[2], -rectangle[1], rectangle[4]}
end

function rect.scale(rectangle, scale)
  if type(scale) == "table" then
    return {rectangle[1] * scale[1], rectangle[2] * scale[2], rectangle[3] * scale[1], rectangle[4] * scale[2]}
  else
    return {rectangle[1] * scale, rectangle[2] * scale, rectangle[3] * scale, rectangle[4] * scale}
  end
end

function rect.pad(rectangle, padding)
  if type(padding) == "table" then
    return {rectangle[1] - padding[1], rectangle[2] - padding[2], rectangle[3] + padding[1], rectangle[4] + padding[2]}
  else
    return {rectangle[1] - padding, rectangle[2] - padding, rectangle[3] + padding, rectangle[4] + padding}
  end
end

function rect.contains(rectangle, point)
  return point[1] >= rectangle[1]
     and point[2] >= rectangle[2]
     and point[1] <= rectangle[3]
     and point[2] <= rectangle[4]
end

function rect.snap(rect, point, direction)
  if direction[1] < 0 then
    return {rect[1], point[2]}
  elseif direction[1] > 0 then
    return {rect[3], point[2]}
  elseif direction[2] < 0 then
    return {point[1], rect[2]}
  elseif direction[2] > 0 then
    return {point[1], rect[4]}
  end
end

function rect.bound(inner, outer)
  if inner[4] > outer[4] then
    inner = rect.translate(inner, {0, outer[4] - inner[4]})
  elseif inner[2] < outer[2] then
    inner = rect.translate(inner, {0, outer[2] - inner[2]})
  end
  if inner[3] > outer[3] then
    inner = rect.translate(inner, {outer[3] - inner[3], 0})
  elseif inner[1] < outer[1] then
    inner = rect.translate(inner, {outer[1] - inner[1], 0})
  end
  return inner
end
