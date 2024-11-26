require "/scripts/vec2.lua"
require "/scripts/poly.lua"

function dashedLine(line, dashLength, gapLength, startOffset)
  local lines = {}

  local offset = (startOffset % 1) * (dashLength + gapLength)
  local angle = vec2.angle(vec2.sub(line[2], line[1]))
  while not compare(line[1], line[2]) do
    if offset < dashLength then
      local lineEnd = vec2.add(line[1], vec2.withAngle(angle, dashLength - offset))
      if vec2.dot(vec2.sub(line[2], lineEnd), vec2.sub(line[2], line[1])) < 0 then
        lineEnd = line[2]
      end
      table.insert(lines, {line[1], lineEnd})
    end

    local newFrom = vec2.add(line[1], vec2.withAngle(angle, gapLength + dashLength - offset))
    if vec2.dot(vec2.sub(line[2], newFrom), vec2.sub(line[2], line[1])) < 0 then
      line[1] = line[2]
    else
      line[1] = newFrom
    end
    offset = 0
  end

  return lines
end

function angledMarkerLines(distance, length, width)
  local intersectPoint = vec2.withAngle(math.pi / 4, distance)
  local line1 = {vec2.add(intersectPoint, {-width / 2, 0}), vec2.add(intersectPoint, {length, 0})}
  local line2 = {vec2.add(intersectPoint, {0, -width / 2}), vec2.add(intersectPoint, {0, length})}
  local lines = {}
  for i = 0, 3 do
    table.insert(lines, poly.rotate(line1, i * math.pi / 2 + math.pi / 4))
    table.insert(lines, poly.rotate(line2, i * math.pi / 2 + math.pi / 4))
  end
  return lines
end

function circle(radius, points, center)
  local poly = {}
  center = center or {0, 0}
  for i = 0, points - 1 do
    local angle = (i / points) * math.pi * 2
    table.insert(poly, vec2.add(center, vec2.withAngle(angle, radius)))
  end
  return poly
end

function wideCircle(radius, points, width, center)
  local outer = circle(radius + width / 2, points, center)
  local inner = circle(radius - width / 2, points, center)
  local triangles = {}
  for i = 1, #inner do
    local j = i == #inner and 1 or i + 1
    table.insert(triangles, {inner[i], outer[i], inner[j]})
    table.insert(triangles, {outer[i], outer[j], inner[j]})
  end
  return triangles
end

function fillCircle(radius, points, center)
  local outer = circle(radius, points, center)
  local triangles = {}
  for i = 1, #outer do
    local j = i == #outer and 1 or i + 1
    table.insert(triangles, {center, outer[i], outer[j]})
  end
  return triangles
end
