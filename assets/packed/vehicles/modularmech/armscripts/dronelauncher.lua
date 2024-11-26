require "/vehicles/modularmech/armscripts/base.lua"
require "/scripts/poly.lua"

DroneLauncher = MechArm:extend()

function DroneLauncher:init()
  self.state = FSM:new()
  self.directives = config.getParameter("partDirectives", {})[self.armName] or ""
  self.droneIds = {}

  if self.droneOrbitRate then
    self.droneOrbitAngle = 0
  end
end

function DroneLauncher:update(dt)
  self:updateDrones()

  if self.state.state then
    self.state:update()
  end

  if not self.state.state then
    if self.fireTriggered and #self.droneIds < self.maxDrones then
      self.state:set(self.deployState, self)
    end
  end

  if not self.state.state then
    self.bobLocked = false
  end
end

function DroneLauncher:deployState()
  animator.setAnimationState(self.armName, "rotate")

  self.bobLocked = true

  while self.isFiring do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)
    coroutine.yield()
  end

  animator.setAnimationState(self.armName, "windup")

  local stateTimer = self.deployTime
  while stateTimer > 0 do
    if stateTimer > self.launchTiming and stateTimer - self.launchTiming < script.updateDt() then
      if not self:rayCheck(self.firePosition) then
        animator.setAnimationState(self.armName, "idle")
        self.state:set()
        return
      end

      self:deployDrone()
      animator.playSound(self.armName .. "Activate")
    end

    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)
    stateTimer = stateTimer - script.updateDt()
    coroutine.yield()
  end

  self.state:set(self.cooldownState, self)
end

function DroneLauncher:cooldownState()
  self.bobLocked = false

  animator.setAnimationState(self.armName, "cooldown")

  local stateTimer = self.cooldownTime
  while stateTimer > 0 do
    stateTimer = stateTimer - script.updateDt()
    coroutine.yield()
  end

  animator.setAnimationState(self.armName, "recover")
  animator.playSound(self.armName .. "Recover")

  self.state:set()
end

function DroneLauncher:deployDrone()
  self.droneParameters.parentEntity = entity.id()
  self.droneParameters.directives = self.directives
  self.droneParameters.initialVelocity = mcontroller.velocity()
  self.droneParameters.initialRotation = self.facingDirection > 0 and self.aimAngle or (math.pi - self.aimAngle)

  local insPos = 1
  if self.droneParameters.movementMode == "Orbit" then
    if #self.droneIds > 0 then
      local currentAngles = self:droneAngles(#self.droneIds)
      local deployAngle = vec2.angle(world.distance(self.firePosition, mcontroller.position()))
      local bestDiff = 8

      for i, angle in ipairs(currentAngles) do
        local diff = util.angleDiff(angle, deployAngle)
        if math.abs(diff) < bestDiff then
          bestDiff = math.abs(diff)
          insPos = i
          if diff < 0 then
            insPos = i
          else
            insPos = i + 1
          end
        end
      end
    else

    end

    local targetOffset = vec2.rotate({self.droneOrbitDistance, 0}, self.aimAngle)
    targetOffset[1] = targetOffset[1] * self.facingDirection
    self.droneParameters.targetOffset = targetOffset
  end

  local droneId = world.spawnMonster(self.droneMonsterType, self.firePosition, self.droneParameters)
  table.insert(self.droneIds, insPos, droneId)
end

function DroneLauncher:updateDrones()
  self.droneIds = util.filter(self.droneIds, function(dId)
      if world.entityExists(dId) then
        return true
      end
      return false
    end)

  if self.droneOrbitRate and #self.droneIds > 0 then
    self.droneOrbitAngle = util.wrapAngle(self.droneOrbitAngle + self.droneOrbitRate * script.updateDt())
    local angles = self:droneAngles(#self.droneIds)
    for i, angle in ipairs(angles) do
      local targetOffset = vec2.rotate({self.droneOrbitDistance, 0}, angle)
      world.sendEntityMessage(self.droneIds[i], "setTargetOffset", targetOffset)
    end
  end
end

function DroneLauncher:droneAngles(droneCount)
  if droneCount <= 1 then
    return {self.droneOrbitAngle}
  end

  local interval = (math.pi * 2) / droneCount
  local angle = self.droneOrbitAngle
  local angles = {}
  while #angles < droneCount do
    table.insert(angles, angle)
    angle = angle + interval
  end
  return angles
end
