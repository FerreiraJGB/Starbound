require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/rect.lua"
require "/scripts/bountygeneration.lua"
require "/interface/cockpit/cockpitutil.lua"

function init()
  self.bountyTypes = root.assetJson("/quests/bounty/assignment.config:bountyTypes")
  self.bountyRanks = root.assetJson("/quests/bounty/assignment.config:bountyRanks")
  self.finalAssignment = root.assetJson("/quests/bounty/assignment.config:finalAssignment")
  self.tutorialAssignment = root.assetJson("/quests/bounty/assignment.config:tutorialAssignment")
  self.newAssignmentDistance = root.assetJson("/quests/bounty/assignment.config:newAssignmentDistance")

  self.posterTypes = config.getParameter("posterTypes")
  self.posterTags = config.getParameter("posterTags")
  self.portraitItems = config.getParameter("portraitItems")
  self.gridSize = config.getParameter("gridSize")
  self.padding = config.getParameter("padding")
  self.loadingCycle = config.getParameter("loadingCycle")
  self.loadingFrames = config.getParameter("loadingFrames")
  self.loadingBaseImage = config.getParameter("loadingBaseImage")
  self.newAssignmentText = config.getParameter("newAssignmentText")
  self.newRankText = config.getParameter("newRankText")

  self.boardSize = widget.getSize("boardLayout")

  self.otherAssignmentText = config.getParameter("otherAssignment")

  loadBoard(false)
end

function loadBoard(forceNewAssignment)
  self.doLoad = coroutine.create(function()
    loadBountyData(forceNewAssignment)
    updateRank()
    updateAssignmentInfo()

    if self.assignment and player.worldId() == self.bountyStation.worldId then
      fillPosters()
      buildLayout()
      updatePosterStatus()
      world.sendEntityMessage(player.id(), "bountyBoardOpened")
    else
      displayOtherAssignment()
    end
    saveBountyData()
    return true
  end)

  widget.setVisible("imgLoadingOverlay", true)
  self.loadTime = config.getParameter("minLoadTime")
end

function update(dt)
  if self.doLoad then
    local status, result = coroutine.resume(self.doLoad)
    if not status then error(result) end
    if result then
      self.doLoad = nil
    end
  end

  if self.loadTime then
    self.loadTime = self.loadTime - dt

    local frame = math.floor(-(self.loadTime / self.loadingCycle) * self.loadingFrames) % self.loadingFrames
    widget.setImage("imgLoadingOverlay", self.loadingBaseImage .. ":" .. frame)

    if self.loadTime <= 0 and not self.doLoad then
      self.loadTime = nil
      widget.setVisible("imgLoadingOverlay", false)
    end
  end

  if self.doLoad or self.loadTime then
    return
  end

  if updatePosterStatus() then
    saveBountyData()
  end
  
  if not widget.active("summaryOverlay") and self.lastAssignment ~= nil and not player.hasActiveQuest("bountyassignment") then
    player.startQuest("bountyassignment")
  end
end

function getPlayerRank()
  local playerRank
  for i, rank in ipairs(self.bountyRanks) do
    if self.playerRankPoints >= rank.threshold then
      playerRank = i
    end
  end
  return playerRank
end

function updateRank()
  local playerRank = getPlayerRank()
  local playerRankInfo = self.bountyRanks[playerRank]

  local assignmentRank = self.assignment and self.assignment.rank or playerRank
  local assignmentRankInfo = self.bountyRanks[assignmentRank]

  widget.setText("lblRank", assignmentRankInfo.description)
  widget.setImage("imgRankIcon", assignmentRankInfo.icon)
  if playerRank < #self.bountyRanks and playerRank == assignmentRank then
    local nextRankInfo = self.bountyRanks[playerRank + 1]
    widget.setProgress("prgRank", (self.playerRankPoints - playerRankInfo.threshold) / (nextRankInfo.threshold - playerRankInfo.threshold))
  else
    if playerRank == #self.bountyRanks then
      self.playerRankPoints = playerRankInfo.threshold
    end
    widget.setProgress("prgRank", 1.0)
  end
end

function displayOtherAssignment()
  widget.setText("lblOtherAssignment", self.otherAssignmentText)
  widget.setVisible("lblOtherAssignment", true)
end

