require("/scripts/quest/serialize.lua")
require("/scripts/quest/messaging.lua")
require("/scripts/achievements.lua")

-- QuestParticipants are the entities which are involved in quests that are
-- neither the quest giver, nor the player, i.e. NPCs that are required to
-- change their behavior while the quest is active, or offer to turn in quests.

QuestParticipant = {}
QuestParticipant.__index = QuestParticipant

function QuestParticipant.new(storageName, outbox)
  local self = setmetatable({}, QuestParticipant)
  self.data = createStorageArea(storageName, jobject())
  self.data.roles = self.data.roles or {}
  self.data.quests = self.data.quests or {}
  self.data.questValues = self.data.questValues or {}

  self.data.questsRemaining = self.data.questsRemaining or util.randomIntInRange(config.getParameter("questGenerator.questCountRange"))

  self.outbox = outbox
  self.dead = false

  self:setHandlers()
  self:updateTurnInQuests()
  self:updateOfferedQuests()
  return self
end

function QuestParticipant:hasActiveQuest()
  for stagehand, role in pairs(self.data.roles) do
    if not isEmpty(role.players) then
      return true
    end
  end
  return false
end

function QuestParticipant:hasRole()
  return not isEmpty(self.data.roles)
end

function QuestParticipant:hasQuest()
  return not isEmpty(self.data.quests)
end

function QuestParticipant:sendToStagehands(message, ...)
  local selfUniqueId = entity.uniqueId()
  for stagehand, role in pairs(self.data.roles) do
    self.outbox:sendMessage(stagehand, message, selfUniqueId, ...)
  end
end

function QuestParticipant:die()
  self:fireEvent("death", storage.respawner)

  self:sendToStagehands("participantDied", storage.respawner)

  self.outbox:offload()
  self.dead = true
end

function QuestParticipant:cancelQuest()
  self:sendToStagehands("participantCancelled")
end

function QuestParticipant:uninit()
  if not self.dead then
    self.outbox:uninit()
  end
end

function QuestParticipant:update()
  self.outbox:update()

  -- Update offered quests if a cooldown has expired
  for _,role in pairs(self.data.roles) do
    if role.offerQuest and not role.cancelOffer and role.offerCooldown and role.offerCooldown < world.time() then
      self:updateOfferedQuests()
      break
    end
  end

  self:checkStagehands()
end

function QuestParticipant:checkStagehands()
  -- Recover from /clearStagehand commands, script errors, etc.
  for stagehand, role in pairs(self.data.roles) do
    if not world.findUniqueEntity(stagehand):result() then
      self:unreserveHandler(stagehand, role.arc)
    end
  end
end

function QuestParticipant:setHandlers()
  -- Messages from the quest stagehand
  -- reserve: sent when a new quest is being offered that involves this entity
  -- unreserve: sent when the quest is no longer being offered or played
  -- stopOffering: when a quest we're offering should no longer be offered
  -- playerStarted: sent when a player accepts a quest we've been reserved for
  -- playerCompleted/Failed: sent when a player fails/completes a quest we've
  --    been reserved for
  message.setHandler("reserve", function(_, _, ...) self:reserveHandler(...) end)
  message.setHandler("unreserve", function(_, _, ...) self:unreserveHandler(...) end)
  message.setHandler("stopOffering", function(_, _, ...) self:stopOfferingHandler(...) end)
  message.setHandler("playerStarted", function(_, _, ...) self:playerStartedHandler(...) end)
  message.setHandler("playerFailed", function(_, _, ...) self:playerFinishedHandler(false, ...) end)
  message.setHandler("playerCompleted", function(_, _, ...) self:playerFinishedHandler(true, ...) end)
  -- playerAcceptedOffer: sent when a player accepts a quest via the new quest dialog (before the quest has started)
  -- playerDeclinedOffer: sent when a player declines a quest via the new quest dialog
  message.setHandler("playerAcceptedOffer", function(_, _, ...) self:playerAcceptedOfferHandler(...) end)
  message.setHandler("playerDeclinedOffer", function(_, _, ...) self:playerDeclinedOfferHandler(...) end)
end

