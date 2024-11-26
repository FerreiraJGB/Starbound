require "/vehicles/modularmech/armscripts/base.lua"

DrillArm = MechArm:extend()

function DrillArm:init()
  self.spinTimer = 0
  self.tileDamageTimer = 0
end

function DrillArm:update(dt)
  if self.isFiring then
    self.spinTimer = math.min(self.spinUpDownTime, self.spinTimer + dt)
  else
    self.spinTimer = math.max(0, self.spinTimer - dt)
  end

  if self.isFiring or self.spinTimer > 0 then
    if self.spinTimer == self.spinUpDownTime then
      vehicle.setDamageSourceEnabled(self.armName .. "Drill", true)
      vehicle.setMovingCollisionEnabled(self.armName .. "Drill", true)
      self.tileDamageTimer = math.max(0, self.tileDamageTimer - dt)
      if self.tileDamageTimer == 0 then
        self.tileDamageTimer = self.tileDamageRate
        self:damageTiles()
      end
      animator.setAnimationState(self.armName, "active")
    else
      vehicle.setDamageSourceEnabled(self.armName .. "Drill", false)
      vehicle.setMovingCollisionEnabled(self.armName .. "Drill", false)
      self.tileDamageTimer = self.tileDamageRate
      animator.setAnimationState(self.armName, self.isFiring and "windup" or "winddown")
    end

    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)
    self.bobLocked = true
  else
    vehicle.setDamageSourceEnabled(self.armName .. "Drill", false)
    vehicle.setMovingCollisionEnabled(self.armName .. "Drill", false)
    animator.setAnimationState(self.armName, "idle")
    self.bobLocked = true
  end
end

function DrillArm:damageTiles()
  local tipPosition = self:transformOffset(self.drillTipOffset)
  for _, sourceOffset in ipairs(self.drillSourceOffsets) do
    local sourcePosition = self:transformOffset(sourceOffset)
    local drillTiles = world.collisionBlocksAlongLine(sourcePosition, tipPosition, nil, self.damageTileDepth)
    if #drillTiles > 0 then
      local driver = vehicle.entityLoungingIn("seat")
      world.damageTiles(drillTiles, "foreground", sourcePosition, "blockish", self.tileDamage, 99, driver)
      world.damageTiles(drillTiles, "background", sourcePosition, "blockish", self.tileDamage, 99, driver)
    end
  end
end
