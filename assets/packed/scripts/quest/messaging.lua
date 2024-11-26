require("/scripts/util.lua")

function createStorageArea(name, default)
  storage[name] = storage[name] or default or {}
  return storage[name]
end

ContactList = {}
ContactList.__index = ContactList

function ContactList.new(storageName)
  local self = setmetatable({}, ContactList)
  self:init(storageName)
  return self
end

function ContactList:init(storageName)
  self.contacts = createStorageArea(storageName, jobject())
end

function ContactList:toJson()
  return self.contacts
end

function ContactList:registerContacts(contacts)
  for uniqueId, contact in pairs(contacts) do
    self.contacts[uniqueId] = contact
  end
end

function ContactList:setEnabled(uniqueId, enabled)
  self.contacts[uniqueId].disabled = not enabled
end

function ContactList:isEnabled(uniqueId)
  return not self.contacts[uniqueId].disabled
end

function ContactList:isEntityAvailable(uniqueId)
  local contact = self.contacts[uniqueId] or {}
  return not self:shouldPostponeContact(uniqueId, contact)
end

function ContactList:isPlayer(uniqueId)
  local contact = self.contacts[uniqueId] or {}
  return contact.player == true
end

function ContactList:shouldPostponeContact(uniqueId, contact)
  if contact.disabled then
    return true
  end
  if contact.player then
    -- Postpone messages if the player is not on this world at this time
    local entityId = world.loadUniqueEntity(uniqueId)
    if not entityId or not world.entityExists(entityId) then
      return true
    end
  end
  return false
end

function ContactList:registerPlayerEntity(uniqueId)
  if not self.contacts[uniqueId] then
    self.contacts[uniqueId] = {
        player = true
      }
  end
end

function ContactList:registerWorldEntity(uniqueId)
  if not self.contacts[uniqueId] then
    self.contacts[uniqueId] = {}
  end
end

-- The main purpose of Outbox is to queue up messages for other entities that
-- aren't accessible right now, either because they're disconnected (player),
-- or are on a different world or universe.
--
-- For example, a quest-giving NPC may need to tell players who have taken on
-- its quest that they should fail their quests. If those players are not
-- in the world, or even on the server, the outbox stores those messages until
-- they are. (If the quest-giver entity dies, it can offload those queued
-- messages onto an invisible stagehand entity)
--
-- If the player is no longer taking part in that quest, the promise returned
-- by sendEntityMessage will return failure because no quest handled the
-- message. The outbox can return this failure to its owner via the
-- failureHandler.
--
-- There are limitations to be aware of. Particularly:
--   * Messages can only be delivered when both sender and receiver are on the
--     same world and server at the same time.
--   * In order to provide reliability, messages can end up being delivered
--     multiple times. This happens when the sender uninitializes while there
--     are sent messages for which the response (a JsonPromise) is not finished
--     yet. The outbox has to assume those messages failed and resend them when
--     it reinitializes.
-- Message recipients should be designed to handle these limitations gracefully.
Outbox = {}
Outbox.__index = Outbox

function Outbox.new(storageName, contactList)
  local self = setmetatable({}, Outbox)
  self.contactList = contactList
  self.sent = {}
  self.failureHandler = nil
  self.debug = false

  self.overwritableMessages = {}
  self.postponed = createStorageArea(storageName, jarray())
  return self
end

function Outbox:empty()
  return #self.sent == 0 and #self.postponed == 0
end

-- Finds or creates a nearby stagehand entity to deliver our remaining messages
-- when the current NPC entity dies.
function Outbox:offload()
  self:uninit()

  local position = entity.position()

  local mailboxes = world.entityQuery(position, 5, {
      includedTypes = {"stagehand"},
      callScript = "stagehand.typeName",
      callScriptResult = "mailbox"
    })
  local targetMailbox = nil
  if mailboxes and #mailboxes > 0 then
    targetMailbox = mailboxes[1]
  else
    targetMailbox = world.spawnStagehand(position, "mailbox")
  end
  world.callScriptedEntity(targetMailbox, "post", self.contactList:toJson(), self.postponed)
