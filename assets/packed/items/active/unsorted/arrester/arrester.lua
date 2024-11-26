require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/activeitem/stances.lua"
require "/scripts/status.lua"

function init()
  self.targetInnerRadius = 1.5
  self.targetOuterRadius = 6
  self.targetRange = 30

  self.increaseRate = 35
  self.decreaseRate = 60

  self.minArrestFactor = 0.5

  self.damageInterruptFactor = 2

  self.beepPitchRange = {1.0, 2.0}
  self.beepTime = 0.15
  self.beepTimer = 0

  self.energyUsage = 60

  self.arrestStatus = nil
  self.arrestProgress = 0

  initStances()
  setStance("idle")

  activeItem.setCursor("/cursors/reticle0.cursor")

  self.damageListener = damageListener("damageTaken", function(notifications)
    if self.arrestStatus == "active" then
      for _,notification in pairs(notifications) do
        self.arrestProgress = math.max(0, self.arrestProgress - notification.damageDealt * self.damageInterruptFactor)
      end
    end
  end)
end

function update(dt, fireMode, shiftHeld)
  updateStance(dt)

  if not self.arrestStatus then
    if fireMode == "primary" and self.lastFireMode ~= "primary" and not status.resourceLocked("energy") then
      if findTarget() then
        startArrest()
      else
        animator.playSound("noTarget")
      end
    end
  elseif self.arrestStatus == "active" then
    if fireMode == "primary" then
      local targetRadius = checkTargetRadius()
      local arrestRatio, arrestRadius = arrestRatioAndRadius()
      if targetRadius and targetRadius <= arrestRadius * 1.41 then
        self.beepTimer = self.beepTimer - dt
        if self.beepTimer <= 0 then
          self.beepTimer = self.beepTime
          animator.setSoundPitch("beep", util.lerp(arrestRatio, self.beepPitchRange[1], self.beepPitchRange[2]))
          animator.playSound("beep")
        end

        increaseArrest(dt)
      else
        failArrest()
      end
    else
      failArrest()
    end
  elseif self.arrestStatus == "success" then

  elseif self.arrestStatus == "failure" then

  end

  self.damageListener:update()

  local arrestRatio, arrestRadius = arrestRatioAndRadius()
  activeItem.setScriptedAnimationParameter("arrestStatus", self.arrestStatus)
  activeItem.setScriptedAnimationParameter("arrestTarget", self.target)
  activeItem.setScriptedAnimationParameter("arrestRatio", arrestRatio)
  activeItem.setScriptedAnimationParameter("arrestRadius", arrestRadius)

  updateAim()

  if (self.aimDirection < 0) == (activeItem.hand() == "primary") then
    animator.setGlobalTag("hand", "front")
    activeItem.setOutsideOfHand(true)
  else
    animator.setGlobalTag("hand", "back")
    activeItem.setOutsideOfHand(false)
  end

  animator.setAnimationState("arrestState", self.arrestStatus == "active" and "active" or "idle")

  self.lastFireMode = fireMode
end

function findTarget()
  local pos = mcontroller.position()
  local cursorPosition = activeItem.ownerAimPosition()
  local candidates = world.entityQuery(cursorPosition, self.targetOuterRadius, {boundMode = "position", includedTypes = {"npc"}, order = "nearest"})
  for _, e in pairs(candidates) do
    if entity.isValidTarget(e) then
      if world.getNpcScriptParameter(e, "arrestable", false) then
        local ePos = world.entityPosition(e)
        if world.magnitude(pos, ePos) <= self.targetRange then
          self.target = e
          return true
        end
      end
    end
  end

  return false
end

function checkTargetRadius()
  if self.target and world.entityExists(self.target) then
    local pos = mcontroller.position()
    local targetPosition = world.entityPosition(self.target)
    if world.magnitude(pos, targetPosition) <= self.targetRange and not world.lineCollision(pos, targetPosition) then
      local cursorPosition = activeItem.ownerAimPosition()
      return world.magnitude(targetPosition, cursorPosition)
    end
  end

  return false
end

function arrestRatioAndRadius()
  if self.arrestProgress > 0 then
    local arrestRatio = self.arrestProgress / self.arrestAmount
    local arrestRadius = util.lerp(arrestRatio ^ 2, self.targetOuterRadius, self.targetInnerRadius)
    return arrestRatio, arrestRadius
  else
    return 0, self.targetOuterRadius
  end
end

function startArrest()
  self.arrestStatus = "active"
  self.arrestProgress = 0
  setStance("active")

  local targetHealth = world.entityHealth(self.target)
  self.arrestAmount = math.max(targetHealth[1], targetHealth[2] * self.minArrestFactor)

  world.sendEntityMessage(self.target, "applyStatusEffect", "arresting", nil, entity.id())
  world.sendEntityMessage(self.target, "notify", {type = "arresting", sourceId = activeItem.ownerEntityId()})
end

function increaseArrest(dt)
  self.arrestProgress = math.min(self.arrestAmount, self.arrestProgress + self.increaseRate * dt)

  status.overConsumeResource("energy", self.energyUsage * dt)

  if self.arrestProgress == self.arrestAmount then
    succeedArrest()
  else
    activeItem.setCursor("/cursors/charge2.cursor")
    world.sendEntityMessage(self.target, "applyStatusEffect", "arresting", nil, entity.id())
  end
end

function decreaseArrest(dt)
  self.arrestProgress = math.max(0, self.arrestProgress - self.decreaseRate * dt)

  if self.arrestProgress == 0 then
    reset()
  end
end

function succeedArrest()
  world.sendEntityMessage(self.target, "applyStatusEffect", "arrested", 5.0, entity.id())
  self.arrestStatus = "success"
  setStance("success")
  activeItem.setCursor("/cursors/chargeready.cursor")
  animator.playSound("arrestSuccess")
end

function failArrest()
  self.arrestStatus = "failure"
  setStance("failure")
  activeItem.setCursor("/cursors/reticle0.cursor")
  animator.playSound("arrestFailure")
end

function reset()
  self.target = nil
  self.arrestStatus = nil
  self.arrestProgress = 0
  activeItem.setCursor("/cursors/reticle0.cursor")
  self.beepTimer = 0
  animator.setSoundPitch("beep", self.beepPitchRange[1])
end
