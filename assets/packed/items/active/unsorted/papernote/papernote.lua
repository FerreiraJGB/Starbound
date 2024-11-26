function activate()
  local configData = root.assetJson("/interface/scripted/papernote/papernotegui.config")
  configData.noteText = config.getParameter("noteText", "")
  activeItem.interact("ScriptPane", configData)

  local messageType = config.getParameter("questId", "") .. ".participantEvent"
  world.sendEntityMessage(activeItem.ownerEntityId(), messageType, nil, "foundClue")
  if config.getParameter("consumeOnUse", true) then
  	item.consume(1)
  end
end
