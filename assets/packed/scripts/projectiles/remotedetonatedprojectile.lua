function init()
  self.triggered = false
  self.delayRange = config.getParameter("triggerDelayRange")
  projectile.setTimeToLive(projectile.timeToLive() + triggerDelay())

  message.setHandler("triggerRemoteDetonation", trigger)
end

function trigger()
  if not self.triggered then
    self.triggered = true
    projectile.setTimeToLive(triggerDelay())
  end
end

function triggerDelay()
  return self.delayRange[1] + math.random() * (self.delayRange[2] - self.delayRange[1])
end
