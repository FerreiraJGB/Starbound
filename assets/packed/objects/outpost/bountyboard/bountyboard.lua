require "/scripts/async.lua"
require "/scripts/bountygeneration.lua"

function init()
  self.interactData = config.getParameter("interactData")
  object.setInteractive(true)

  storage.bountyWorlds = storage.bountyWorlds or {}
  storage.questWorlds = storage.questWorlds or {}
  storage.posterPools = storage.posterPools or {}
  storage.assignment = storage.assignment or nil
  storage.tutorialAssignment = storage.tutorialAssignment or nil
  storage.stationUuid = storage.stationUuid or nil
  storage.nextAssignment = storage.nextAssignment or {}

  message.setHandler("bountyWorlds", function(_, _)
      return storage.bountyWorlds
    end)
  message.setHandler("setBountyWorlds", function(_, _, worlds)
      storage.bountyWorlds = util.map(worlds, function(w) return {w, 0} end)
    end)
  message.setHandler("registerQuest", function(_, _, questId, worlds)
      sb.logInfo("Registered %s with worlds %s", questId, worlds)
      storage.questWorlds[questId] = worlds
      
      -- technically the world hasn't been visited yet, but we still want to
      -- disincentivize picking it again for another quest
      incrementQuestVisits(questId) 
    end)
  message.setHandler("consumeQuest", function(_, _, questId)
      -- each time a world is visited on a quest (the quest is completed by *anyone*) further disincentivize
      -- using that world again
      incrementQuestVisits(questId)

      -- remove the quest from the poster pools
      for poolName, pool in pairs(storage.posterPools) do
        storage.posterPools[poolName] = filterArray(pool, function(poster)
            for _, quest in ipairs(poster.arc.quests) do
              if quest.questId == questId then
                sb.logInfo("Remove poster for quest %s", questId)
                return false
              end
            end
            return true
          end)
      end
    end)

  message.setHandler("posterPool", function(_, _, poolId)
    return storage.posterPools[poolId] or jarray()
  end)
  message.setHandler("addPosters", function(_, _, poolId, posters)
    storage.posterPools[poolId] = storage.posterPools[poolId] or jarray()
    if #storage.posterPools[poolId] == 0 then
      storage.posterPools[poolId] = jarray()
    end
    local pool = storage.posterPools[poolId]
    for _, newPoster in ipairs(posters) do
      if poolId ~= "standard" and #pool > 0 then
        -- only the standard pool has multiple bounties
        break
      end

      local _, existing = util.find(pool, function(p) return compare(p.slot, newPoster.slot) end)
      if not existing then
        table.insert(pool, newPoster)
      end
    end
  end)

  message.setHandler("assignment", function(_, _)
    return storage.assignment
  end)
  message.setHandler("setAssignment", function(_, _, assignment)
    if storage.assignment == nil then
      storage.assignment = assignment
    end
  end)


  message.setHandler("tutorialAssignment", function(_, _)
    return storage.tutorialAssignment
  end)
  message.setHandler("setTutorialAssignment", function(_, _, assignment)
    if storage.tutorialAssignment == nil then
      storage.tutorialAssignment = assignment
    end
  end)

  message.setHandler("stationUuid", function(_, _)
    return storage.stationUuid
  end)
  message.setHandler("setStationUuid", function(_, _, stationUuid)
    if storage.stationUuid == nil then
      storage.stationUuid = stationUuid
    end
  end)

  message.setHandler("nextAssignment", function(_, _, assignmentType)
    return storage.nextAssignment[assignmentType]
  end)
  message.setHandler("setNextAssignment", function(_, _, assignmentType, assignment)
    if storage.nextAssignment[assignmentType] == nil then
      storage.nextAssignment[assignmentType] = assignment
    end
  end)
end

function onInteraction(args)
  self.interactData.universeRank = 1
  local rankFlags = config.getParameter("rankUniverseFlags")
  for i, flagName in ipairs(rankFlags) do
    if i > self.interactData.universeRank and world.universeFlagSet(flagName) then
      self.interactData.universeRank = i
    end
  end

  return {"ScriptPane", self.interactData}
end

function incrementQuestVisits(questId)
  local worlds = storage.questWorlds[questId]
  if worlds then
    for _, w in ipairs(worlds) do
      local bountyWorld = util.find(storage.bountyWorlds, function(bw) return compare(w, bw[1]) end)
      if bountyWorld then
        bountyWorld[2] = bountyWorld[2] + 1
      end
    end
  end
end

function filterArray(t, predicate)
  local newTable = jarray()
  for _,value in ipairs(t) do
    if predicate(value) then
      newTable[#newTable+1] = value
    end
  end
  return newTable
end