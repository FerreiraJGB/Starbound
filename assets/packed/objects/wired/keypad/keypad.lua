function init()
  self.interactData = config.getParameter("interactData")
  self.combinationLength = config.getParameter("combinationLength")
  storage.combination = storage.combination or config.getParameter("combination")
  storage.entry = storage.entry or ""

  message.setHandler("setKeypadCombination", function(_, _, newCombination)
    if type(newCombination) == "string" and #newCombination == self.combinationLength then
      storage.combination = newCombination
      clearEntry()
    end
  end)

  message.setHandler("setKeypadEntry", function(_, _, newEntry)
    storage.entry = newEntry
    checkCombination()
  end)

  message.setHandler("unlocked", function()
      return object.getOutputNodeLevel(0)
    end)

  message.setHandler("registerParticipant", function(_, _, questId, stagehandId)
      self.quest = {
        questId = questId,
        stagehand = stagehandId
      }
    end)

  object.setInteractive(true)
end

function onInteraction(args)
  self.interactData.combination = storage.combination
  self.interactData.entry = storage.entry
  self.interactData.combinationLength = self.combinationLength
  return {"ScriptPane", self.interactData}
end

function update(dt)

end

function checkCombination()
  object.setOutputNodeLevel(0, storage.entry == storage.combination)
  if self.quest and storage.entry == storage.combination then
    world.sendEntityMessage(self.quest.stagehand, "keypadUnlocked", entity.uniqueId(), self.quest.questId)
  end
end

function clearEntry()
  storage.entry = ""
  checkCombination()
end