function updateAssignmentInfo()
  if self.assignment then
    local systemName = celestialWrap.planetName(self.assignment.system)

    local template = config.getParameter("assignmentFormat")
    local assignmentString = template:gsub("<gangName>", self.assignment.gang.name):gsub("<systemName>", systemName)
    widget.setText("lblAssignment", assignmentString)
  else
    widget.setText("lblAssignment", config.getParameter("missingAssignment"))
  end
end

function generatePosterQuest(p, worlds)
  if not p.accepted then
    local generator = BountyGenerator.new(
        p.seed,
        systemPosition(self.assignment.system),
        self.bountyRanks[self.assignment.rank].systemTypes,
        p.questConfig.questCategories,
        p.questConfig.endStep)

    generator.stepCount = p.questConfig.stepCount or generator.stepCount
    generator.level = self.assignment.rank + 1
    generator.systemCount = 3
    generator.preBountyQuest = p.questConfig.preBountyQuest
    generator.rewards = scaleRewards(p.questConfig.rewards, self.assignment.rank)
    generator.targetPortrait = posterPortrait(p)

    sb.logInfo("Worlds left: %s", #worlds)
    if p.questConfig.arcType == "minor" then
      if p.target.type == "monster" then
        sb.logInfo("generating minor arc for monster bounty %s", p.target.name)

        local w = table.remove(worlds, 1)
        return generator:generateMinorBounty(p.target, {w})
      else
        sb.logInfo("generating minor arc for NPC bounty %s", p.target.name)

        generator.stepCount = {1, 1}
        return generator:generateBountyArc(p.target, worlds)
      end
    elseif p.questConfig.arcType == "major" then
      sb.logInfo("generating major arc for bounty %s", p.target.name)

      return generator:generateBountyArc(p.target, worlds)
    end
  end
end

function scaleRewards(rewards, rank)
  return {
    money = math.floor(rewards.money * self.bountyRanks[rank].rewardMultipliers.money),
    rank = math.floor(rewards.rank * self.bountyRanks[rank].rewardMultipliers.rank),
    credits = rewards.credits
  }
end

function updatePosterStatus()
  local posterUpdated = false
  for _, p in pairs(self.posters) do
    if not p.accepted then
      p.accepted = posterQuestAccepted(p)
      if p.accepted then
        world.sendEntityMessage(pane.sourceEntity(), "registerQuest", p.arc.quests[1].questId, p.worlds)
        for i, quest in ipairs(p.arc.quests) do
          sb.logInfo("accepted %s", quest.questId)
          -- if #p.arc.quests < 10 or i ~= #p.arc.quests then
          --   world.sendEntityMessage(player.id(), quest.questId..".complete")
          -- end
        end
        posterUpdated = true
      end
    end
    widget.setVisible("boardLayout." .. p.widgetName, not p.accepted)
  end
  return posterUpdated
end

function getNewAssignment(finalAssignment)
  removePosters()

  local rank = getPlayerRank()
  local rankInfo
  local tutorial = false
  if self.assignment == nil and self.playerRankPoints == 0 then
    tutorial = true
    rankInfo = self.tutorialAssignment
  elseif finalAssignment then
    rankInfo = self.finalAssignment
  else 
    rankInfo = self.bountyRanks[rank]
  end

  local jumpsToRefuel = 0
  if self.assignment then
    jumpsToRefuel = self.assignment.jumpsToRefuel or 0
  end

  function newAssignmentAt(system)
    local gang = rankInfo.gang or generateGang()
    local generator = BountyGenerator.new(seed, systemPosition(system), self.bountyRanks[rank].systemTypes)
    local gangLeader = generator:generateBountyNpc(gang, gang.capstoneColor, true)

    return {
      rank = rank,
      system = system,
      gang = gang,
      gangLeader = gangLeader,
      pointsToCapstone = rankInfo.pointsToCapstone,
      poolId = "standard",
      final = finalAssignment,
      tutorial = tutorial,
    }
  end

  local newAssignment
  -- board doesn't have an assignment, make a new one
  local lastAssignment, newSystem, newPosition
  if self.assignment and self.assignment.system and not self.assignment.tutorial then
    local assignmentType = finalAssignment and "final" or "standard"
    while newAssignment == nil do
      newAssignment = util.await(world.sendEntityMessage(pane.sourceEntity(), "nextAssignment", assignmentType)):result()
      if newAssignment == nil then
        -- assign to a new system some distance away from current system
        local oldPosition = systemPosition(self.assignment.system)
        local newPosition = vec2.add(oldPosition, vec2.withAngle(math.random() * math.pi * 2, util.randomInRange(self.newAssignmentDistance)))
        newSystem = findAssignmentArea(newPosition, rankInfo.systemTypes)

        local newBoardAssignment = newAssignmentAt(newSystem)
        util.await(world.sendEntityMessage(pane.sourceEntity(), "setNextAssignment", assignmentType, newBoardAssignment))
      end
    end
    lastAssignment = self.assignment.system
    self.bountyStation = {
      system = newAssignment.system,
      worldId = nil
    }
  elseif player.worldId() == self.bountyStation.worldId then
    -- get assignment from the board, if any, or generate a new one in this system
    local assignmentType = tutorial and "tutorialAssignment" or "assignment"
    local boardAssignment = util.await(world.sendEntityMessage(pane.sourceEntity(), assignmentType)):result()
    if boardAssignment and not tutorial then
      newAssignment = boardAssignment
    else
      newAssignment = newAssignmentAt(self.bountyStation.system)
    end
  end

  if newAssignment then
    self.lastAssignment = lastAssignment
    if lastAssignment then
      table.insert(self.assignmentLog, lastAssignment)
    end
    self.assignment = newAssignment
    self.assignment.jumpsToRefuel = jumpsToRefuel
    sb.logInfo("Got new assignment")
  end 

  updateRank()
end

function needFinalAssignment(rank)
  return player.hasCompletedQuest("destroyruin")
    and (not self.assignment or not self.assignment.final)
    and not player.hasCompletedMission("missioncultist1")
    and rank == #self.bountyRanks
end

function loadBountyData(forceNewAssignment)
  local bountyData = player.getProperty("bountyData") or {}
  bountyData = bountyData[player.serverUuid()] or {}
  self.posters = bountyData.posters or jarray()
  self.assignment = bountyData.assignment
  self.lastAssignment = bountyData.lastAssignment
  self.assignmentLog = bountyData.assignmentLog or jarray()

  self.playerRankPoints = player.getProperty("bountyPoints") or 0
  local bountyStation = player.getProperty("bountyStation") or {}
  self.bountyStation = bountyStation[player.serverUuid()] or {}

  -- in some cases we want to immediately switch our assignment to the board we are interacting with
  maybeTakeBoardAssignment()

  local newEventDescriptions = {}
  local newBountyEvents = player.getProperty("newBountyEvents") or {}
  local newMoney, newRankPoints, newCredits = 0, 0, 0

  local needNewAssignment = forceNewAssignment or not self.assignment
  local hasActiveBounties = false
  local assignmentRank = self.assignment and self.assignment.rank or getPlayerRank()
  self.posters = util.filter(self.posters, function(p)
      if p.accepted and not posterQuestActive(p) then
        for _, quest in pairs(p.arc.quests) do
          local questId = quest.questId
          world.sendEntityMessage(pane.sourceEntity(), "consumeQuest", questId)

          if newBountyEvents[questId] then
            local be = newBountyEvents[questId]
            table.insert(newEventDescriptions, {
              name = p.target.name,
              targetType = p.target.type,
              status = be.status,
              money = be.money or 0, 
              rank = be.rank or 0,
              credits = be.credits or 0
            })

            if be.status == "Captured" then
              if p.category == "capstone" then
                needNewAssignment = true
              elseif p.category == "major" then
                needNewAssignment = needFinalAssignment(assignmentRank)
              end

              if p.category == "capstone" or p.category == "major" then
                local systems = {}
                for _, w in ipairs(p.worlds) do
                  local s = coordinateSystem(w)
                  if not contains(systems, s) then
                    table.insert(systems, s)
                  end
                end
                local toRefuel = self.assignment.jumpsToRefuel or 0
                -- subtract one jump per system, plus one jump back to the station
                self.assignment.jumpsToRefuel = toRefuel - (#systems + 1)
              end
            end
            
            if p.questConfig.endStep == "fuel_bounty" then
              if be.status == "Captured" then
                -- if the player completed the bounty they must have visited the fuel depot
                self.assignment.jumpsToRefuel = 20
              else
                -- player might have visited the fuel depot to grab the fuel then abandoned the quest,
                -- so don't immediately offer a new fuel bounty
                self.assignment.jumpsToRefuel = 5
              end
            end

            newRankPoints = newRankPoints + (be.rank or 0)
            newMoney = newMoney + (be.money or 0)
            newCredits = newCredits + (be.credits or 0)
            
            if be.status == "Failed" then
              -- failed bounties will be replaced with new ones off the board,
              -- so there will be active bounties
              return false
            end
            if be.cinematic then
              self.triggerCinematic = be.cinematic
            end
          end
        end
      else
        -- unaccepted bounties on the board and bounties in the quest log both count as active
        hasActiveBounties = true
      end
      return true
    end)

  if #newEventDescriptions > 0 then
    local playerRank = getPlayerRank()
    local gainedNewRank = false
    if newRankPoints > 0 then
      self.playerRankPoints = self.playerRankPoints + newRankPoints
      gainedNewRank = needNewAssignment and playerRank < #self.bountyRanks
      updateRank()

      if self.assignment.pointsToCapstone then
        self.assignment.pointsToCapstone = self.assignment.pointsToCapstone - newRankPoints
      end
    elseif newRankPoints < 0 then
      self.playerRankPoints = math.max(self.playerRankPoints + newRankPoints, self.bountyRanks[playerRank].threshold)
    end

    showSummary(newEventDescriptions, needNewAssignment, gainedNewRank)
  else
    hideSummary()
  end
  
  if not hasActiveBounties then
    if needNewAssignment then
      -- start a new assignment once the capstone is beaten
      getNewAssignment(needFinalAssignment(getPlayerRank()))
    else
      -- no active bounties, grab new posters from the board
      self.posters = {}
    end
  end
  
  if newMoney > 0 then
    player.giveItem({"money", newMoney})
  end
  if newCredits > 0 then
    player.giveItem({"peacecredit", newCredits})
  end
  player.setProperty("newBountyEvents", {})

  for _, p in pairs(self.posters) do
    populateTempFields(p)
  end
end

function maybeTakeBoardAssignment()
  if self.bountyStation and self.bountyStation.worldId == player.worldId() then
    -- this is already the assigned station
    return
  end

  local playerRank = getPlayerRank()
  local assignmentType = self.playerRankPoints == 0 and "tutorialAssignment" or "assignment"
  local boardAssignment = util.await(world.sendEntityMessage(pane.sourceEntity(), assignmentType)):result()
  if boardAssignment == nil then
    self.otherAssignmentText = config.getParameter("noBoardAssignment")
    return
  end

  if self.assignment then
    if contains(self.assignmentLog, boardAssignment.system) then
      self.otherAssignmentText = config.getParameter("assignmentCompleted")
      return
    end

    if self.assignment.rank ~= boardAssignment.rank then
      self.otherAssignmentText = string.format(config.getParameter("assignmentDifferentRank"), boardAssignment.rank, self.assignment.rank)
      return
    end

    if self.assignment.final ~= boardAssignment.final then
      if boardAssignment.final then
        if not needFinalAssignment(playerRank) then
          self.otherAssignmentText = config.getParameter("finalAssignmentNotReady")
          return
        end
        if player.hasCompletedMission("missioncultist1") then
          self.otherAssignmentText = config.getParameter("assignmentCompleted")
          return
        end
      end
    end

    for _, p in ipairs(self.posters) do
      if posterQuestActive(p) then
        self.otherAssignmentText = config.getParameter("otherAssignmentActive")
        return
      end
    end
  elseif boardAssignment.rank > 1 then
    -- if the player has no assignment, this board must be rank 1
    self.otherAssignmentText = config.getParameter("assignmentNotReady")
    return
  end
  
  self.assignment = boardAssignment
  self.posters = {}

  local boardStationUuid = util.await(world.sendEntityMessage(pane.sourceEntity(), "stationUuid")):result()
  self.bountyStation = {
    system = self.assignment.system,
    uuid = boardStationUuid,
    worldId = player.worldId()
  }
end

function saveBountyData()
  if player.worldId() == self.bountyStation.worldId then
    self.lastAssignment = nil
  end

  local bp = {}
  for _, p in pairs(self.posters) do
    table.insert(bp, {
        seed = p.seed,
        level = p.level,
        posterType = p.posterType,
        tags = p.tags,
        slot = p.slot,
        category = p.category,
        questConfig = p.questConfig,
        target = p.target,
        accepted = p.accepted,
        arc = p.arc,
        worlds = p.worlds,
      })
  end
  player.setProperty("bountyPosters", bp)
  
  local newBountyData = {
    lastAssignment = self.lastAssignment,
    assignment = self.assignment,
    assignmentLog = self.assignmentLog,
    posters = self.posters
  }
  local bountyData = player.getProperty("bountyData") or {}
  bountyData[player.serverUuid()] = newBountyData
  player.setProperty("bountyData", bountyData)
  
  player.setProperty("bountyPoints", self.playerRankPoints)
  local bountyStation = player.getProperty("bountyStation") or {}
  bountyStation[player.serverUuid()] = self.bountyStation
  player.setProperty("bountyStation", bountyStation)

  -- save assignment to the bounty board so others can get the same assignment
  if player.worldId() == self.bountyStation.worldId then
    if self.assignment.tutorial then
      world.sendEntityMessage(pane.sourceEntity(), "setTutorialAssignment", self.assignment)
    else
      world.sendEntityMessage(pane.sourceEntity(), "setAssignment", self.assignment)
    end
    world.sendEntityMessage(pane.sourceEntity(), "setStationUuid", self.bountyStation.uuid)
  end
end

function currentCategories()
  local res = {}
  for _, p in pairs(self.posters) do
    res[p.category] = true
  end
  return res
end

function posterQuestAccepted(poster)
  for _, quest in pairs(poster.arc.quests) do
    if player.hasAcceptedQuest(quest.questId) then
      return true
    end
  end

  return false
end

function posterQuestActive(poster)
  for _, quest in pairs(poster.arc.quests) do
    if player.hasActiveQuest(quest.questId) then
      return true
    end
  end

  return false
end

function populateTempFields(poster)
  poster.widgetName = poster.isMajor and "major"..poster.slot[1]..poster.slot[2] or "minor"..poster.slot[1]..poster.slot[2]

  poster.widgetConfig = copy(self.posterTypes[poster.posterType])

  for tag, value in pairs(poster.tags) do
    replacePatternInData(poster.widgetConfig, nil, "<"..tag..">", value)
  end

  replacePatternInData(poster.widgetConfig, nil, "<posterWidgetName>", poster.widgetName)

  replaceInData(poster.widgetConfig, nil, "<portraitDrawables>", posterPortrait(poster))

  local cellCenter = {
    self.boardSize[1] * ((poster.slot[1] - 0.5) / self.gridSize[1]),
    self.boardSize[2] * ((poster.slot[2] - 0.5) / self.gridSize[2])
  }
  poster.widgetConfig.position = vec2.floor(vec2.sub(cellCenter, vec2.mul(poster.widgetConfig.size, 0.5)))

  poster.rect = {
      poster.widgetConfig.position[1] - self.padding[1],
      poster.widgetConfig.position[2] - self.padding[2],
      poster.widgetConfig.position[1] + poster.widgetConfig.size[1] + self.padding[1],
      poster.widgetConfig.position[2] + poster.widgetConfig.size[2] + self.padding[2]
    }
end

function makePoster(bountyConfig, level, slot, category)
  local seed = sb.makeRandomSource():randu64()
  local generator = BountyGenerator.new(seed, systemPosition(self.assignment.system), self.bountyRanks[self.assignment.rank].systemTypes)
  local gang = bountyConfig.questConfig.useGang and self.assignment.gang or nil

  local colorIndex = nil
  if gang ~= nil and category == "major" then
    colorIndex = gang.majorColor
  elseif gang ~= nil and category == "capstone" then
    colorIndex = gang.capstoneColor
  end

  local target
  if bountyConfig.questConfig.target then
    target = bountyConfig.questConfig.target
  else
    if bountyConfig.questConfig.targetType == "npc" then
      if category == "capstone" and self.assignment.gangLeader then
        target = self.assignment.gangLeader
      else
        local withTitle = category == "capstone" or category == "major"
        target = generator:generateBountyNpc(gang, colorIndex, withTitle)
      end
    elseif bountyConfig.questConfig.targetType == "monster" then
      target = generator:generateBountyMonster()
    else
      error("Unknown bounty target type '%s' in poster", bountyConfig.questConfig.targetType)
    end
  end
  target.gang = target.gang or gang

  local tags = {}
  for tagName, tagPool in pairs(bountyConfig.randomTags) do
    tags[tagName] = util.randomChoice(self.posterTags[tagPool])
  end
  tags.targetName = target.name

  local poster = {
    seed = seed,
    level = level,
    posterType = bountyConfig.poster,
    tags = tags,
    slot = slot,
    category = category,
    questConfig = bountyConfig.questConfig,
    target = target,
    arc = nil,
    accepted = false
  }

  return poster
end

function posterPortrait(poster)
  local target, level, seed = poster.target, poster.level, poster.seed

  local colorIndex = nil
  if target.gang ~= nil then
    colorIndex = target.gang.colorIndex
  end

  local portrait
  if target.type == "npc" then
    local portraitParams = copy(target.parameters)
    local portraitItems = copy(self.portraitItems)
    if target.gang then
      portraitItems.head = {
        {name = target.gang.hat, parameters = {colorIndex = colorIndex} }
      }
    end
    portraitParams.items = {
      override = {
        {0, {
          portraitItems
        }}
      }
    }

    portrait = root.npcPortrait("bust", target.species, target.typeName, level, seed, portraitParams)
  elseif target.type == "monster" then
    portrait = root.monsterPortrait(target.monster.monsterType, target.monster.parameters)

    for _, drawable in pairs(portrait) do
      if target.portraitScale then
        if drawable.transformation then
          drawable.transformation[1][1] = drawable.transformation[1][1] * target.portraitScale
          drawable.transformation[2][2] = drawable.transformation[2][2] * target.portraitScale
        else
          drawable.transformation = {
            {target.portraitScale, 0, -8},
            {0, target.portraitScale, -8},
            {0, 0, 1}
          }
        end
      end

      if target.portraitCenter then
        if drawable.position then
          drawable.position = vec2.add(drawable.position, vec2.mul(target.portraitCenter, 8))
        else
          drawable.position = vec2.mul(target.portraitCenter, 8)
        end
      end
    end
  end

  return portrait
end

function bountyWorlds()
  local worlds = util.await(world.sendEntityMessage(pane.sourceEntity(), "bountyWorlds")):result()
  if #worlds == 0 then
    local pos = systemPosition(self.assignment.system)
    local systemTypes = self.bountyRanks[self.assignment.rank].systemTypes
    -- be cautious and allow finding the worlds in a very large area so this doesn't fail
    local newWorlds = findWorlds(pos, systemTypes, 1000000)
    util.await(world.sendEntityMessage(pane.sourceEntity(), "setBountyWorlds", newWorlds))
    worlds = util.await(world.sendEntityMessage(pane.sourceEntity(), "bountyWorlds")):result()
  end
  shuffle(worlds)

  -- sort worlds by how many times they've been used in bounty quests
  table.sort(worlds, function(l, r) return l[2] < r[2] end)
  worlds = util.map(worlds, function(w) return w[1] end)

  return worlds
end

function fillPosters()
  local maxPosters = 6
  
  local poolId = self.assignment.poolId
  local playerRank = getPlayerRank()
  if playerRank > self.assignment.rank or (self.assignment.pointsToCapstone and self.assignment.pointsToCapstone <= 0) then
    poolId = "capstone"
  end
  if self.assignment.tutorial then
    poolId = "tutorial"
  end

  local worlds = bountyWorlds()
  while #self.posters < maxPosters do
    if #self.posters > 0 and (poolId == "capstone" or poolId == "tutorial") then
      break
    end
    local boardPosters = util.await(world.sendEntityMessage(pane.sourceEntity(), "posterPool", poolId)):result()

    -- fill local available posters with posters from the corresponding slots on the board object
    local localAvail = availableSlots(self.posters)
    for _, slot in ipairs(localAvail) do
      for _, p in ipairs(boardPosters) do
        if compare(slot, p.slot) then
          populateTempFields(p)
          table.insert(self.posters, p)
        end
      end
    end

    -- break out if we have the max number of posters, or we have a capstone poster
    local hasLocalCapstone = false
    for _, p in ipairs(self.posters) do
      if p.category == "capstone" then
        hasLocalCapstone = true
      end
    end
    if #self.posters >= maxPosters or (#self.posters > 0 and (hasLocalCapstone or poolId == "tutorial")) then
      break
    end
    
    -- otherwise, generate new bounties to store on the board, and try again
    local avail = availableSlots(boardPosters)
    local majorWorlds = nil
    local minorWorldPool = {}

    local boardHasCapstone = false
    local boardHasSpecial = false
    for _, p in ipairs(boardPosters) do
      if p.category == "major" then
        majorWorlds = p.worlds
      elseif p.category == "capstone" then
        boardHasCapstone = true
      elseif p.category == "minorSpecial" then
        boardHasSpecial = true
      end
    end

    -- major bounty worlds are used for minor bounties,
    -- filter out all the used ones and leave available ones in a minor world pool
    if majorWorlds then
      minorWorldPool = util.filter(majorWorlds, function(c) return c.planet ~= 0 or c.satellite ~= 0 end)
      for _, p in ipairs(boardPosters) do
        if p.category == "minor" then
          for _,l in ipairs(p.worlds) do
            minorWorldPool = util.filter(minorWorldPool, function(r) return not compare(l, r) end)
          end
        end
      end
    end

    local newPosters = jarray()
    for _, slot in ipairs(avail) do
      if boardHasCapstone then
        break
      end

      local targetCategory
      if (poolId == "capstone" or poolId == "tutorial") then
        -- capstone at the end of a tier
        targetCategory = "capstone"
        boardHasCapstone = true
      elseif majorWorlds == nil then
        -- otherwise, first make a major bounty
        targetCategory = "major"
      elseif not boardHasSpecial then
        -- every pool should have 1 special minor bounty
        targetCategory = "minorSpecial"
        boardHasSpecial = true
      else
        -- then generate minor bounties
        if #minorWorldPool > 0 then
          targetCategory = "minorPlanet"
        else
          targetCategory = "minor"
        end
      end

      local rankInfo
      if self.assignment.tutorial then
        rankInfo = self.tutorialAssignment
      elseif self.assignment.final then
        rankInfo = self.finalAssignment
      else
        rankInfo = self.bountyRanks[self.assignment.rank]
      end
      local bountyType = util.randomChoice(rankInfo.bounties[targetCategory])
      local refuel = self.assignment.jumpsToRefuel or 0
      if targetCategory == "minorSpecial" and refuel <= 0 then
        bountyType = "fuel_bounty"
      end
      local bc = self.bountyTypes[bountyType]
      local newPoster = makePoster(bc, 1, slot, targetCategory)
      
      local worlds = worlds
      if majorWorlds then
        if #minorWorldPool == 0 then
          -- put the bounties in the same systems as the major bounty visits, one in each system
          local usedSystems = {}
          local majorSystems = util.map(majorWorlds, coordinateSystem)
          minorWorldPool = util.filter(worlds, function(w)
            if worlds.planet == 0 and world.satellite == 0 then
              return false
            end
            local system = coordinateSystem(w)
            if contains(majorSystems, system) and not contains(usedSystems, system) and not contains(majorWorlds, w) then
              table.insert(usedSystems, system)
              return true
            end
            return false
          end)
        end

        if #minorWorldPool > 0 then
          -- generate one minor bounty on each planet the major bounty uses
          worlds = minorWorldPool
        end
      end
      newPoster.arc, newPoster.worlds = generatePosterQuest(newPoster, worlds)

      if targetCategory == "major" then
        majorWorlds = shallowCopy(newPoster.worlds)
        minorWorldPool = util.filter(majorWorlds, function(c) return c.planet ~= 0 or c.satellite ~= 0 end)
      end
      
      table.insert(newPosters, newPoster)
    end
    util.await(world.sendEntityMessage(pane.sourceEntity(), "addPosters", poolId, newPosters))
  end

  saveBountyData()
end

function availableSlots(posters)
  local availSlots = {}
  for col = 1, self.gridSize[1] do
    for row = 1, self.gridSize[2] do
      local avail = true

      for _, p in pairs(posters) do
        if p.slot[1] == col and p.slot[2] == row then
          avail = false
          break
        end
      end

      if avail then
        table.insert(availSlots, {col, row})
      end
    end
  end
  shuffle(availSlots)
  return availSlots
end

function buildLayout()
  for _, p in pairs(self.posters) do
    widget.addChild("boardLayout", p.widgetConfig, p.widgetName)
  end

  shiftPosters()
end

function posterSetSeed()
  local seedList = {}
  for _, p in pairs(self.posters) do
    table.insert(seedList, p.seed)
  end
  return sb.staticRandomI32(table.unpack(seedList))
end

function shiftPosters()
  local rng = sb.makeRandomSource(posterSetSeed())

  local c = vec2.floor(vec2.mul(self.boardSize, 0.5))
  for i, p1 in ipairs(self.posters) do
    local xShiftRight = rng:randb()
    local xLimit = xShiftRight and util.lerp(rng:randf(), p1.rect[3], self.boardSize[1]) or rng:randf() * p1.rect[1]
    for j, p2 in ipairs(self.posters) do
      if i ~= j and p1.rect[2] <= p2.rect[4] and p1.rect[4] >= p2.rect[2] then
        if xShiftRight and p1.rect[3] <= p2.rect[1] then
          xLimit = math.min(xLimit, p2.rect[1])
        elseif not xShiftRight and p1.rect[1] >= p2.rect[3] then
          xLimit = math.max(xLimit, p2.rect[3])
        end
      end
    end

    local xTranslate = {xLimit - (xShiftRight and p1.rect[3] or p1.rect[1]), 0}
    p1.widgetConfig.position = vec2.add(p1.widgetConfig.position, xTranslate)
    p1.rect = rect.translate(p1.rect, xTranslate)

    local yShiftUp = rng:randb()
    local yLimit = yShiftUp and util.lerp(rng:randf(), p1.rect[4], self.boardSize[2]) or rng:randf() * p1.rect[2]
    for j, p2 in ipairs(self.posters) do
      if i ~= j and p1.rect[1] <= p2.rect[3] and p1.rect[3] >= p2.rect[1] then
        if yShiftUp and p1.rect[4] <= p2.rect[2] then
          yLimit = math.min(yLimit, p2.rect[2])
        elseif not yShiftUp and p1.rect[2] >= p2.rect[4] then
          yLimit = math.max(yLimit, p2.rect[4])
        end
      end
    end

    local yTranslate = {0, yLimit - (yShiftUp and p1.rect[4] or p1.rect[2])}
    p1.widgetConfig.position = vec2.add(p1.widgetConfig.position, yTranslate)
    p1.rect = rect.translate(p1.rect, yTranslate)

    widget.setPosition("boardLayout."..p1.widgetName, p1.widgetConfig.position)
  end
end

function removePosters()
  widget.removeAllChildren("boardLayout")
  self.posters = {}
end

function selectPoster(widgetName, widgetData)
  for _, p in pairs(self.posters) do
    if p.widgetName == widgetData then
      if p.arc then
        player.startQuest(p.arc, player.serverUuid())
      end
      break
    end
  end
end

function showSummary(events, newAssignment, newRank)
  local nameStr, statusStr, moneyStr, rankStr, creditsStr = "", "", "", "", ""
  for _, e in pairs(events) do
    nameStr = string.format("%s%s\n", nameStr, e.name)
    statusStr = string.format("%s%s\n", statusStr, e.status)
    moneyStr = string.format(e.money > 0 and "%s+%d\n" or "%s%d\n", moneyStr, math.floor(e.money))
    rankStr = string.format(e.rank > 0 and "%s+%d\n" or "%s%d\n", rankStr, math.floor(e.rank))
    creditsStr = string.format(e.credits > 0 and "%s+%d\n" or "%s%d\n", creditsStr, math.floor(e.credits))
    
    player.recordEvent("bountyQuest", {targetType = e.targetType})
  end
  widget.setText("summaryOverlay.lblNameList", nameStr)
  widget.setText("summaryOverlay.lblStatusList", statusStr)
  widget.setText("summaryOverlay.lblMoneyList", moneyStr)
  widget.setText("summaryOverlay.lblRankList", rankStr)
  widget.setText("summaryOverlay.lblCreditsList", creditsStr)

  local extraEventStr = ""
  if newAssignment then
    extraEventStr = extraEventStr .. "\n" .. self.newAssignmentText
  end
  if newRank then
    extraEventStr = extraEventStr .. "\n" .. self.newRankText
  end
  widget.setText("summaryOverlay.lblExtraEvents", extraEventStr)
end

function hideSummary()
  widget.setVisible("summaryOverlay", false)
  if self.triggerCinematic then
    player.playCinematic(self.triggerCinematic)
    self.triggerCinematic = nil
  end
end

function debugReset()
  player.setProperty("bountyData", nil)
  player.setProperty("bountyPoints", nil)
  player.setProperty("bountyStation", nil)
  removePosters()
  loadBoard(false)
end
