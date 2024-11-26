function init()
  self.played = false
end

function update(dt)
  if not self.played and not world.breathable(entity.position()) then
    world.sendEntityMessage(entity.id(), "queueRadioMessage", "biomeairless", 5.0)
    self.played = true
  end
end

function uninit()
end
