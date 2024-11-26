require "/scripts/vec2.lua"

function update()
  if not sourceEntityAlive() then
    projectile.die()
  end

  local velocity = mcontroller.velocity()
  if vec2.mag(velocity) < 0.1 then
    projectile.die()
  end
end

function destroy()
  if not sourceEntityAlive() then
    return
  end

  world.spawnMonster("ophanim", mcontroller.position(), {
    level = world.threatLevel(),
    spawnEnergyPickup = config.getParameter("spawnEnergyPickup")
  })
end

function sourceEntityAlive()
  return world.entityExists(projectile.sourceEntity()) and world.entityHealth(projectile.sourceEntity())[1] > 0
end