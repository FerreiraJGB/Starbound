function init()
  activeItem.setArmAngle(config.getParameter("armAngle"))
  activeItem.setOutsideOfHand(true)

  self.beamInTime = config.getParameter("beamInTime")
  self.beamInTimer = self.beamInTime
end

function update(dt)
  if self.beamInTimer then
    self.beamInTimer = math.max(0, self.beamInTimer - dt)
    if self.beamInTimer > 0 then
      local ratio = self.beamInTimer / self.beamInTime
      if ratio > 0.5 then
        local phaseRatio = 1 - 2 * (ratio - 0.5)
        local directiveString = string.format("?fade=FFFFFF;1.0?multiply=FFFFFF%2x", math.floor(255 * phaseRatio))
        animator.setGlobalTag("directives", directiveString)
      else
        local phaseRatio = 2 * ratio
        local directiveString = string.format("?fade=FFFFFF=%.2f", phaseRatio)
        animator.setGlobalTag("directives", directiveString)
      end
    else
      self.beamInTimer = nil
      animator.setGlobalTag("directives", "")
      animator.setAnimationState("cuffState", "active")
    end
  end
end

function uninit()

end
