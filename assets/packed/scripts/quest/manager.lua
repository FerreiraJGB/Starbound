require("/scripts/set.lua")
require("/scripts/quest/serialize.lua")
require("/scripts/quest/messaging.lua")
require("/scripts/quest/manager/plugin.lua")

-- The quest manager is responsible for:
--  * Reserving entities participating in its quest arc and telling them what
--    they should do (i.e. sending them their roles and behaviors).
--  * Informing participating entities when a player starts or ends a quest.
--  * Telling the player if a quest has become incompletable and should fail.
--  * And in certain quests, spawning enemies and running other quest-specific
--    server-side scripting, via plugins.
--
-- This is not the _quest giver_. The quest giver is only a participant.
-- The quest manager is instead a stagehand so that the quest can continue when
-- the quest giver dies (if that makes sense for the specific quest).

QuestManager = {}
QuestManager.__index = QuestManager

function QuestManager.new(storageName, outbox, arc)
  local self = setmetatable({}, QuestManager)
  self.data = createStorageArea(storageName, jobject())
  self.outbox = outbox
  self.outbox.failureHandler = function (...) self:outboxFailureHandler(...) end

  message.setHandler("playerConsideringOffer", function (_, _, ...) self:playerConsideringOfferHandler(...) end)
  message.setHandler("playerDeclinedOffer", function (_, _, ...) self:playerDeclinedOfferHandler(...) end)
  message.setHandler("playerStarted", function (_, _, ...) self:playerStartedHandler(...) end)
  message.setHandler("playerFailed", function (_, _, ...) self:playerFailedHandler(...) end)
  message.setHandler("playerCompleted", function (_, _, ...) self:playerCompletedHandler(...) end)
  message.setHandler("participantDied", function (_, _, ...) self:participantDiedHandler(...) end)
  message.setHandler("participantCancelled", function (_, _, ...) self:cancel() end)

  self.uniqueId = arc.stagehandUniqueId
  assert(self.uniqueId == entity.uniqueId())

  self.data.playerProgress = self.data.playerProgress or {}
  self.data.playerStarted = self.data.playerStarted or {}
  if self.data.canceled == nil then
    self.data.canceled = false
  end
  if self.data.offering == nil then
    self.data.offering = false
  end

  self.data.participants = self.data.participants or {}
  self.data.nonMessagingParticipants = self.data.nonMessagingParticipants or {}
  self.data.criticalParticipants = self.data.criticalParticipants or {}
  self.data.pendingRespawns = self.data.pendingRespawns or {}

  if not self.data.arc then
    self.data.arc = storeQuestArcDescriptor(arc)
    self._arc = arc
    self:resetExpiration()
  end

  self.data.pluginStorage = self.data.pluginStorage or {}
  self.plugins = QuestPluginManager.new(self, self.data.pluginStorage, config.getParameter("plugins", {}))

  self.availablePlayers = {}

  return self
end

function QuestManager:arc()
  if not self._arc then
    self._arc = loadQuestArcDescriptor(self.data.arc)
  end
  return self._arc
end

function QuestManager:questDescriptor(questId)
  for _,questDesc in pairs(self:arc().quests) do
    if questDesc.questId == questId then
      return questDesc
    end
  end
end

function QuestManager:questParameters(questId)
  local questDesc = self:questDescriptor(questId)
  if not questDesc then return {} end
  return questDesc.parameters
end

function QuestManager:setQuestParameter(questId, paramName, paramValue)
  local arc = self:arc()
  for _,questDesc in pairs(arc.quests) do
    if questDesc.questId == questId then
      questDesc.parameters[paramName] = paramValue
      break
    end
  end
  self.data.arc = storeQuestArcDescriptor(arc)
end

function QuestManager:resetExpiration()
  self.data.expiration = world.time() + config.getParameter("quest.expiration", 300)
end

function QuestManager:finished()
  return self.data.canceled and isEmpty(self.data.playerProgress)
end

function QuestManager:nextQuestId(questId)
  local arcPos = nil
  for i,questDesc in ipairs(self:arc().quests) do
    if questDesc.questId == questId then
      arcPos = i
      break
    end
  end
  if arcPos == nil then
    error("Quest "..questId.." is not part of arc "..self.uniqueId)
  end
  arcPos = arcPos + 1
  if arcPos <= #self:arc().quests then
    return self:arc().quests[arcPos].questId
  end
  return nil -- Arc finished
end

function QuestManager:sendToPlayer(player, message, ...)
  local questId = self.data.playerProgress[player]
  if questId then
    self.outbox:sendMessage(player, questId .. "." .. message, ...)
  end
end

