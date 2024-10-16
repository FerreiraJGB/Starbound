function init()
  self.state = stateMachine.create({
    "idleState",
    "attackState",
  })

  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
  end

  self.initialPauseTimer = entity.configParameter("initialPauseTime")

  entity.setDeathParticleBurst("deathPoof")
  entity.setAggressive(true)
  entity.setDamageOnTouch(true)
end

--------------------------------------------------------------------------------
function update(dt)
  if self.initialPauseTimer > 0 then
    self.initialPauseTimer = self.initialPauseTimer - dt
  else
    if util.trackTarget(entity.configParameter("targetNoticeDistance")) then
      self.state.pickState(self.targetId)
    end

    self.state.update(dt)
  end
end

--------------------------------------------------------------------------------
function boundingBox(offset)
  local position = mcontroller.position()
  if offset ~= nil then position = vec2.add(position, offset) end

  local bounds = entity.configParameter("metaBoundBox")
  return {
    bounds[1] + position[1],
    bounds[2] + position[2],
    bounds[3] + position[1],
    bounds[4] + position[2],
  }
end

--------------------------------------------------------------------------------
function isClosed()
  return entity.animationState("movement") == "closedIdle"
end

--------------------------------------------------------------------------------
function isOnPlatform()
  local bounds = boundingBox({ 0, -1 })

  return mcontroller.onGround() and
      world.rectTileCollision(bounds, {"Platform"})
end

--------------------------------------------------------------------------------
function move(toTarget)
  entity.setAnimationState("movement", "move")

  if math.abs(toTarget[2]) < 4.0 and isOnPlatform() then
    mcontroller.controlDown()
  end

  mcontroller.controlMove(toTarget[1], true)
end

--------------------------------------------------------------------------------
idleState = {}

function idleState.enter()
  if isClosed() then return nil end

  return { timer = entity.randomizeParameterRange("idleBlinkIntervalRange") }
end

function idleState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    entity.setAnimationState("movement", "blink")
    stateData.timer = entity.randomizeParameterRange("idleBlinkIntervalRange")
  end

  return false
end

--------------------------------------------------------------------------------
attackState = {}

function attackState.enterWith(targetId)
  if targetId == nil then return nil end

  if isClosed() then
    entity.setAnimationState("movement", "open")
  end

  return {
    timer = entity.configParameter("attackTargetHoldTime"),
    targetId = targetId,
    targetPosition = world.entityPosition(targetId),
  }
end

function attackState.update(dt, stateData)
  if entity.animationState("movement") == "open" then
    return false
  end

  local targetPosition = world.entityPosition(stateData.targetId)
  if targetPosition == nil then return true end

  if entity.entityInSight(stateData.targetId) then
    stateData.targetPosition = targetPosition
    stateData.timer = entity.configParameter("attackTargetHoldTime")
  else
    stateData.timer = stateData.timer - dt
  end

  local toTarget = world.distance(stateData.targetPosition, mcontroller.position())
  move(toTarget)

  return stateData.timer <= 0
end
