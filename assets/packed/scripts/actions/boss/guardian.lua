require "/scripts/rect.lua"

local BeamWindup = 0.5
local BeamWinddown = 0.5
local BeamFrames = 4

function spawnMinionGroup(args, board)
  local group = {}
  local spawnMin = args.spawnMin or mcontroller.position()
  local spawnMax = args.spawnMin or mcontroller.position()

  for _,minion in pairs(args.minions) do
    minion.parameters.level = monster.level()
    minion.parameters.bossId = entity.id()

    local position
    local tries = 1
    if minion.position then
      position = minion.position
    elseif minion.positions then
      repeat
        position = util.randomFromList(minion.positions)
        tries = tries + 1
      until #world.entityQuery(position, 10, {boundMode = "Position", includedTypes = {"monster"}}) == 0 or tries == 10
    else
      local spawnArea = rect.fromVec2(args.spawnMin, args.spawnMax)
      spawnArea = rect.pad(spawnArea, -4) -- spawn some distance away from walls
      repeat
        position = rect.randomPoint(spawnArea)
        tries = tries + 1
      until #world.entityQuery(position, 10, {boundMode = "Position", includedTypes = {"monster"}}) == 0 or tries == 10
    end

    local angle = vec2.angle(world.distance(position, entity.position()))
    local chain = copy(self.spawnBeam)
    chain.sourcePart = "righthand"
    chain.endPosition = position

    util.run(0.25, function() pointHand("righthand", angle) end, {minions = group})

    animator.playSound("spawnMinion")

    local entityId = world.spawnMonster(minion.monsterType, position, minion.parameters)
    table.insert(group, entityId)

    util.run(0.50, function()
      table.insert(self.chains, chain)
      pointHand("righthand", vec2.angle(world.distance(position, entity.position())))
    end, {minions = group})
    util.run(0.25, function() pointHand("righthand", angle) end, {minions = group})
  end
  for _,entityId in pairs(group) do
    world.sendEntityMessage(entityId, "setGroup", group)
  end

  return true, {minions = group}
end

-- param handPart
-- param angle
function rotateGuardianHand(args, board)
  pointHand(args.handPart, args.angle)
  if args.offset then
    animator.translateTransformationGroup(args.handPart, args.offset)
  end
  return true
end

-- param handPart
-- param damagePart
-- param beamType
-- param angle
-- param maxLength
-- param windup
-- param winddown
-- param duration
-- param power
function guardianBeam(args, board, _, dt)
  local timer = 0
  local totalDuration = BeamWindup + args.duration + BeamWinddown
  repeat
    timer = math.min(timer + dt, totalDuration)
    local frame = 4
    if timer < BeamWindup then
      frame = math.ceil((timer / BeamWindup) * BeamFrames)
    elseif timer > BeamWindup + args.duration then
      frame = math.floor(((totalDuration - timer) / BeamWinddown) * BeamFrames) + 1
    end

    handBeam(args.handPart, args.angle, frame, args.beamType, args.bounces, args.maxLength)

    if args.offset then
      animator.translateTransformationGroup(args.handPart, args.offset)
    end

    if timer > BeamWindup and timer < BeamWindup + args.duration then
      table.insert(self.damageParts, args.damagePart)
    end

    coroutine.yield()
  until timer == totalDuration

  return true
end

-- param handPart
-- param maxLength
-- param targetPosition
-- param angularSpeed
-- param duration
-- param power
-- output angle
function guardianBeamArc(args, output, _, dt)
  local start = world.lineCollision(entity.position(), args.targetPosition) or args.targetPosition

  local timer = 0
  local angle = vec2.angle(world.distance(start, entity.position()))
  repeat
    timer = math.min(timer + dt, BeamWindup)
    local frame = math.ceil((timer / BeamWindup) * BeamFrames)
    handBeam(args.handPart, angle, frame, args.beamType, args.bounces)
    coroutine.yield()
  until timer == BeamWindup

  timer = 0
  repeat
    timer = math.min(timer + dt, args.duration)

    local newAngle = vec2.angle(world.distance(args.targetPosition, entity.position()))
    angle = angle + (util.toDirection(util.angleDiff(angle, newAngle)) * args.angularSpeed * dt)

    handBeam(args.handPart, angle, frame, args.beamType, args.bounces)
    table.insert(self.damageParts, args.damagePart)

    coroutine.yield()
  until timer == args.duration

  timer = 0
  repeat
    timer = math.min(timer + dt, BeamWinddown)
    local frame = math.floor(((BeamWinddown - timer) / BeamWinddown) * BeamFrames) + 1
    handBeam(args.handPart, angle, frame, args.beamType, args.bounces)
    coroutine.yield()
  until timer == BeamWinddown

  return true, {angle = angle}
end

