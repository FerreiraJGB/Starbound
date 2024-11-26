require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/quests/scripts/portraits.lua"
require "/quests/scripts/questutil.lua"
require "/scripts/bountygeneration.lua"
require "/quests/bounty/bounty_portraits.lua"

function init()
  setPortraits()

  message.setHandler("bountyBoardOpened", function(_, _)
      quest.complete()
    end)

  storage.complete = storage.complete or false
  self.compassUpdate = config.getParameter("compassUpdate", 0.5)

  self.boardUid = config.getParameter("boardUid")
  self.arrivalCinematic = config.getParameter("arrivalCinematic")
  
  self.bountyRanks = root.assetJson("/quests/bounty/assignment.config:bountyRanks")
  self.stationTypes = root.assetJson("/quests/bounty/assignment.config:rankStationTypes")

  if quest.serverUuid() ~= player.serverUuid() then
    storage.bountySystem = nil
    quest.setServerUuid(player.serverUuid())
  end
  
  local bountyData = player.getProperty("bountyData") or {}
  bountyData = bountyData[player.serverUuid()] or {}
  local assignment = bountyData.assignment
  self.assignmentRank = 1
  self.finalAssignment = false
  if assignment then
    storage.bountySystem = assignment.system
    self.assignmentRank = assignment.rank
    if assignment.final then
      self.finalAssignment = true
    end
  else
    self.assignmentRank = getPlayerRank()
  end

  if self.finalAssignment then
    quest.setTitle(config.getParameter("finalAssignmentTitle"))
    quest.setText(config.getParameter("finalAssignmentText"))
  else
    quest.setTitle(config.getParameter("rankTitles")[self.assignmentRank])
    quest.setText(util.randomFromList(config.getParameter("rankText")[self.assignmentRank]))
  end
  
  setBountyPortraits()

  storage.playedCinematic = storage.playedCinematic or false

  storage.stage = storage.stage or 1
  self.stages = {
    findSystemStage,
    approachStationStage,
    findBoardStage
  }

  self.state = FSM:new()
  self.state:set(self.stages[storage.stage])
end

function questInteract(entityId)
  if self.onInteract then
    return self.onInteract(entityId)
  end
end

function questStart()
end

function update(dt)
  self.state:update(dt)
end

function questComplete()
  setBountyPortraits()
  questutil.questCompleteActions()
end

function getPlayerRank()
  local points = player.getProperty("bountyPoints") or 0
  local playerRank
  for i, rank in ipairs(self.bountyRanks) do
    if points >= rank.threshold then
      playerRank = i
    end
  end
  return playerRank
end

function findSystemStage()
  local searchText = config.getParameter("descriptions.searching")
  quest.setObjectiveList({
    {string.format(searchText, systemName), false}
  })
  while celestial.currentSystem() == nil do
    coroutine.yield()
  end
  if storage.bountySystem == nil then
    local systemTypes = self.bountyRanks[self.assignmentRank].systemTypes
    storage.bountySystem = findAssignmentArea(systemPosition(celestial.currentSystem()), systemTypes)
  end

  quest.setLocation({system = storage.bountySystem.location, location = nil})
  quest.setWorldId(nil)

  quest.setCompassDirection(nil)
  quest.setIndicators({})

  while celestial.planetName(storage.bountySystem) == nil do
    coroutine.yield()
  end
  local systemName = celestial.planetName(storage.bountySystem)
  local objectiveText = config.getParameter("descriptions.findSystem")
  quest.setObjectiveList({
    {string.format(objectiveText, systemName), false}
  })

  while not compare(celestial.currentSystem(), storage.bountySystem) do
    coroutine.yield()
  end

  storage.stage = 2
  self.state:set(self.stages[storage.stage])
end

function approachStationStage()
  if not compare(celestial.currentSystem(), storage.bountySystem) then
    storage.stage = 1
    return self.state:set(self.stages[storage.stage])
  end

  local objectiveText = config.getParameter("descriptions.approachStation")
  quest.setObjectiveList({
    {objectiveText[1], false},
    {objectiveText[2], false}
  })

  local stationType = self.stationTypes[self.assignmentRank]
  if stationType == nil then
    error(string.format("Peacekeeper station type not defined for assignment rank %s", self.assignmentRank))
  end
  local stationUuid = util.find(celestial.systemObjects(), function(o)
    if celestial.objectType(o) == stationType then
      return true
    else
      return false
    end
  end)
  if not stationUuid then
    stationUuid = celestial.systemSpawnObject(stationType)
    while not contains(celestial.systemObjects(), stationUuid) do
      coroutine.yield()
    end
  end
  local questLocation = {system = storage.bountySystem.location, location = {"object", stationUuid}}
  quest.setLocation(questLocation)
  local stationWorld = celestialWrap.objectWarpActionWorld(stationUuid)
  quest.setWorldId(stationWorld)

  local bountyStation = player.getProperty("bountyStation") or {}
  bountyStation[player.serverUuid()] = {
    system = storage.bountySystem,
    uuid = stationUuid,
    worldId = stationWorld
  }
  player.setProperty("bountyStation", bountyStation)

  while quest.worldId() == nil or player.worldId() ~= quest.worldId() do
    local atLocation = compare(celestial.shipLocation(), questLocation.location)
    quest.setObjectiveList({
      {objectiveText[1], atLocation},
      {objectiveText[2], false}
    })
    coroutine.yield()
  end

  storage.stage = 3
  self.state:set(self.stages[storage.stage])
end

function findBoardStage()
  if quest.worldId() == nil or player.worldId() ~= quest.worldId() then
    storage.stage = 2
    self.state:set(self.stages[storage.stage])
  end

  quest.setParameter("board", {type = "entity", uniqueId = self.boardUid, indicator = "/interface/quests/questreceiver.animation"})
  quest.setIndicators({"board"})

  quest.setObjectiveList({{config.getParameter("descriptions.findBoard"), false}})

  local findBoard = util.uniqueEntityTracker(self.boardUid, self.compassUpdate)
  while true do
    local position = findBoard()
    questutil.pointCompassAt(position)

    if position and not storage.playedCinematic then
      local distance = world.magnitude(entity.position(), position)
      if distance < 15 and self.assignmentRank == 1 then
        storage.playedCinematic = true
        player.playCinematic(self.arrivalCinematic)
      end
    end
    coroutine.yield()
  end
end