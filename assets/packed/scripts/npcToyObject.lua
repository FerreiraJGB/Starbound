npcToy = {
  npcCount = 0,
  currentNpcs = {}
}

function npcToy.getInfluence()
  return config.getParameter("npcToy.influence")
end

function npcToy.getDefaultReactions()
  return config.getParameter("npcToy.defaultReactions")
end

function npcToy.getPreciseStandPosition()
  if object.direction() < 0 then
    return config.getParameter("npcToy.preciseStandPositionLeft")
  else
    return config.getParameter("npcToy.preciseStandPositionRight")
  end
end

function npcToy.getImpreciseStandPosition()
  local standXRange = config.getParameter("npcToy.randomStandXRange")
  if standXRange == nil then return nil end

  local rangeMagnitude = standXRange[2] - standXRange[1]
  local x = standXRange[1] + math.random() * rangeMagnitude
  return {x, 0}
end

function npcToy.getMaxNpcs()
  return config.getParameter("npcToy.maxNpcs")
end

function npcToy.isOccupied()
  return npcToy.getMaxNpcs() ~= nil and npcToy.npcCount >= npcToy.getMaxNpcs()
end

function npcToy.isAvailable()
  -- override in objects that can be disabled / turned on/off:
  return not npcToy.isOccupied()
end

function npcToy.isPriority()
  return npcToy.npcCount > 0 and (npcToy.getMaxNpcs() == nil or npcToy.npcCount < npcToy.getMaxNpcs())
end

function npcToy.isOwnerOnly()
  return config.getParameter("npcToy.ownerOnly", false)
end

function npcToy.notifyNpcPlay(npcId)
  if not npcToy.isAvailable() then return end

  npcToy.currentNpcs[npcId] = true
  npcToy.npcCount = npcToy.npcCount + 1

  if onNpcPlay then
    onNpcPlay(npcId)
  end
end

function npcToy.notifyNpcPlayEnd(npcId)
  if npcToy.currentNpcs[npcId] then
    npcToy.currentNpcs[npcId] = nil
    npcToy.npcCount = npcToy.npcCount - 1

    if onNpcPlayEnd then
      onNpcPlayEnd(npcId)
    end
  end
end
