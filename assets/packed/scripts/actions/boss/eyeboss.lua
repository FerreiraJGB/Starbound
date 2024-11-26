require "/scripts/vec2.lua"
require "/scripts/interp.lua"

function tentacleMovement(args, board, _, dt)
  local offsets = util.rep(function() return math.random() * 6 end, 6)
  local speeds = util.rep(function() return util.randomInRange(args.speedRange) end, 6)
  local directions = util.rep(function() return util.randomDirection() end, 6)

  while true do
    for i = 1, args.tentacleCount do
      offsets[i] = offsets[i] + (speeds[i] * dt) * directions[i]

      if offsets[i] > args.movement or offsets[i] < 0 then
        directions[i] = -directions[i]
        speeds[i] = util.randomInRange(args.speedRange)

        if offsets[i] < 0 then
          offsets[i] = 0
        else
          offsets[i] = args.movement
        end
      end

      animator.resetTransformationGroup("tentacle"..i)
      animator.translateTransformationGroup("tentacle"..i, {0, -offsets[i]})
    end

    dt = coroutine.yield()
  end
end

function heartBeat(args, board, _, dt)
  local moveTime = args.moveTime + args.moveDelays.right
  local movement = {
    left = {0.375, -0.375},
    middle = {0.0, -0.375},
    right = {-0.375, -0.375}
  }

  animator.playSound("heartin")
  local timer = 0
  while timer <= (moveTime + args.moveDelays.right) do
    timer = timer + dt

    for tentacle,offset in pairs(movement) do
      animator.resetTransformationGroup("heart"..tentacle)

      local delay = args.moveDelays[tentacle]
      if timer > delay then
        local ratio = math.min(1.0, (timer - delay) / moveTime)
        local multiply = interp.ranges(ratio, {
          {0.5, interp.linear, 0, 1},
          {1.0, interp.linear, 1, 0}
        })

        animator.translateTransformationGroup("heart"..tentacle, vec2.mul(offset, multiply))
      end
    end

    coroutine.yield()
  end
  animator.playSound("heartout")

  return true
end

function spawnMonsterGroup(args, board, _, dt)
  local spawnGroup = util.randomFromList(config.getParameter("monsterSpawnGroups"))

  animator.setGlobalTag("biome", spawnGroup.biome)

  local timer = args.windup
  while timer > 0 do
    timer = timer - dt
    dt = coroutine.yield()
  end

  for _,monsterType in pairs(spawnGroup.monsters) do
    local offset = rect.randomPoint(args.offsetRegion)
    local position = vec2.add(offset, mcontroller.position())

    local aimVector = {math.random(-54, 54), -20}

    world.spawnProjectile("spacemonsterspawner", position, entity.id(), vec2.norm(aimVector), false, {
      monsterType = monsterType,
      monsterLevel = monster.level()
    })
  end

  return true
end

function eyeWiggle(args, board, _, dt)
  while true do
    local timer = 0
    while timer < args.time do
      timer = timer + dt
      local ratio = (args.time - timer) / args.time
      local rotation = interp.ranges(ratio, {
        {0.25, interp.linear, 0, args.rotation},
        {0.75, interp.linear, args.rotation, -args.rotation},
        {1.0, interp.linear, -args.rotation, 0}
      })
      animator.resetTransformationGroup("eye")
      animator.rotateTransformationGroup("eye", rotation, animator.partPoint("eye", "rotationCenter"))

      dt = coroutine.yield()
    end
  end
end

function spawnLightShaft(args, board)
  local rotation = math.random() * math.pi*2
  animator.resetTransformationGroup("shaftemitter")
  animator.rotateTransformationGroup("shaftemitter", rotation)
  animator.translateTransformationGroup("shaftemitter", config.getParameter("eyeCenterOffset"))
  animator.burstParticleEmitter("shaftemitter")
  return true
end
