require "/scripts/stagehandutil.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

function init()
  self.region = translateBroadcastArea()

  message.setHandler("tileBroken", function(_, _, sourceId, pos)
    if rect.contains(self.region, pos) then
      broadcastTileBroken(sourceId, pos)
    end
  end)

  message.setHandler("objectBroken", function(_, _, sourceId, pos)
    if rect.contains(self.region, pos) then
      broadcastObjectBroken(sourceId, pos)
    end
  end)
end

function broadcastTileBroken(sourceId, position)
  broadcast(position, {
    type = "tileBroken",
    sourceId = entity.id(),
    targetPosition = position,
    targetId = sourceId,
  })
end

function broadcastObjectBroken(sourceId, position)
  broadcast(position, {
    type = "objectBroken",
    sourceId = entity.id(),
    targetPosition = position,
    targetId = sourceId,
  })
end

function broadcast(position, notification)
  local npcs = world.entityQuery(position, 30, { includedTypes = {"npc"} })
  for _,npcId in pairs(npcs) do
    if world.entityDamageTeam(npcId).team == 1 then
      world.sendEntityMessage(npcId, "notify", notification)
    end
  end
end