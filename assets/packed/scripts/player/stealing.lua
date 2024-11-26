require "/scripts/util.lua"
require "/scripts/rect.lua"

local BiomeMicrodungeonId = 65533
local FirstMetaDungeonId = 65520

function init()
  message.setHandler("tileBroken", function(_, _, position, layer, materialId, dungeonId, harvested)
      if dungeonId == BiomeMicrodungeonId or dungeonId < FirstMetaDungeonId then
        messageStagehands(position, "tileBroken")
      end
    end)
  message.setHandler("tileEntityBroken", function(_, _, position, entityType, objectName)
      if entityType == "object" then
        messageStagehands(position, "objectBroken")
      end
    end)
end

function update(dt)
end

function messageStagehands(position, messageType)
  local area = rect.withCenter(position, {2, 2})
  local stagehands = world.entityQuery(rect.ll(area), rect.ur(area), {
      includedTypes = { "stagehand" },
      boundMode = "MetaBoundBox"
    })
  stagehands = util.filter(stagehands, function(entityId)
      return world.entityName(entityId) == "objecttracker"
    end)
  for _, entityId in ipairs(stagehands) do
    world.sendEntityMessage(entityId, messageType, player.id(), position)
  end
end