-- param angle
function guardianStab(args, board, _, dt)
  local timer = 0
  local angle = 0
  repeat
    timer = math.min(timer + dt, args.windup)

    angle = vec2.angle({math.abs(math.cos(args.angle)), math.sin(args.angle)})
    animator.resetTransformationGroup("lefthand")
    animator.rotateTransformationGroup("lefthand", angle, animator.partProperty("lefthand", "offset"))
    animator.translateTransformationGroup("lefthand", vec2.add(args.offset, vec2.withAngle(angle + math.pi, math.sin((timer / args.windup) * math.pi / 2) * args.windupLength)))
    if args.windup - timer < 0.1 then
      table.insert(self.damageParts, "weapon")
    end
    coroutine.yield()
  until timer >= args.windup

  -- hold stab pose
  timer = 0
  local stabTime = 0.1
  while true do
    timer = math.min(timer + dt, stabTime)
    table.insert(self.damageParts, "weapon")
    animator.resetTransformationGroup("lefthand")
    animator.rotateTransformationGroup("lefthand", angle, animator.partProperty("lefthand", "offset"))
    local start = vec2.withAngle(angle + math.pi, args.windupLength)
    local stabDistance = vec2.sub(vec2.withAngle(angle, args.stabLength), start)
    animator.translateTransformationGroup("lefthand", vec2.add(args.offset, vec2.add(start, vec2.mul(stabDistance, timer / stabTime))))
    coroutine.yield()
  end
end

function guardianHandProjectile(args, board)
  local sourcePosition = vec2.add(entity.position(), animator.partPoint(args.handPart, "projectileSource"))

  local projectileConfig = root.projectileConfig(args.projectileType)
  local minMagnitude = args.fuzzAimPosition + vec2.mag(animator.partPoint(args.handPart, "projectileSource"))
  for i = 1, args.projectileCount do
    local params = copy(args.projectileParameters)
    local magnitude = math.max(world.magnitude(args.aimPosition, entity.position()), minMagnitude)
    local fuzzedPosition = vec2.add(entity.position(), vec2.withAngle(vec2.angle(world.distance(args.aimPosition, entity.position())), magnitude))
    fuzzedPosition = vec2.add(fuzzedPosition, vec2.withAngle(math.random() * math.pi * 2, math.sqrt(math.random()) * args.fuzzAimPosition))

    local aimAngle
    if args.fuzzAimPosition == 0 then
      aimAngle = vec2.angle(world.distance(fuzzedPosition, entity.position()))
    else
      aimAngle = vec2.angle(world.distance(fuzzedPosition, sourcePosition))
    end
    local aimVector = vec2.withAngle(aimAngle + util.randomInRange({-args.fuzzAngle / 2, args.fuzzAngle / 2}))

    local projectileSpeed = params.speed or projectileConfig.speed or 50
    params.power = params.power or projectileConfig.power or 10
    params.power = params.power * status.stat("powerMultiplier") * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
    if args.fuzzSpeed then
      projectileSpeed = projectileSpeed + util.randomInRange({-args.fuzzSpeed / 2, args.fuzzSpeed / 2})
    end
    if args.fixedDistance then
      -- adjust speed and ttl to make all projectiles die at the same time at their fuzzed aim position
      params.timeToLive = world.magnitude(args.aimPosition, sourcePosition) / projectileSpeed
      projectileSpeed = world.magnitude(fuzzedPosition, sourcePosition) / params.timeToLive
    end
    params.speed = projectileSpeed
    world.spawnProjectile(args.projectileType, sourcePosition, entity.id(), aimVector, false, params)
  end

  return true
end

function approachFly(position, innerRange)
  local toTarget = world.distance(position, entity.position())
  local mag = world.magnitude(position, entity.position())

  local bounds = mcontroller.boundBox()
  -- check for walls in the direction of the player when approaching, or away when moving away
  local checkDirection = mag < innerRange and vec2.mul(toTarget, -1) or toTarget
  local horizontalCollision = world.lineTileCollision(entity.position(), vec2.add(entity.position(), {checkDirection[1] > 0 and bounds[3] + 3 or bounds[1] - 3, 0}))
  local verticalCollision = world.lineTileCollision(entity.position(), vec2.add(entity.position(), {0, checkDirection[2] > 0 and bounds[4] + 3 or bounds[2] - 3}))
  -- move along the walls if near
  if horizontalCollision then
    toTarget = vec2.mul(toTarget, {0, 1})
  elseif verticalCollision then
    toTarget = vec2.mul(toTarget, {1, 0})
  end

  if mag < innerRange then
    if horizontalCollision and verticalCollision then
      local dodgePosition = vec2.add(entity.position(), vec2.mul(toTarget, {2, 2}))
      repeat
        mcontroller.controlModifiers({speedModifier = 2.0})
        approachFly(dodgePosition, 0)
        coroutine.yield()
        local mag = world.magnitude(dodgePosition, entity.position())
      until mag < 2
      return
    else
      toTarget = vec2.mul(toTarget, -1) -- move away from target
    end
  elseif horizontalCollision and verticalCollision then
    return
  end

  mcontroller.controlFly(toTarget)
end

function guardianApproach(args, board, _, dt)
  local mag = world.magnitude(args.position, entity.position())
  if mag > args.outerRange or mag < args.innerRange then
    local outerRange, innerRange = args.outerRange, args.innerRange
    if mag > outerRange then
      -- Move to well within range
      outerRange = args.innerRange + ((args.outerRange - args.innerRange) / 2)
    elseif mag < innerRange then
      innerRange = args.outerRange - ((args.outerRange - args.innerRange) / 2)
    end
    local goalRange = mag > innerRange and innerRange or innerRange
    repeat
      local smoothingRange = 1.0
      local smoothingAmount = 0.25
      mcontroller.controlModifiers({speedModifier = (1 - smoothingAmount) + math.min(math.abs(goalRange - mag), smoothingRange) / smoothingRange * smoothingAmount})
      approachFly(args.position, innerRange)

      coroutine.yield()

      mag = world.magnitude(args.position, entity.position())
    until mag < outerRange and mag > innerRange
  end

  return true
end
