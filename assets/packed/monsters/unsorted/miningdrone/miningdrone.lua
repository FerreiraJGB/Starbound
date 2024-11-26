require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/async.lua"

function init()
  self.behavior = droneBehavior()

  monster.setDeathSound("deathPuff")
  monster.setDeathParticleBurst("deathPoof")

  script.setUpdateDelta(1)
end

function update()
  tick(self.behavior)
end

droneBehavior = async(function()
  local ownerId = config.getParameter("ownerId")
  local tileDamage = config.getParameter("tileDamagePerSecond", 0.2) * script.updateDt()
  local harvestLevel = config.getParameter("harvestLevel", 99)
  local mineRadius = config.getParameter("mineRadius", 2)
  
  local movementParameters = mcontroller.baseParameters()
  local direction = vec2.norm(config.getParameter("direction", {1, -1}))
  local velocity = vec2.mul(direction, movementParameters.flySpeed)
  mcontroller.setVelocity(velocity)

  mcontroller.controlFace(velocity[1])

  local newTiles = {}
  local tiles = {}
  await(select(
    delay(config.getParameter("flyTime", 5.0)),
    function()
      while true do
        if #newTiles == 0 then
          local pos = vec2.add(mcontroller.position(), vec2.mul(direction, mineRadius))
          newTiles = world.radialTileQuery(pos, mineRadius, "foreground")
          for _,t in ipairs(world.radialTileQuery(mcontroller.position(), mineRadius, "foreground")) do
            if not contains(newTiles, t) then
              table.insert(newTiles, t)
            end
          end
        end
        
        if #newTiles > 0 then
          table.insert(tiles, table.remove(newTiles, #newTiles))
          animator.playSound("zap")
        end
        tiles = util.filter(tiles, function(t) return world.material(t, "foreground") ~= false end)
        mcontroller.controlApproachVelocity(vec2.mul(velocity, 1 - math.min(1.0, math.max(0, #tiles - 4) / 12)), movementParameters.airForce)

        monster.setAnimationParameter("tiles", tiles)
        world.damageTiles(tiles, "foreground", mcontroller.position(), "blockish", tileDamage, harvestLevel, ownerId)
        coroutine.yield()
      end
    end
  ))

  mcontroller.setVelocity({0, 0})
  monster.setAnimationParameter("tiles", {})
  status.setResource("health", 0)

  world.spawnProjectile("zbombexplosion", mcontroller.position(), entity.id(), {1, 0}, false)

  while true do
    coroutine.yield()
  end
end)