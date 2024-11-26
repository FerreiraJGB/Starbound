require "/vehicles/modularmech/armscripts/base.lua"

RemoteDetonator = MechArm:extend()

function RemoteDetonator:init()
  self.state = FSM:new()
  self.projectileIds = {}
end

function RemoteDetonator:update(dt)
  self:updateProjectiles()

  if self.state.state then
    self.state:update()
  end

  if self.fireTriggered then
    if #self.projectileIds > 0 then
      self:triggerProjectiles()
      animator.playSound(self.armName .. "Trigger")
    elseif not self.state.state then
      self.state:set(self.fireState, self)
    end
  end

  if not self.state.state then
    self.bobLocked = false
  end
end

function RemoteDetonator:triggerProjectiles()
  for _, pId in ipairs(self.projectileIds) do
    world.sendEntityMessage(pId, "triggerRemoteDetonation")
  end
end

function RemoteDetonator:updateProjectiles()
  self.projectileIds = util.filter(self.projectileIds, function(pId)
      if world.entityExists(pId) then
        world.sendEntityMessage(pId, "setTargetPosition", self.aimPosition)
        return true
      end
      return false
    end)
end

function RemoteDetonator:fireState()
  self.bobLocked = true

  animator.setAnimationState(self.armName, "rotate")

  local stateTimer = self.windupTime
  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    stateTimer = stateTimer - script.updateDt()
    coroutine.yield()
  end

  if not self:rayCheck(self.firePosition) then
    animator.setAnimationState(self.armName, "idle")
    self.state:set()
    return
  end

  animator.setAnimationState(self.armName, "windup")
  animator.playSound(self.armName .. "Fire")

  local projectileIds = self:fire()
  util.appendLists(self.projectileIds, projectileIds)

  stateTimer = self.fireTime
  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    stateTimer = stateTimer - script.updateDt()
    coroutine.yield()
  end

  self.state:set(self.cooldownState, self)
end

function RemoteDetonator:cooldownState()
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
