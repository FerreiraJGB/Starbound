function activate()
  local defaultPortrait = config.getParameter("defaultPortrait")
  local defaultPortraitFrames = config.getParameter("defaultPortraitFrames")
  local defaultSenderName = config.getParameter("defaultSenderName")
  local radioMessages = config.getParameter("radioMessages", {})
  for i, message in ipairs(radioMessages) do
    if type(message) == "string" then
      message = {
        messageId = "audioDiscMessage"..i,
        unique = false,
        text = message
      }
    end

    message.senderName = message.senderName or defaultSenderName

    if not message.portraitImage then
      message.portraitImage = defaultPortrait
      message.portraitFrames = defaultPortraitFrames
    end

    player.radioMessage(message)
  end

  local messageType = config.getParameter("questId", "") .. ".participantEvent"
  world.sendEntityMessage(activeItem.ownerEntityId(), messageType, nil, "foundClue")

  item.consume(1)
end
