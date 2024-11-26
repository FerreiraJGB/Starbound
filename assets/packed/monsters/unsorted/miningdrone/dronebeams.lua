require "/scripts/vec2.lua"

function init()
  self.tick = 0
end

function update()
  localAnimator.clearDrawables()
  local tiles = animationConfig.animationParameter("tiles") or {}
  local start = vec2.add(entity.position(), animationConfig.partPoint("body", "beamSource"))
  
  for i, tile in ipairs(tiles) do
    self.tick = (self.tick + 1) % 10

    local tileCenter = vec2.add(tile, {0.5, 0.5})
    local toTile = world.distance(vec2.add(tile, {0.5, 0.5}), start)
    local start = vec2.add(start, vec2.mul(vec2.norm(toTile), 0.25))
    local toTile = world.distance(vec2.add(tile, {0.5, 0.5}), start)
    local distance = world.magnitude(toTile)
    local center = vec2.div(vec2.add(start, tileCenter), 2)
    local a = vec2.angle(toTile)

    localAnimator.addDrawable({
      image = "/monsters/unsorted/miningdrone/beamend.png",
      position = tileCenter,
      fullbright = true
    }, "ForegroundTile+10")
    localAnimator.addDrawable({
      image = "/monsters/unsorted/miningdrone/beam.png",
      transformation = {
        {math.cos(a) * distance * 8, -math.sin(a), 0},
        {math.sin(a) * distance * 8, math.cos(a), 0},
        {0, 0, 1}
      },
      position = center,
      fullbright = true
    }, "ForegroundTile+10")

    if self.tick == 0 then
      localAnimator.spawnParticle("dust2", tileCenter)
    end
  end

  -- if #tiles > 0 then
  --   localAnimator.addDrawable({
  --     image = "/monsters/unsorted/miningdrone/beamorig.png",
  --     position = start,
  --     fullbright = true
  --   }, "ForegroundTile+10")
  -- end
end