end

function Outbox:uninit()
  -- Assume all sent unfinished messages failed and postpone them all for retrying
  for _,messageData in ipairs(self.sent) do
    if not messageData.options.unreliable and not messageData.options.overwritable then
      self:logMessage(messageData, "assuming unfinished message failed")
      self:postpone(messageData)
    end
  end
  self.sent = {}
end

function Outbox:log(text)
  if self.debug then
    local uniqueId = entity.uniqueId() or entity.id()
    sb.logInfo(tostring(entity.entityType()).." "..uniqueId.." "..tostring(text))
  end
end

function Outbox:logMessage(messageData, status)
  if self.debug then
    local available = self.contactList:isEntityAvailable(messageData.recipient)
    local availableMsg = available and "available" or "unavailable"
    self:log(status.." message: "..messageData.message.." to: "..messageData.recipient.." ("..availableMsg..")")
  end
end

function Outbox:updateSentMessage(messageData)
  if messageData.response:finished() then
    if not messageData.response:succeeded() then
      self:logMessage(messageData, "failed")
      if self.failureHandler then
        self.failureHandler(messageData, messageData.response:error())
      end
    else
      self:logMessage(messageData, "succeeded")
    end
    return true
  end

  return false
end

function filterNot(fun, array)
  local removeIndices = {}
  for i,elem in ipairs(array) do
    if fun(elem) then
      table.insert(removeIndices, 1, i)
    end
  end
  for _,i in ipairs(removeIndices) do
    table.remove(array, i)
  end
end

function Outbox:update()
  -- check sent messages for failure, and resend if necessary
  filterNot(bind(Outbox.updateSentMessage, self), self.sent)

  -- Attempt to send postponed messages
  filterNot(bind(Outbox.trySend, self), self.postponed)

  -- Attempt to send postponed overwritable messages
  for key,messageData in pairs(self.overwritableMessages) do
    if self:trySend(messageData) then
      self.overwritableMessages[key] = nil
    end
  end
end

function Outbox:trySend(messageData)
  if self.contactList:isEntityAvailable(messageData.recipient) then
    local promise = world.sendEntityMessage(messageData.recipient, messageData.message, table.unpack(messageData.args))
    if not messageData.options.unreliable then
      messageData.response = promise
      self.sent[#self.sent+1] = messageData
    end
    self:logMessage(messageData, "sent")
    return true
  end
  return false
end

function Outbox:postpone(messageData, disableOverwrite)
  messageData.response = nil
  if messageData.options.overwritable then
    local key = messageData.recipient..":"..messageData.message
    if disableOverwrite and self.overwritableMessages[key] then
      return
    end
    self.overwritableMessages[key] = messageData
  else
    self.postponed[#self.postponed+1] = messageData
  end
  self:logMessage(messageData, "postponed")
end

function Outbox:sendMessageWithOptions(options, recipient, message, ...)
  local messageData = {
      options = options,
      recipient = recipient,
      message = message,
      args = {...}
    }
  if not self:trySend(messageData) then
    self:postpone(messageData)
  end
end

function Outbox:sendMessage(recipient, message, ...)
  self:sendMessageWithOptions({}, recipient, message, ...)
end

-- An unreliable message is one where we don't care if it fails, and we don't
-- even bother to postpone it if the recipient isn't present.
function Outbox:unreliableMessage(recipient, message, ...)
  self:trySend({
      options = {unreliable = true},
      recipient = recipient,
      message = message,
      args = {...}
    })
end

-- A message is overwritable if it can be discarded when:
--   * This entity uninitializes
--   * A second message with the same text is queued up
-- Although this means the message can be lost sometimes, it is still postponed
-- if the recipient is not present.
function Outbox:overwritableMessage(recipient, message, ...)
  return self:sendMessageWithOptions({overwritable = true}, recipient, message, ...)
end
