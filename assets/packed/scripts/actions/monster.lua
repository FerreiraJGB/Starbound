-- param name
function setForceRegionActive(args, board)
  if args.name == nil or args.name == "" then return false end

  self.forceRegions:setActive(args.name)
  return true
end

-- param name
function setDamageSourceActive(args, board)
  if args.name == nil or args.name == "" then return false end

  self.damageSources:setActive(args.name)
  return true
end

-- param name
function setDamagePartActive(args, board)
  table.insert(self.damageParts, args.name)
  return true
end

function setDamageBar(args, board)
  monster.setDamageBar(args.type)
  return true
end

-- param enable
function battleMusic(args, board)
  if self.musicEnabled ~= args.enable then
    local musicStagehands = config.getParameter("musicStagehands")
    if not musicStagehands then
      sb.logInfo("The monster's musicStagehands parameter (a uniqueId) must be configured for startBattleMusic")
      return false
    end
    for _,stagehand in pairs(musicStagehands) do
      local entityId = world.loadUniqueEntity(stagehand)

      if entityId and world.entityExists(entityId) then
        world.callScriptedEntity(entityId, "setMusicEnabled", args.enable)
        self.musicEnabled = args.enable
      end
    end
  end

  return true
end

-- param skillName
function setActiveSkillName(args, board, _, dt)
  monster.setActiveSkillName(args.skillName)
  return true
end

-- param angle
-- param vector
-- param immediate
function rotate(args, board, _, dt)
  local goalAngle = 0
  local angle = mcontroller.rotation()
  repeat
    goalAngle = args.vector and vec2.angle(args.vector) or args.angle
    goalAngle = (goalAngle + config.getParameter("rotationOffset", 0)) % (math.pi*2)
    if args.rate == 0 then break end

    local diff = util.angleDiff(angle, goalAngle)
    local angleStep = args.rate * dt * util.toDirection(diff)
    -- break if the angle went past the goal angle
    if util.angleDiff(angle + angleStep, goalAngle) * diff < 0 then break end

    angle = angle + angleStep
    animator.resetTransformationGroup("body")
    animator.rotateTransformationGroup("body", angle)
    mcontroller.setRotation(angle)

    dt = coroutine.yield()
  until math.abs(util.angleDiff(angle, goalAngle)) < 0.02

  animator.resetTransformationGroup("body")
  animator.rotateTransformationGroup("body", goalAngle)
  mcontroller.setRotation(goalAngle)
  return true
end

-- param angle
-- param transformationGroup
function rotateBody(args, board)
  self.rotationGroup = args.transformationGroup
  while true do
    self.rotation = args.angle
    self.rotated = true

    animator.resetTransformationGroup(args.transformationGroup)
    animator.rotateTransformationGroup(args.transformationGroup, self.rotation)
    coroutine.yield()
  end
end
