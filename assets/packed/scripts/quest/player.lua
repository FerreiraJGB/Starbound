require("/scripts/quest/messaging.lua")

PlayerContactList = {}
setmetatable(PlayerContactList, { __index = ContactList })

function PlayerContactList.new(storageName)
  local self = setmetatable({}, { __index = PlayerContactList })
  self:init(storageName)
  return self
end

function PlayerContactList:registerWorldEntity(uniqueId, worldId, serverUuid)
  if not self.contacts[uniqueId] then
    self.contacts[uniqueId] = {
        server = serverUuid or player.serverUuid(),
        world = worldId or player.worldId()
      }
  end
end

function PlayerContactList:shouldPostponeContact(uniqueId, contact)
  if ContactList.shouldPostponeContact(self, uniqueId, contact) then
    return true
  end
  if contact.server and contact.server ~= player.serverUuid() then
    return true
  end
  if contact.world and contact.world ~= player.worldId() then
    return true
  end
  return false
end

QuestPlayer = {}
QuestPlayer.__index = QuestPlayer

function QuestPlayer.new(storageName, outbox)
  local self = setmetatable({}, QuestPlayer)
  self.data = createStorageArea(storageName, jobject())
  self.outbox = outbox
  self.outbox.failureHandler = function(...) self:outboxFailureHandler(...) end
  self.aborted = false
  self.eventHandlers = {}
  self:setMessageHandlers()
  return self
end

function QuestPlayer:uninit()
  self.outbox:uninit()
end

function QuestPlayer:playerId()
  return entity.uniqueId()
end

function QuestPlayer:stagehand()
  return quest.questArcDescriptor().stagehandUniqueId
end

function QuestPlayer:sendToStagehand(message, ...)
  self.outbox:sendMessage(self:stagehand(), message, ...)
end

function QuestPlayer:sendToStagehandUnreliable(message, ...)
  self.outbox:unreliableMessage(self:stagehand(), message, ...)
end

function QuestPlayer:questMessage(messageName)
  return quest.questId().."."..messageName
end

function QuestPlayer:setMessageHandlers()
  -- Messages from QuestManager (stagehand)
  -- abort: sent when the stagehand determines that the quest cannot be
  --   completed any more.
  -- keepAlive: sent by the stagehand to check that the quest is still active.
  -- participantEvent: notification that something happened to one of the entities
  --   participating in this quest, e.g. a particular quest-relevant NPC has been
  --   interacted with.
  -- updateParameters: sent as the quest begins so that any changes that any
  --   changes plugins on the questmanager create are reflected in the player
  --   quest script. For example, they might spawn new entities we need
  --   entity parameters for.
  self:setMessageHandler("abort", function (_, _, ...) self:questAbortHandler(...) end)
  self:setMessageHandler("keepAlive", function () end)
  self:setMessageHandler("participantEvent", function (_, _, ...) self:questParticipantEventHandler(...) end)
  self:setMessageHandler("updateParameters", function (_, _, ...) self:updateParametersHandler(...) end)
end

function QuestPlayer:setMessageHandler(messageName, handler)
  -- All messages we handle are prefixed by the questId so they that they are
  -- handled only by the right quest script on the player, not all of them.
  message.setHandler(quest.questId().."."..messageName, handler)
end

function QuestPlayer:updateParametersHandler(parameters)
  for paramName, paramValue in pairs(parameters) do
    quest.setParameter(paramName, paramValue)
  end
end

-- Key can be either an event name ("death", "interaction", ...) or a table
-- consisting of a template param name and an event name.
-- The parameters passed into the callback 'func' are the uniqueId and template
-- param name of the event's originating entity, followed by arguments that
-- depend on the event.
function QuestPlayer:setEventHandler(key, func)
  local entityKey, eventName
  if type(key) == "table" then
    entityKey, eventName = table.unpack(key)
    if quest.parameters()[entityKey] then
      entityKey = quest.parameters()[entityKey].uniqueId
    end
  else
    entityKey, eventName = "_", key
  end
  self.eventHandlers[entityKey] = self.eventHandlers[entityKey] or {}
  self.eventHandlers[entityKey][eventName] = func
end

function QuestPlayer:questParticipantEventHandler(entityUniqueId, eventName, ...)
  local args = {...}
  function callHandler(key)
    if self.eventHandlers[key] and self.eventHandlers[key][eventName] then
      self.eventHandlers[key][eventName](entityUniqueId, table.unpack(args))
    end
  end

  callHandler(entityUniqueId)
  callHandler("_")
end

function QuestPlayer:abort()
  self.aborted = true
  quest.fail()
end

function QuestPlayer:outboxFailureHandler(messageData, reason)
  -- The outbox fails if the quest giver is present but not handling our messages.
  -- This happens if the quest giver is no longer providing our quest.
  sb.logInfo("QuestPlayer messaging failure. Recipient: "..messageData.recipient.." Message: "..messageData.message.." Reason: "..reason)
  self:abort()
end

function QuestPlayer:questAbortHandler()
  self:abort()
end

function QuestPlayer:questComplete()
  self:sendToStagehand("playerCompleted", self:playerId(), quest.questId())
end

function QuestPlayer:questFail()
  if not self.aborted then
    self:sendToStagehand("playerFailed", self:playerId(), quest.questId())
  end
end

function QuestPlayer:questStart()
  local questArc = quest.questArcDescriptor()
  local stagehand = questArc.stagehandUniqueId
  if not stagehand then
    error("No stagehand defined for quest "..quest.questId().." ("..quest.templateId()..")")
  end
  self.outbox.contactList:registerWorldEntity(stagehand, quest.worldId(), quest.serverUuid())
  self:sendToStagehand("playerStarted", self:playerId(), quest.questId())
end

function QuestPlayer:questOffer()
  self:sendToStagehandUnreliable("playerConsideringOffer", self:playerId(), quest.questId())
end

function QuestPlayer:questDecline()
  self:sendToStagehandUnreliable("playerDeclinedOffer", self:playerId(), quest.questId())
end

function QuestPlayer:update()
  self.outbox:update()
end
