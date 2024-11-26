require("/scripts/util.lua")
require("/scripts/rect.lua")

local function canStandAt(boundBox)
  local collidesHere = world.rectTileCollision(boundBox, {"Block", "Null"})
  local collidesBelow = world.rectTileCollision(rect.translate(boundBox, {0, -1}), {"Block", "Platform", "Dynamic"})
  return not collidesHere and collidesBelow
end

-- Return a position where an entity with the given boundBox can stand without
-- colliding with any tiles.
-- Returns nil if there are no valid positions (which may occur if the region
-- is not loaded or there just isn't space).
function findSpaceInRect(region, boundBox)
  function checkPosition(x, y)
    local translatedBox = rect.translate(boundBox, {x, y})
    local ll = rect.ll(translatedBox)
    local ur = rect.ur(translatedBox)
    return rect.contains(region, ll) and rect.contains(region, ur) and canStandAt(translatedBox)
  end

  if not world.loadRegion(region) then
    return nil
  end

  local innerRegion = {math.ceil(region[1] - boundBox[1]), math.ceil(region[2] - boundBox[2]), math.floor(region[3] - boundBox[3]), math.floor(region[4] - boundBox[4])}

  if innerRegion[1] >= innerRegion[3] or innerRegion[2] >= innerRegion[4] then
    return nil
  end

  for i = 1, 5 do
    local x = math.random(innerRegion[1], innerRegion[3])
    local initialY = math.random(innerRegion[2], innerRegion[4])
    for y = initialY, initialY-5, -1 do
      if checkPosition(x, y) then
        return {x, y}
      end
    end
  end

  local validPositions = {}
  for x = innerRegion[1], innerRegion[3] do
    for y = innerRegion[2], innerRegion[4] do
      if checkPosition(x,y) then
        table.insert(validPositions, {x, y})
      end
    end
  end
  if #validPositions > 0 then
    return validPositions[math.random(#validPositions)]
  end

  return nil
end
