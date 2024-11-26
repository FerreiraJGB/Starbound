require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/async.lua"

function init()
  local movementParameters = mcontroller.baseParameters()
  self.flySpeed = movementParameters.flySpeed
  self.airForce = movementParameters.airForce
  
  monster.setDeathParticleBurst("death")
  monster.setDeathSound("death")

  message.setHandler("break", function(_, _)
    status.setResource("health", 0)
  end)
  message.setHandler("despawn", function(_, _)
      self.spawnEnergyPickup = false
      self.behavior = despawn()
    end)

  self.spawnEnergyPickup = config.getParameter("spawnEnergyPickup")

  self.behavior = ophanimBehavior()
end

function update(dt)
  mcontroller.controlFace(1)

  tick(self.behavior)
end

function shouldDie()
  return status.resource("health") <= 0
end

function die()
  if self.spawnEnergyPickup then
    world.spawnProjectile("mechenergypickup", mcontroller.position())
  end
end

function damage(damageSource)
end

-- flyTo smoothly flies to a position
flyTo = async(function(pos)
  local maxAcc = self.airForce / mcontroller.mass()
  local initialDir = vec2.norm(world.distance(pos, mcontroller.position()))
  while true do
    local toTarget = world.distance(pos, mcontroller.position())
    local distance = world.magnitude(toTarget)
    if vec2.dot(toTarget, initialDir) < 0.0 or distance < 0.1 then
      -- passed the target, or is very close
      break 
    end

    local step = vec2.mag(mcontroller.velocity()) * script.updateDt()
    local targetSpeed = math.min(math.sqrt(2 * maxAcc * (distance - step)), self.flySpeed)    
    mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(toTarget), targetSpeed), self.airForce)
    coroutine.yield()
  end
  mcontroller.setVelocity({0, 0})

  return true
end)

messageBoss = async(function(message, ...)
  local boss = util.filter(world.entityQuery(mcontroller.position(), 80, {includedTypes={"monster"}, withoutEntityId=entity.id(), order = "nearest"}), function(e)
      return world.monsterType(e) == "swansong" 
    end)
  if #boss == 0 then return false end
  boss = boss[1]

  local promise = world.sendEntityMessage(boss, message, ...)
  while not promise:finished() do
    coroutine.yield()
  end
  return promise:succeeded(), promise:result()
end)

ophanimBehavior = async(function()
  await(delay(1.0))

  while true do
    -- alternate between ground state and float state
    await(groundState())
    await(floatState())
  end
end)

-- hover above ground while there is gravity
groundState = async(function()
  local hoverHeight = 2.0 + math.random() * 2.0
  while world.gravity(mcontroller.position()) ~= 0 do
    local endLine = vec2.add(mcontroller.position(), {0.0, -hoverHeight * 2})
    local floorPoint = world.lineTileCollisionPoint(mcontroller.position(), endLine)
    floorPoint = (floorPoint and floorPoint[1]) or endLine
    local floorDistance = mcontroller.position()[2] - floorPoint[2]
    mcontroller.controlApproachVelocity({0,  (hoverHeight - floorDistance) * self.flySpeed}, self.airForce)
    coroutine.yield()
  end
end)

-- fly to a designated position and float there until gravity is turned back on
floatState = async(function()
  -- get a designated position from the boss
  local succeeded, goalPosition = await(messageBoss("ophanimPosition", entity.id()))
  if not succeeded then
    await(despawn())
  end

  -- fly to it
  await(flyTo(goalPosition))

  -- while the gravity is turned off, do damage beams
  local beams = connectBeams()
  while world.gravity(mcontroller.position()) == 0 do
    coroutine.yield(tick(beams))
  end

  -- when gravity turns off, clear damage beams and exit the state
  monster.setAnimationParameter("beamTargets", {})
  monster.setDamageSources({})
end)

-- connects beams up to other nearby ophanims, dictated by the boss
-- keeps tracks of the other targets and removes beams when targets are killed
connectBeams = async(function()
  local succeeded, beamTargets = await(messageBoss("beamTargets", entity.id()))
  if not succeeded then
    await(despawn())
  end

  local beams = {}
  while true do
    -- set damage beams to pending beam targets that have stopped moving
    beamTargets = util.filter(beamTargets, function(targetId)
        if not world.entityExists(targetId) then
          return false
        end

        if vec2.mag(world.entityVelocity(targetId)) < 0.001 then
          beams[targetId] = {
            line = {{0.0, 0.0}, world.distance(world.entityPosition(targetId), mcontroller.position())},
            damage = 5 * root.evalFunction("spaceMonsterLevelPowerMultiplier", monster.level()),
            damageSourceKind = "fireplasma",
            team = entity.damageTeam(),
            damageRepeatTimeout = 0.2
          }
          monster.setAnimationParameter("beamTargets", util.keys(beams))
          monster.setDamageSources(util.values(beams))
          return false
        else
          return true
        end
      end)
    
    -- clear damage beams for targets that have been killed
    for entityId, _ in pairs(beams) do
      if not world.entityExists(entityId) then
        beams[entityId] = nil
        monster.setDamageSources(util.values(beams))
      end
    end
    coroutine.yield()
  end
end)

despawn = async(function()
  monster.setAnimationParameter("beamTargets", {})
  monster.setDamageSources({})

  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  self.deathBehavior = nil
  self.shouldDie = true
  status.addEphemeralEffect("monsterdespawn")

  while true do
    coroutine.yield()
  end
end)
