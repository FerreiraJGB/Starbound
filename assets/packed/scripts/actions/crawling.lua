require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"

-- Crawl up on walls and ceilings
-- Requires the bound box to be square with the origin in the center

-- param direction
-- param run
-- output headingDirection
-- output headingAngle
function crawl(args, board)
  local bounds = mcontroller.boundBox()
  local size = bounds[3] - bounds[1]

  local groundDirection = findGroundDirection()
  if not groundDirection then return false end

  local baseParameters = mcontroller.baseParameters()
  local moveSpeed = args.run and baseParameters.runSpeed or baseParameters.walkSpeed

  local headingAngle
  while true do
    local groundDirection = findGroundDirection()

    if groundDirection then
      if not headingAngle then
        headingAngle = (math.atan(groundDirection[2], groundDirection[1]) + math.pi / 2) % (math.pi * 2)
      end

      if args.direction == nil then return false end

      headingAngle = adjustCornerHeading(headingAngle, args.direction)

      local groundAngle = headingAngle - (math.pi / 2)
      mcontroller.controlApproachVelocity(vec2.withAngle(groundAngle, moveSpeed), 50)

      local moveDirection = vec2.rotate({args.direction, 0}, headingAngle)
      mcontroller.controlApproachVelocityAlongAngle(math.atan(moveDirection[2], moveDirection[1]), moveSpeed, 2000)

      mcontroller.controlParameters({
        gravityEnabled = false
      })

      coroutine.yield(nil, {headingDirection = vec2.withAngle(headingAngle), headingAngle = headingAngle})
    else
      break
    end
  end

  return false, {headingDirection = {1, 0}, forwardAngle = 0}
end

-- param rotationRate
function wallSit(args, board)
  local bounds = mcontroller.boundBox()
  while true do
    -- Fail when not adjacent to any blocks
    local groundDirection = findGroundDirection()
    if not groundDirection then break end

    -- Smoothly rotate to the ground slope
    local headingAngle = (math.atan(groundDirection[2], groundDirection[1]) + math.pi / 2) % (math.pi * 2)
    headingAngle = adjustCornerHeading(headingAngle, mcontroller.facingDirection())

    mcontroller.controlParameters({
      gravityEnabled = false
    })
    coroutine.yield(nil, {groundDirection = groundDirection, forwardAngle = headingAngle})
  end

  return false, {groundDirection = {0, -1}, forwardAngle = 0}
end

function adjustCornerHeading(headingAngle, direction)
  -- adjust direction for concave corners
  local adjustment = 0
  for a = 0, math.pi, math.pi / 4 do
    local testPos = vec2.add(mcontroller.position(), vec2.rotate({direction * 0.25, 0}, headingAngle + (direction * a)))
    adjustment = direction * a
    if not world.polyCollision(poly.translate(poly.scale(mcontroller.collisionPoly(), 1.0), testPos)) then
      break
    end
  end
  headingAngle = headingAngle + adjustment

  -- adjust direction for convex corners
  adjustment = 0
  for a = 0, -math.pi, -math.pi / 4 do
    local testPos = vec2.add(mcontroller.position(), vec2.rotate({direction * 0.25, 0}, headingAngle + (direction * a)))
    if world.polyCollision(poly.translate(poly.scale(mcontroller.collisionPoly(), 1.0), testPos)) then
      break
    end
    adjustment = direction * a
  end
  headingAngle = headingAngle + adjustment
  return headingAngle
end

function findGroundDirection(testDistance)
  testDistance = testDistance or 0.25
  for i = 0, 7 do
    local angle = (i * math.pi / 4) - math.pi / 2
    local collisionSet = i == 1 and self.platformCollisionSet or self.normalCollisionSet
    local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
    if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos), nil, collisionSet) then
      return vec2.withAngle(angle, 1.0)
    end
  end
end
