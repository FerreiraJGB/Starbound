require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/async.lua"
require "/interface/cockpit/cockpitutil.lua"

local BiomeMicrodungeonId = 65533
local FirstMetaDungeonId = 65520

function init()
  self.pendingConfirmations = {}
  message.setHandler("confirm", function(_, _, dialogConfig)
      local uuid = sb.makeUuid()
      dialogConfig.paneLayout = "/interface/windowconfig/simpleconfirmation.config:paneLayout"
      self.pendingConfirmations[uuid] = player.confirm(dialogConfig)
      return uuid
    end)

  -- nil for unfinished, false for declined, true for accepted
  message.setHandler("confirmResult", function(_, _, uuid)
      local promise = self.pendingConfirmations[uuid]
      if not promise then
        return false
      end
      if promise:finished() then
        return promise:result()
      end
      return nil
    end)

  self.bountyMusicCount = 0
  self.musicTracks = {}
  self.playingMusic = false
  message.setHandler("startBountyMusic", function(_, _, tracks, fadeTime) 
    self.musicTracks = tracks
    self.bountyMusicCount = self.bountyMusicCount + 1
  end)

  message.setHandler("stopBountyMusic", function(_, _, fadeTime)
    self.bountyMusicCount = self.bountyMusicCount - 1
  end)

  -- offer a bounty assignment quest if the player has an assignment, but not on this server
  local bountyData = player.getProperty("bountyData") or {}
  bountyData = bountyData[player.serverUuid()] or nil
  if player.hasAcceptedQuest("bountyassignment") and not player.hasActiveQuest("bountyassignment") and bountyData == nil then
    player.startQuest("bountyassignment")
  end

  -- check that the station exists, this can take multiple ticks so keep doing it
  if bountyData then
    self.checkStation = checkBountyStation()
  end
end

function update(dt)
  if not self.playingMusic and self.bountyMusicCount > 0 then
    world.sendEntityMessage(player.id(), "playAltMusic", self.musicTracks, 2.0)
    self.playingMusic = true
  end
  if self.playingMusic and self.bountyMusicCount <= 0 then
    world.sendEntityMessage(player.id(), "stopAltMusic", 2.0)
    self.playingMusic = false
  end

  if self.checkStation then
    local status = tick(self.checkStation)
    if status == "dead" then
      self.checkStation = nil
    end
  end
end

function getBountyStation()
  local bountyStation = player.getProperty("bountyStation")
  return bountyStation[player.serverUuid()]
end

function getPlayerRank()
  local bountyRanks = root.assetJson("/quests/bounty/assignment.config:bountyRanks")
  local points = player.getProperty("bountyPoints") or 0
  local playerRank
  for i, rank in ipairs(bountyRanks) do
    if points >= rank.threshold then
      playerRank = i
    end
  end
  return playerRank
end

function getAssignmentRank()
  local bountyData = player.getProperty("bountyData") or {}
  bountyData = bountyData[player.serverUuid()] or {}
  local assignment = bountyData.assignment
  if assignment then
    return assignment.rank
  else
    return getPlayerRank()
  end
end

checkBountyStation = async(function()
  -- check if the bounty system is spawned
  while not compare(celestial.currentSystem(), getBountyStation().system) do
    await(delay(5.0))
  end

  local stationTypes = root.assetJson("/quests/bounty/assignment.config:rankStationTypes")
  local rank = getAssignmentRank()
  local stationType = stationTypes[rank]
  if stationType == nil then
    sb.logInfo("ERROR: Peacekeeper station type not defined for assignment rank %s", rank)
    return
  end
  local stationUuid = util.find(celestial.systemObjects(), function(o)
    if celestial.objectType(o) == stationType then
      return true
    else
      return false
    end
  end)
  if not stationUuid and player.hasAcceptedQuest("bountyassignment") and not player.hasActiveQuest("bountyassignment") then
    local bountyStation = player.getProperty("bountyStation")
    local serverStation = bountyStation[player.serverUuid()]
    if serverStation then
      bountyStation[player.serverUuid()] = {
        system = serverStation.system
      }
      player.setProperty("bountyStation", bountyStation)
    end

    player.startQuest("bountyassignment")
  end
end)