function QuestManager:sendToParticipants(message, ...)
  for participant,_ in pairs(self.data.participants) do
    self.outbox:sendMessage(participant, message, self.uniqueId, ...)
  end
end

function QuestManager:uninit()
  self.outbox:uninit()
end

function QuestManager:update()
  for participant, respawner in pairs(self.data.pendingRespawns) do
    if world.findUniqueEntity(participant):result() then
      -- The participant had died but has now respawned. Enable it again so
      -- we can send messages to it
      self.outbox.contactList:setEnabled(participant, true)
      self.data.pendingRespawns[participant] = nil

      local role = self.data.participants[participant]
      if not self:finished() then
        self.outbox:sendMessage(participant, "reserve", self.uniqueId, self:arc(), role)
        for player,questId in pairs(self.data.playerStarted) do
          self.outbox:sendMessage(participant, "playerStarted", self.uniqueId, player, questId)
        end
      end
    elseif not world.findUniqueEntity(respawner):result() then
      -- The respawner (deed) was destroyed while it was respawning the
      -- participant. The participant is now permanently dead.
      self:participantDiedHandler(participant, nil)
      self.data.pendingRespawns[participant] = nil
    end
  end

  for participant,_ in pairs(self.data.nonMessagingParticipants) do
    if self.outbox.contactList:isEnabled(participant) and not world.findUniqueEntity(participant):result() then
      -- Some participants (e.g. unscripted objects) aren't able to send a message
      -- when they die. We must assume they're gone permanently.
      self:participantDiedHandler(participant, nil)
    end
  end

  for player, questId in pairs(self.data.playerProgress) do
    local available = self.outbox.contactList:isEntityAvailable(player)
    if not self.availablePlayers[player] and available then
      self:sendToPlayer(player, "keepAlive")
    end
    self.availablePlayers[player] = available
  end

  if self.data.offering and isEmpty(self.data.playerProgress) and world.time() > self.data.expiration then
    self:stopOffering()
  end

  self.plugins:update()

  self.outbox:update()

  if not self:finished() then
    if not self.data.offering and isEmpty(self.data.playerProgress) then
      self:cancel()
    end
  end
end

function QuestManager:reserveParticipants(participants)
  for i = #self:arc().quests, 1, -1 do
    local questDesc = self:arc().quests[i]
    local questId = questDesc.questId

    for paramName,participantDef in pairs(participants[questId]) do
      local uniqueId = questDesc.parameters[paramName].uniqueId
      if uniqueId then
        self:reserveParticipant(questId, uniqueId, participantDef, paramName)
      end
    end
  end
end

