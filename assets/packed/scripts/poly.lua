require "/scripts/vec2.lua"
require "/scripts/util.lua"

poly = {}

function poly.handPosition(points)
  local translated = {}
  for _,point in pairs(points) do
    table.insert(translated, activeItem.handPosition(point))
  end
  return translated
end

function poly.translate(points, offset)
  local translated = {}
  for _,point in pairs(points) do
    table.insert(translated, vec2.add(point, offset))
  end
  return translated
end

function poly.rotate(points, angle)
  return util.map(points, function(point)
    return vec2.rotate(point, angle)
  end)
end

function poly.scale(points, scale)
  return util.map(points, function(point)
    return vec2.mul(point, scale)
  end)
end

function poly.center(points)
  local center = {0,0}
  for _,point in pairs(points) do
    center = vec2.add(center, point)
  end
  center = vec2.div(center, #points)
  return center
end

function poly.flip(points)
  local flipped = {}
  for _,point in pairs(points) do
    table.insert(flipped, {-point[1], point[2]})
  end
  return flipped
end

function poly.boundBox(points)
  local x1, y1, x2, y2
  for _, point in ipairs(points) do
    x1 = math.min(point[1], x1 or point[1])
    x2 = math.max(point[1], x2 or point[1])
    y1 = math.min(point[2], y1 or point[2])
    y2 = math.max(point[2], y2 or point[2])
  end
  return {x1, y1, x2, y2}
end
