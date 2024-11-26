require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.targetPosition = config.getParameter("targetPosition")
  self.rotationRate = config.getParameter("rotationRate")
  self.trackingLimit = config.getParameter("trackingLimit")

  local ttlVariance = config.getParameter("timeToLiveVariance")
  if ttlVariance then
    projectile.setTimeToLive(projectile.timeToLive() + sb.nrand(ttlVariance))
  end

  message.setHandler("setTargetPosition", function(_, _, targetPosition)
      self.targetPosition = targetPosition
    end)
end

function update(dt)
  if self.targetPosition then
    local toTarget = world.distance(self.targetPosition, mcontroller.position())

    local curVel = mcontroller.velocity()
    local curAngle = vec2.angle(curVel)

    local toTargetAngle = util.angleDiff(curAngle, vec2.angle(toTarget))

    if math.abs(toTargetAngle) > self.trackingLimit then
      return
    end

    local rotateAngle = math.max(dt * -self.rotationRate, math.min(toTargetAngle, dt * self.rotationRate))

    mcontroller.setVelocity(vec2.rotate(curVel, rotateAngle))
  end
  mcontroller.setRotation(math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1]))
end