function QuestParticipant:updateTurnInQuests()
  local turnInQuests = config.getParameter("turnInQuests", jarray())
  for _,role in pairs(self.data.roles) do
    for _,questId in ipairs(role.turnInQuests) do
      turnInQuests[#turnInQuests+1] = questId
    end
  end

  if entity.entityType() == "npc" then
    npc.setTurnInQuests(turnInQuests)
  elseif entity.entityType() == "object" then
    object.setTurnInQuests(turnInQuests)
  end
end

function QuestParticipant:updateOfferedQuests()
  local offeredQuests = config.getParameter("offeredQuests", jarray())
  for _,role in pairs(self.data.roles) do
    if role.offerQuest and not role.cancelOffer then
      if not role.offerCooldown or role.offerCooldown < world.time() then
        offeredQuests[#offeredQuests+1] = loadQuestArcDescriptor(role.offerQuest)
        role.offerCooldown = nil
      end
    end
  end

  self.isOfferingQuests = #offeredQuests > 0
  
  if entity.entityType() == "npc" then
    npc.setOfferedQuests(offeredQuests)
  elseif entity.entityType() == "object" then
    object.setOfferedQuests(offeredQuests)
  end
end

function QuestParticipant:isQuestGiver()
  if #config.getParameter("offeredQuests", jarray()) > 0 then
    return true
  end
  for _,role in pairs(self.data.roles) do
    if role.offerQuest and not role.cancelOffer then
      return true
    end
  end
end

function QuestParticipant:reserveHandler(stagehand, arc, role)
  -- The format of role is:
  --  {
  --    turninQuests : [QuestId],
  --    offerQuest : Maybe QuestArcDescriptor,
  --    participateIn : Map QuestId Boolean,
  --    behaviorOverrides : Map QuestId [{
  --      type : String,
  --      target : Maybe String,
  --      behavior : Maybe { name : String }
  --    }]
  --  }
  self.outbox.contactList:registerWorldEntity(stagehand)

  role.players = {}
  self.data.roles[stagehand] = role
  role.arc = arc

  for _,questDesc in ipairs(arc.quests) do
    self.data.quests[questDesc.questId] = storeQuestDescriptor(questDesc)

    self.data.questValues[questDesc.questId] = self.data.questValues[questDesc.questId] or {}
  end

  self:updateTurnInQuests()
  self:updateOfferedQuests()
end

function QuestParticipant:questParameter(questId, paramName)
  return self:questParameters(questId)[paramName]
end

function QuestParticipant:questDescriptor(questId)
  return loadQuestDescriptor(self.data.quests[questId])
end

function QuestParticipant:questParameters(questId)
  local questDesc = self:questDescriptor(questId)
  if not questDesc then return nil end
  return questDesc.parameters
end

function QuestParticipant:setQuestParameters(questId, parameters)
  local questDesc = loadQuestDescriptor(self.data.quests[questId])
  questDesc.parameters = parameters
  self.data.quests[questId] = storeQuestDescriptor(questDesc)
end

function QuestParticipant:forEachOverride(stagehand, player, questId, func)
  local role = self.data.roles[stagehand]
  if not role then return end

  for i, overrideDef in ipairs(role.behaviorOverrides[questId] or {}) do
    local overrideId = questId .. "-" .. i .. "-" .. player

    local override = shallowCopy(overrideDef)
    override.questId = questId
    if override.target == "player" then
      override.target = player
    elseif override.target ~= nil then
      local targetParam = self:questParameter(questId, override.target)
      if targetParam and targetParam.uniqueId then
        override.target = targetParam.uniqueId
      else
        error("Behavior override target '"..override.target.."' is not a QuestEntity parameter")
      end
    end

    func(overrideId, override)
  end
end

function QuestParticipant.addOverride(overrideId, override)
  if entity.entityType() ~= "object" then
    require("/scripts/actions/overrides.lua")
    addOverride(overrideId, override)
  end
end

function QuestParticipant.removeOverride(overrideId)
  if entity.entityType() ~= "object" then
    require("/scripts/actions/overrides.lua")
    removeOverride(overrideId)
  end
end

function QuestParticipant:unreserveHandler(stagehand, arc)
  local role = self.data.roles[stagehand]
  if not role then return end

  for player, questId in pairs(role.players) do
    self:forEachOverride(stagehand, player, questId, self.removeOverride)
  end

  for _,questDesc in ipairs(arc.quests) do
    self.data.quests[questDesc.questId] = nil
    self.data.questValues[questDesc.questId] = nil
  end

  self.data.roles[stagehand] = nil

  if entity.entityType() == "npc" and self.data.hadCompleteOfferedQuest and isEmpty(self.data.roles) then
    -- We've been offering a quest and now it has completed and we're not
    -- involved in any other quests.
    -- Now we have a random chance at graduating / changing into a new npctype.

    if self.data.questsRemaining then
      self.data.questsRemaining = self.data.questsRemaining - 1
      if self.data.questsRemaining <= 0 then
        tenant.graduate()
      end
    end
    self.data.hadCompleteOfferedQuest = false
  end

  self:updateTurnInQuests()
  self:updateOfferedQuests()
end

function QuestParticipant:stopOfferingHandler(stagehand, cooldown)
  -- If cooldown is nil, the quest is permanently no longer offered.
  local role = self.data.roles[stagehand]
  if not role then return end

  if cooldown == nil then
    role.cancelOffer = true
  else
    role.offerCooldown = world.time() + cooldown
  end
  self:updateOfferedQuests()
end

function QuestParticipant:playerAcceptedOfferHandler(stagehand, player, questId)
  if notify then
    local entityId = world.loadUniqueEntity(player)
    notify({
        type = "questOfferAccepted",
        sourceId = entityId
      })
  end
end

function QuestParticipant:playerDeclinedOfferHandler(stagehand, player, questId)
  if notify then
    local entityId = world.loadUniqueEntity(player)
    notify({
        type = "questOfferDeclined",
        sourceId = entityId
      })
  end
end

function QuestParticipant:playerStartedHandler(stagehand, player, questId, updatedParameters)
  local role = self.data.roles[stagehand]
  if not role then return end
  self.outbox.contactList:registerPlayerEntity(player)

  self:setQuestParameters(questId, updatedParameters)

  if role.offerQuest then
    if self.onOfferedQuestStarted then
      self.onOfferedQuestStarted(role.offerQuest)
    end
  end

  role.players[player] = questId
  self:forEachOverride(stagehand, player, questId, self.addOverride)
end

function QuestParticipant:playerFinishedHandler(complete, stagehand, player, questId)
  local role = self.data.roles[stagehand]
  if not role then return end

  role.players[player] = nil
  self:forEachOverride(stagehand, player, questId, self.removeOverride)

  if complete then
    for _,delta in ipairs(role.stateDeltas[questId] or {}) do
      self:applyStateDelta(delta.type, delta.arguments)
    end

    -- If we were offering this quest, and it was the last in a sequence,
    -- remember that it was completed successfully.
    if role.offerQuest then
      local lastQuestId = nil
      for _,quest in pairs(loadQuestArcDescriptor(role.offerQuest).quests) do
        lastQuestId = quest.questId
      end
      if questId == lastQuestId then
        self.data.hadCompleteOfferedQuest = true

        if tenant and tenant.isTenant() then
          recordEvent(player, "completeTenantQuest", entityEventFields(entity.id()), worldEventFields())
        end
      end
    end
  end

  if role.offerQuest then
    if self.onOfferedQuestFinished then
      self.onOfferedQuestFinished(role.offerQuest, complete)
    end
  end
end

function QuestParticipant:applyStateDelta(type, arguments)
  if type == "addRelationship" then
    addRelationship(table.unpack(arguments))
  elseif type == "removeRelationship" then
    removeRelationship(table.unpack(arguments))
  elseif type == "setCriminal" then
    setCriminal(table.unpack(arguments))
  elseif type == "setStolen" then
    setStolen(table.unpack(arguments))
  elseif type == "unsetStolen" then
    unsetStolen(table.unpack(arguments))
  else
    error("Unable to apply NPC state delta "..type.." following quest completion")
  end
end

function QuestParticipant:fireEvent(eventName, ...)
  local uniqueId = entity.uniqueId()
  for stagehand, role in pairs(self.data.roles) do
    for player, questId in pairs(role.players) do
      if role.participateIn[questId] then
        local message = questId..".participantEvent"
        self.outbox:sendMessage(player, message, uniqueId, eventName, ...)
      end
    end
  end
end

function QuestParticipant:getQuestValue(questId, varName)
  return self.data.questValues[questId][varName]
end

function QuestParticipant:setQuestValue(questId, varName, value)
  self.data.questValues[questId][varName] = value
end
