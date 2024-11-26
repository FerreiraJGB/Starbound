function init()
  animator.setAnimationState("teleport", "beamOut")
  animator.setFlipped(mcontroller.facingDirection() < 0)
  effect.setParentDirectives("?multiply=ffffff00")
  self.triggerTimer = 1.5
end

function update(dt)
  self.triggerTimer = self.triggerTimer - dt
  if self.triggerTimer <= 0 then
    status.setResource("health", 0)
  end
end
