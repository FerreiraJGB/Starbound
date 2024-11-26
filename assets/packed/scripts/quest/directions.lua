require("/scripts/vec2.lua")
require("/scripts/util.lua")

local function directionInRange(direction, angleRange)
  -- This breaks if the angle range >= 180 degrees
  local min = vec2.rotate({0, -1}, util.toRadians(angleRange[1]))
  local max = vec2.rotate({0, -1}, util.toRadians(angleRange[2]))

  local minDiff = vec2.sub(min, direction)
  local maxDiff = vec2.sub(max, direction)
  local dot = vec2.dot(minDiff, maxDiff)
  return dot <= 0
end

function describeDirection(targetPosition)
  local direction = vec2.norm(world.distance(entity.position(), targetPosition))

  local descriptions = nil
  for _,directionDef in pairs(config.getParameter("directions") or root.assetJson("/quests/quests.config:directions")) do
    if directionInRange(direction, directionDef.angleRange) then
      return directionDef.descriptions[math.random(#directionDef.descriptions)]
    end
  end

  return ""
end
