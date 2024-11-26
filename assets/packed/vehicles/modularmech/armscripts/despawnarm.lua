require "/vehicles/modularmech/armscripts/base.lua"

DespawnArm = MechArm:extend()

function DespawnArm:update(dt, firing, edgeTrigger, aimPosition, facingDirection)
  if firing and edgeTrigger then
    vehicle.destroy()
  end
end
