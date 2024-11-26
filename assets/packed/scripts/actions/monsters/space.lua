function masteroidSplit(args)
  local velocity = mcontroller.velocity()
  local velocityAngle = vec2.angle(velocity)
  local params = {
    level = monster.level(),
    aggressive = world.entityAggressive(entity.id()),
    persistent = entity.persistent()
  }

  -- first splitter
  local spawnVelocity = vec2.add(velocity, vec2.withAngle(velocityAngle + args.angle, args.speed))
  local entityId = world.spawnMonster(args.monsterType, vec2.add(mcontroller.position(), vec2.withAngle(velocityAngle + args.angle, args.offset)), params)
  world.callScriptedEntity(entityId, "mcontroller.setVelocity", spawnVelocity)

  -- second splitter
  spawnVelocity = vec2.add(velocity, vec2.withAngle(velocityAngle - args.angle, args.speed))
  entityId = world.spawnMonster(args.monsterType, vec2.add(mcontroller.position(), vec2.withAngle(velocityAngle - args.angle, args.offset)), params)
  world.callScriptedEntity(entityId, "mcontroller.setVelocity", spawnVelocity)
end

function approachLeadOrbit(args, _, _, dt)
  local tangentialSpeed = 0
  while true do
    local targetPosition = world.entityPosition(args.target)
    local targetVelocity = world.entityVelocity(args.target)

    -- approach velocity to the orbit distance
    local toTarget = world.distance(targetPosition, mcontroller.position())
    local approachPoint = vec2.add(targetPosition, vec2.mul(vec2.norm(toTarget), -args.distance))
    local toApproach = vec2.norm(world.distance(approachPoint, mcontroller.position()))
    local approach = vec2.add(vec2.mul(toApproach, math.min(vec2.mag(toApproach) ^ 3, mcontroller.baseParameters().flySpeed)), targetVelocity)

    -- find the direction to move in orbit
    local toOrbit
    local targetDistance = vec2.mag(toTarget)
    local orbitPoint = vec2.withAngle(vec2.angle(toTarget) + math.pi, targetDistance)
    local targetAngle = vec2.angle(toTarget)
    local leadDir = util.toDirection(util.angleDiff(targetAngle, vec2.angle(targetVelocity)))
    if targetDistance > args.distance then
      -- outside the orbit distance the direction to the orbit is the vector to the outside of the orbit range
      local toEdge = math.sqrt((targetDistance ^ 2) - (args.distance ^ 2))
      local toEdgeAngle = math.atan(args.distance, toEdge)
      orbitPoint = vec2.add(mcontroller.position(), vec2.withAngle(leadDir * toEdgeAngle, toEdge))
      toOrbit = vec2.withAngle(toEdgeAngle)
    else
    -- within the orbit range the direction to the orbit is directly perpendicular to the target
      toOrbit = {0, 1}
    end

    -- tangential approach is the velocity to add to the orbit approach velocity
    -- tangentialSpeed has inertia so it will oscillate smoothly
    -- only apply the directional part of tangentialSpeed to the y component of the tangential vector
    -- so when outside orbit range we always apply a velocity *to* the target

    tangentialSpeed = math.min(args.tangentialSpeed, math.max(-args.tangentialSpeed, tangentialSpeed + leadDir * ((args.tangentialForce / mcontroller.baseParameters().mass) * dt)))

    local tangentialApproach = vec2.mul(vec2.rotate({toOrbit[1], toOrbit[2] * util.toDirection(tangentialSpeed)}, targetAngle), math.abs(tangentialSpeed))

    approach = vec2.add(approach, tangentialApproach)
    if world.rectTileCollision(rect.translate(mcontroller.boundBox(), vec2.add(mcontroller.position(), vec2.norm(approach)))) then
      if world.lineTileCollision(mcontroller.position(), targetPosition) then
        local searchParameters = {
          returnBest = false,
          mustEndOnGround = false,
          maxFScore = 400,
          maxNodesToSearch = 70000,
          boundBox = mcontroller.boundBox()
        }
        while world.lineTileCollision(mcontroller.position(), targetPosition) do
          mcontroller.controlPathMove(targetPosition, false, searchParameters)
          mcontroller.controlFace(1)
          coroutine.yield(nil, {angle = vec2.angle(mcontroller.velocity())})
          targetPosition = world.entityPosition(args.target)
        end
      else
        approach = vec2.add(targetVelocity, vec2.mul(vec2.norm(toTarget), mcontroller.baseParameters().flySpeed))
      end
    end

    mcontroller.controlApproachVelocity(approach, mcontroller.baseParameters().airForce, true)

    coroutine.yield(nil, {angle = vec2.angle(approach)})
  end
end
