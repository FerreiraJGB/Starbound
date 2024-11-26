require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.successTime = 0.75
  self.failureTime = 0.3

  self.maxRadius = 6
end

function update(dt)
  localAnimator.clearDrawables()

  local arrestStatus = animationConfig.animationParameter("arrestStatus")

  if arrestStatus then
    local arrestTarget = animationConfig.animationParameter("arrestTarget")
    local arrestRatio = animationConfig.animationParameter("arrestRatio")
    local arrestRadius = animationConfig.animationParameter("arrestRadius")

    if arrestTarget and world.entityExists(arrestTarget) then
      local targetPosition = world.entityPosition(arrestTarget)

      if arrestStatus == "active" then
        if arrestRatio > 0 then
          local color = {165, 243, 225, 255 * math.min(1.0, arrestRatio * 10)}

          local aimPos = activeItemAnimation.ownerAimPosition()
          self.innerSquareOffset = vec2.mul(world.distance(aimPos, targetPosition), 0.5)

          drawSquare(targetPosition, arrestRadius, math.pi * arrestRatio, color)
          drawSquare(vec2.add(targetPosition, self.innerSquareOffset), 1.5, -math.pi * arrestRatio, color)
        end
        resetTimers()
      elseif arrestStatus == "success" then
        if not self.successTimer then
          self.successTimer = self.successTime
        end

        self.successTimer = math.max(0, self.successTimer - dt)

        if self.successTimer > 0 then
          local successRatio = self.successTimer / self.successTime
          drawSquare(targetPosition, 1.5, 0, {165 + 90 * successRatio, 243 + 9 * successRatio, 225 + 30 * successRatio, 255 * successRatio})
          localAnimator.addDrawable({
            image = "/items/active/unsorted/arrester/lock.png",
            fullbright = true,
            color = {255, 255, 255, 255 * successRatio},
            position = targetPosition,
            centered = true
          }, "ForegroundOverlay")
        end
      elseif arrestStatus == "failure" then
        if not self.failureTimer then
          self.failureTimer = self.failureTime
        end

        self.failureTimer = math.max(0, self.failureTimer - dt)

        if self.failureTimer > 0 and arrestRatio > 0 then
          local failureRatio = self.failureTimer / self.failureTime
          local color = {217, 58 * failureRatio, 58 * failureRatio, 255 * failureRatio}
          drawSquare(targetPosition, util.lerp(failureRatio, self.maxRadius, arrestRadius), math.pi * arrestRatio, color)
          drawSquare(vec2.add(targetPosition, self.innerSquareOffset or {0, 0}), 1.5, -math.pi * arrestRatio, color)
        end
      end
    else
      resetTimers()
    end
  else
    resetTimers()
  end
end

function drawSquare(position, radius, rotation, color)
  local ri = math.pi / 4
  local points = {
    vec2.withAngle(rotation + ri, radius),
    vec2.withAngle(rotation + ri * 3, radius),
    vec2.withAngle(rotation - ri * 3, radius),
    vec2.withAngle(rotation - ri, radius)
  }

  for i = 0, 3 do
    localAnimator.addDrawable({
        line = {points[i + 1], points[(i + 1) % 4 + 1]},
        width = 1,
        color = color,
        fullbright = true,
        position = position,
      }, "ForegroundOverlay")
  end
end

function resetTimers()
  self.successTimer = nil
  self.failureTimer = nil
end
