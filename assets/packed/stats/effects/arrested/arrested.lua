function init()
  effect.addStatModifierGroup({
      {stat = "arrested", amount = 1},
      {stat = "invulnerable", amount = 1},
      {stat = "fireStatusImmunity", amount = 1},
      {stat = "iceStatusImmunity", amount = 1},
      {stat = "electricStatusImmunity", amount = 1},
      {stat = "poisonStatusImmunity", amount = 1},
      {stat = "powerMultiplier", effectiveMultiplier = 0},
      {stat = "specialStatusImmunity", amount = 1}
    })
end

function update(dt)

end

function onExpire()

end