function QuestManager:reserveParticipant(questId, uniqueId, participantDef, paramName)
  participantDef = participantDef or {}

  self.data.participants[uniqueId] = self.data.participants[uniqueId] or {
      turnInQuests = {},
      offerQuest = nil,
      behaviorOverrides = {},
      participateIn = {},
      stateDeltas = {}
    }

  local participant = self.data.participants[uniqueId]

  if participantDef.turnInQuest then
    participant.turnInQuests[#participant.turnInQuests+1] = questId
  end
  if participantDef.offerQuest then
    participant.offerQuest = self.data.arc
  end
  participant.behaviorOverrides[questId] = participantDef.behaviorOverrides or {}
  participant.participateIn[questId] = true
  participant.stateDeltas[questId] = participantDef.stateDeltas or {}

  if participantDef.critical then
    self.data.criticalParticipants[uniqueId] = self.data.criticalParticipants[uniqueId] or {}
    local quests = self.data.criticalParticipants[uniqueId]
    quests[#quests+1] = questId
  end

  self.outbox.contactList:registerWorldEntity(uniqueId)
  self.outbox:sendMessage(uniqueId, "reserve", self.uniqueId, self:arc(), participant)
  if participant.offerQuest then
    self.data.offering = true
  end
end

function QuestManager:outboxFailureHandler(messageData, reason)
  if self.data.participants[messageData.recipient] and world.findUniqueEntity(messageData.recipient):result() then
    local entityId = world.loadUniqueEntity(messageData.recipient)
    if world.entityType(entityId) == "object" then
      -- Certain participants (unscripted objects) can't send or receive messages,
      -- which means they can't send events to the player, and can't inform us
      -- when they die. We keep a track of them in a table so we can check when
      -- they die through findUniqueEntity
      self.data.nonMessagingParticipants[messageData.recipient] = true
      return
    end
  end

  if self.outbox.contactList:isPlayer(messageData.recipient) then
    local player = messageData.recipient
    local questId = self.data.playerStarted[player]
    if questId then
      self:playerFailedHandler(player, questId)
    end
    return
  end

  sb.logInfo("QuestManager messaging failure. Recipient: "..messageData.recipient.." Message: "..messageData.message.." Reason: "..reason)
  self:cancel()
end

function QuestManager:stopOffering(cooldown)
  -- If cooldown is nil, the quest is permanently no longer offered.
  for uniqueId, role in pairs(self.data.participants) do
    if role.offerQuest then
      self.outbox:sendMessage(uniqueId, "stopOffering", self.uniqueId, cooldown)
    end
  end
  if not cooldown then
    self.data.offering = false
  end
end

function QuestManager:cancel()
  if self.data.canceled then return end

  for _, questDesc in pairs(self:arc().quests) do
    self.plugins:questFinished(questDesc.questId)
  end

  self:sendToParticipants("unreserve", self:arc())

  for player,_ in pairs(self.data.playerProgress) do
    self:sendToPlayer(player, "abort")
  end

  self.data.playerProgress = {}
  self.data.playerStarted = {}

  self.data.offering = false
  self.data.canceled = true
end

-- "playerConsideringOffer" is sent when the 'New Quest' dialog opens on
-- the client. Here on the stagehand, we update the playerProgress table
-- to make sure the quest doesn't expire and get canceled while the dialog
-- is open.
function QuestManager:playerConsideringOfferHandler(player, questId)
  self.outbox.contactList:registerPlayerEntity(player)
  self.data.playerProgress[player] = questId
  self:resetExpiration()
end

function QuestManager:playerDeclinedOfferHandler(player, questId)
  self.data.playerProgress[player] = nil
  self:resetExpiration()

  for uniqueId, role in pairs(self.data.participants) do
    if role.offerQuest then
      self.outbox:sendMessage(uniqueId, "playerDeclinedOffer", self.uniqueId, player, questId)
    end
  end

  self:stopOffering()
end

function QuestManager:playerStartedHandler(player, questId)
  -- Send a message so that the quest giver can react to the player accepting
  -- the quest.
  for uniqueId, role in pairs(self.data.participants) do
    if role.offerQuest then
      self.outbox:sendMessage(uniqueId, "playerAcceptedOffer", self.uniqueId, player, questId)
    end
  end

  self.outbox.contactList:registerPlayerEntity(player)

  if not set.new(util.toList(self.data.playerStarted))[questId] then
    self.plugins:questStarted(questId)
  end

  self.data.playerProgress[player] = questId
  self.data.playerStarted[player] = questId

  self:sendToPlayer(player, "updateParameters", self:questParameters(questId))

  self.plugins:playerStarted(questId, player)
  self:sendToParticipants("playerStarted", player, questId, self:questParameters(questId))
  self:resetExpiration()
end

function QuestManager:playerFailedHandler(player, questId)
  self.data.playerProgress[player] = nil
  self.data.playerStarted[player] = nil
  self:sendToParticipants("playerFailed", player, questId)
  self:stopOffering()
  self:resetExpiration()
  self.plugins:playerFailed(questId, player)
end

function QuestManager:playerCompletedHandler(player, questId)
  local nextQuest = self:nextQuestId(questId)
  self.data.playerProgress[player] = nextQuest
  self.data.playerStarted[player] = nil
  self:sendToParticipants("playerCompleted", player, questId)
  if nextQuest == nil then
    self:stopOffering()
  end
  self.plugins:playerCompleted(questId, player)
end

function QuestManager:participantDiedHandler(participant, respawner)
  if not respawner then
    -- The participant is gone for good.
    -- Make all players who were relying on this participant fail.
    for _,questId in ipairs(self.data.criticalParticipants[participant] or {}) do
      local deletedPlayers = {}

      for player, progress in pairs(self.data.playerProgress) do
        if progress == questId then
          self:sendToPlayer(player, "abort")
          deletedPlayers[player] = true
        end
      end

      for player,_ in pairs(deletedPlayers) do
        self.data.playerProgress[player] = nil
        self.data.playerStarted[player] = nil
      end
    end

    self.outbox.contactList:setEnabled(participant, true)

    if self.data.participants[participant] and self.data.participants[participant].offerQuest then
      self:cancel()
    else
      self.data.participants[participant] = nil
      self.data.nonMessagingParticipants[participant] = nil
      self:stopOffering()
    end

  else
    -- The participant is gone temporarily, and should be respawned later.
    -- Disable it in the contactList so that we don't send any messages to it
    -- until it's back.
    self.outbox.contactList:setEnabled(participant, false)

    -- We also have to keep track of the respawner (the deed). If the respawner
    -- dies before the participant is respawned, the participant is essentially
    -- permanently dead.
    self.data.pendingRespawns[participant] = respawner
  end

  self.plugins:participantDied(participant, respawner)
end
