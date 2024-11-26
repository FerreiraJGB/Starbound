require "/scripts/vec2.lua"

function init()
  self.triggered = false
  self.delay = config.getParameter("triggerDelay")
  self.projectileType = config.getParameter("projectileType")
  self.projectileOffset = config.getParameter("projectileOffset")

  message.setHandler("triggerRemoteDetonation", trigger)
end

function update(dt)
  if self.hitGround or mcontroller.onGround() then
    mcontroller.setRotation(0)
    self.hitGround = true
  else
    mcontroller.setRotation(math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1]))
  end

  if self.triggered and self.delay > 0 then
    self.delay = self.delay - dt
    if self.delay <= 0 then
      local pPos = vec2.add(mcontroller.position(), self.projectileOffset)
      world.spawnProjectile(
          self.projectileType,
          pPos,
          projectile.sourceEntity(),
          {0, 0},
          false,
          {}
        )
      projectile.die()
    end
  end
end

function trigger()
  self.triggered = true
end
