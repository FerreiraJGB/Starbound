require "/scripts/vec2.lua"

function init()
  -- scale damage and calculate energy cost
  self.pType = config.getParameter("projectileType")
  self.pParams = config.getParameter("projectileParameters", {})
  if not self.pParams.power then
    local projectileConfig = root.projectileConfig(self.pType)
    self.pParams.power = projectileConfig.power
  end
  self.pParams.power = self.pParams.power * root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1))
  self.energyPerShot = 3 * self.pParams.power

  self.fireOffset = config.getParameter("fireOffset")
  updateAim()

  storage.fireTimer = storage.fireTimer or 0
  self.recoilTimer = 0

  animator.setAnimationRate(1 / config.getParameter("fireTime", 1.0))
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  storage.fireTimer = math.max(storage.fireTimer - dt, 0)
  self.recoilTimer = math.max(self.recoilTimer - dt, 0)

  if fireMode ~= "none"
      and storage.fireTimer <= 0
      and not world.pointTileCollision(firePosition())
      and status.overConsumeResource("energy", self.energyPerShot) then

    storage.fireTimer = config.getParameter("fireTime", 1.0)
    fire()
  end

  activeItem.setRecoil(self.recoilTimer > 0)
end

function fire()
  self.pParams.powerMultiplier = activeItem.ownerPowerMultiplier()
  world.spawnProjectile(
      self.pType,
      firePosition(),
      activeItem.ownerEntityId(),
      aimVector(),
      false,
      self.pParams
    )
  animator.setAnimationState("reload", "reload", true)
  animator.burstParticleEmitter("fireParticles")
  animator.playSound("fire")
  self.recoilTimer = config.getParameter("recoilTime", 0.12)
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector()
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(config.getParameter("inaccuracy", 0), 0))
  aimVector[1] = aimVector[1] * self.aimDirection
  return aimVector
end
