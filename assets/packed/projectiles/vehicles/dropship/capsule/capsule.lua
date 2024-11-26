require "/scripts/vec2.lua"

function destroy()
  local objectType = ({
    "capsulesmall",
    "capsulemed",
    "capsulebig"
  })[math.random(1, 3)]
  local places = world.placeObject(objectType, vec2.floor(entity.position()), 1)
end