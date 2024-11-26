require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/vehicles/dropship/dropship.lua"

function init()
  initShip()

  self.moveDir = {0, 0}
  self.startPosition = mcontroller.position()

  self.behavior = coroutine.create(eventBehavior)

  animator.setAnimationState("blinds", "closed")
end
  
function update(dt)
  local s, r = coroutine.resume(self.behavior)
  if not s then error(r) end

  local driver = 0 -- pretend there's a driver
  updateShip(dt, driver, self.moveDir)
end

function eventBehavior()
  local flyDir = config.getParameter("flyDir")
  local flyDistance = config.getParameter("flyDistance")

  local fireHeight = 20
  local targetHeight = 15

  while true do
    self.moveDir = {flyDir, 0}

    local distance = math.abs(world.distance(mcontroller.position(), self.startPosition)[1])
    if distance > flyDistance then
      if not world.isVisibleToPlayer(mcontroller.collisionBoundBox()) then
        vehicle.destroy()
      end

      self.moveDir[2] = 2
    elseif shipHeight() > targetHeight then
      self.moveDir[2] = -2
    end

    if not isFiring() and shipHeight() < fireHeight then
      startFiring()      
    elseif isFiring() and shipHeight() > fireHeight then
      stopFiring()
    end

    coroutine.yield()
  end
end