function translateBroadcastArea()
  local broadcastArea = config.getParameter("broadcastArea", {-8, -8, 8, 8})
  local pos = entity.position()
  return {
      broadcastArea[1] + pos[1],
      broadcastArea[2] + pos[2],
      broadcastArea[3] + pos[1],
      broadcastArea[4] + pos[2]
    }
end

function broadcastAreaQuery(options)
  local area = translateBroadcastArea()
  return world.entityQuery({area[1], area[2]}, {area[3], area[4]}, options)
end
