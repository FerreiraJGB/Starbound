require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init(dt)
  setCannonSeatOffset({0,0})

  self.state = FSM:new()

  self.fireTimer = 0
  self.fireTime = 1.0
  self.aimAngle = 0
  self.facingDirection = 1

  self.state:set(aimState)
end

function setCannonSeatOffset(offset)
  animator.resetTransformationGroup("ammo")
  animator.translateTransformationGroup("ammo", offset)
  animator.rotateTransformationGroup("ammo", -math.pi/2)
end

function update()
  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  self.state:update()

  local aimDirection = world.distance(vehicle.aimPosition("main"), mcontroller.position())
  self.facingDirection = util.toDirection(aimDirection[1])
  animator.setFlipped(self.facingDirection < 0)

  if mcontroller.onGround() then
    local moveDir = 0
    if vehicle.controlHeld("main", "right") then
      moveDir = moveDir + 1
    end
    if vehicle.controlHeld("main", "left") then
      moveDir = moveDir - 1
    end

    if moveDir * aimDirection[1] > 0 then
      animator.setAnimationState("body", "move")
    elseif moveDir * aimDirection[1] < 0 then
      animator.setAnimationState("body", "movebackward")
    else
      animator.setAnimationState("body", "idle")
    end
    mcontroller.approachXVelocity(moveDir * config.getParameter("moveSpeed", 4), config.getParameter("groundForce", 200))
  end
end

function aimState()
  vehicle.setLoungeEnabled("cannon", true)

  while not vehicle.controlHeld("main", "primaryFire") do
    local aimDirection = world.distance(vehicle.aimPosition("main"), mcontroller.position())
    aimDirection[1] =  math.abs(aimDirection[1])
    self.aimAngle = vec2.angle(aimDirection)
    if self.aimAngle > math.pi then self.aimAngle = math.pi - self.aimAngle end
    self.aimAngle = util.clamp(self.aimAngle, 0, 0.75)
    animator.resetTransformationGroup("cannon")
    animator.rotateTransformationGroup("cannon", self.aimAngle, config.getParameter("cannonRotationCenter", {0.25, 1.5}))
    coroutine.yield()
  end

  self.state:set(loadState)
end

function loadState()
  animator.setAnimationState("cannon", "load")
  vehicle.setLoungeStatusEffects("cannon", {"ballisticapplier"})
  local timer = 0
  util.wait(0.4, function(dt)
    timer = timer + dt
    setCannonSeatOffset({0, timer * -1.25})
  end)
  setCannonSeatOffset({0, -1.25})

  util.wait(1.0)

  self.state:set(fireState)
end

function fireState()
  animator.setAnimationState("cannon", "fire")

  util.wait(0.08)
  setCannonSeatOffset({0, 2.5})

  vehicle.setLoungeEnabled("cannon", false)
  vehicle.setLoungeStatusEffects("cannon", {})

  self.state:set(cooldownState)
end

function cooldownState()
  util.wait(2.0)
  setCannonSeatOffset({0,0})

  self.state:set(aimState)
end
