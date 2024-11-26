require "/vehicles/modularmech/armscripts/base.lua"

GatlingArm = MechArm:extend()

function GatlingArm:init()
  self.windupTimer = 0
  self.fireTimer = 0
end

function GatlingArm:update(dt)
  if self.isFiring then
    self.windupTimer = math.min(self.windupTimer + dt, self.windupTime)
  else
    self.windupTimer = math.max(0, self.windupTimer - dt)
  end

  if self.fireTriggered then
    animator.setAnimationState(self.armName, "windup")
  elseif self.wasFiring and not self.isFiring then
    animator.setAnimationState(self.armName, "winddown")
  end

  self.fireTimer = math.max(0, self.fireTimer - dt)

  if self.driverId and self.windupTimer > 0 then
    if self.isFiring and self.windupTimer == self.windupTime and self.fireTimer == 0 then
      self:fire()

      animator.burstParticleEmitter(self.armName .. "Fire")
      animator.playSound(self.armName .. "Fire")

      self.fireTimer = self.fireTime
    end

    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    self.bobLocked = true
  else
    animator.setAnimationState(self.armName, "idle")

    self.bobLocked = false
  end
end
