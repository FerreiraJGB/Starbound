require "/scripts/vec2.lua"

function toRadians(degrees)
  return (degrees / 180) * math.pi
end

function init()
  self.delay = config.getParameter("delay")

  self.initialVelocity = mcontroller.velocity()

  self.dirX = 1
  if self.initialVelocity[1] < 0.0 then
    self.dirX = -1
  end

  local angle = toRadians(60)
  local approachAngle = -angle + math.random() * (2 * angle)
  local minRange = 4 + (math.abs(approachAngle) / angle * 4)
  local maxRange = 10
  local approachDistance = minRange + math.random() * (maxRange - minRange)
  self.approachPosition = vec2.add(mcontroller.position(), vec2.mul(vec2.withAngle(approachAngle, approachDistance), {self.dirX, 1.0}))

  self.state = 1
  self.timer = 0.0
  self.lastTargetDir = nil

  message.setHandler("setTargetPosition", function(_, _, pos)
      self.targetPosition = pos
      self.lastTargetDir = nil
      self.state = 3
    end)

  message.setHandler("explode", function(_, _)
      self.deathTimer = math.random() * 1.0
    end)
end

function update(dt)
  if self.deathTimer then
    self.deathTimer = self.deathTimer - dt
    if self.deathTimer < 0.0 then
      projectile.die()
    end
    return
  end

  if self.state == 1 then
    local toApproach = world.distance(self.approachPosition, mcontroller.position())
    local distance = world.magnitude(toApproach)
    local speed = math.max(2.0, math.min(20, distance * 1.5))
    mcontroller.approachVelocity(vec2.mul(vec2.norm(toApproach), speed), 20)

    if self.lastTargetDir ~= nil and vec2.dot(self.lastTargetDir, toApproach) < 0.0 then
      self.state = 2
    end
    self.lastTargetDir = toApproach
  elseif self.state == 2 then
    -- do nothing until a target is received

  elseif self.state == 3 then
    local toTarget = world.distance(self.targetPosition, mcontroller.position())
    mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), 25), 40)

    if self.lastTargetDir ~= nil and vec2.dot(self.lastTargetDir, toTarget) < 0.0 then
      projectile.die()
    end
    self.lastTargetDir = toTarget
  end
end
