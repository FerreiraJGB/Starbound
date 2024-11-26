function init()
  effect.setParentDirectives("fade=f915cf=0.4")

  doStun()
end

function update(dt)
  doStun()
  mcontroller.controlModifiers({
      facingSuppressed = true,
      movementSuppressed = true
    })
end

function doStun()
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration() or 0.1))
  end
  mcontroller.setVelocity({0, 0})
end
