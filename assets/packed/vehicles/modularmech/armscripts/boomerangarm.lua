require "/vehicles/modularmech/armscripts/base.lua"

Boomerang = MechArm:extend()

function Boomerang:init()
  self.state = FSM:new()
  self.directives = config.getParameter("partDirectives", {})[self.armName] or ""
  self.projectileIds = {}
end

function Boomerang:update(dt)
  self:updateProjectiles()

  if self.state.state then
    self.state:update()
  end

  if not self.state.state then
    if self.fireTriggered then
      self.state:set(self.fireState, self)
    end
  end

  if not self.state.state then
    self.bobLocked = false
  end
end

function Boomerang:updateProjectiles()
  local newProjectileIds = {}
  for i, projectileId in ipairs(self.projectileIds) do
    if world.entityExists(projectileId) then
      world.sendEntityMessage(projectileId, "setTargetPosition", self.firePosition)

      local projectileIdsMessage = world.sendEntityMessage(projectileId, "projectileIds")
      if projectileIdsMessage:finished() and projectileIdsMessage:succeeded() then
        updatedProjectileIds = projectileIdsMessage:result()
        if updatedProjectileIds then
          for j, updatedProjectileId in ipairs(updatedProjectileIds) do
            table.insert(newProjectileIds, updatedProjectileId)
          end
        end
      end
    end
  end
  self.projectileIds = newProjectileIds
end

function Boomerang:fireState()
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

function Boomerang:cooldownState()
  while #self.projectileIds > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)
    coroutine.yield()
  end

  animator.setAnimationState(self.armName, "recover")
  animator.playSound(self.armName .. "Recover")

  self.state:set()
end
