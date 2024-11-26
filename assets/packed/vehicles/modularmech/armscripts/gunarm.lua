require "/vehicles/modularmech/armscripts/base.lua"

GunArm = MechArm:extend()

function GunArm:init()
  self.extendTimer = 0
  self.fireTimer = 0
end

function GunArm:update(dt)
  self.extendTimer = math.max(0, self.extendTimer - dt)
  if self.isFiring then
    self.extendTimer = self.extendTime
  end

  self.fireTimer = math.max(0, self.fireTimer - dt)

  if self.driverId and self.extendTimer > 0 then
    if self.isFiring and self.fireTimer == 0 then
      self:fire()

      animator.burstParticleEmitter(self.armName .. "Fire")
      animator.playSound(self.armName .. "Fire")
      animator.setAnimationState(self.armName, "winddown", true)

      self.fireTimer = self.fireTime
    end

    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    self.bobLocked = true
  else
    animator.setAnimationState(self.armName, "idle")

    self.bobLocked = false
  end
end
