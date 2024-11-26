function recordEvent(player, eventName, ...)
  if not player then return end
  local eventFields = jobject()
  for _,fieldSet in ipairs({...}) do
    eventFields = sb.jsonMerge(eventFields, fieldSet)
  end
  world.sendEntityMessage(player, "recordEvent", eventName, eventFields)
end

function entityEventFields(entityId)
  local eventFields = {}
  eventFields.entityType = world.entityType(entityId)
  if eventFields.entityType == "npc" then
    eventFields.species = world.entitySpecies(entityId)
    eventFields.gender = world.entityGender(entityId)
    eventFields.npcType = world.npcType(entityId)
  elseif eventFields.entityType == "player" then
    eventFields.species = world.entitySpecies(entityId)
    eventFields.gender = world.entityGender(entityId)
  elseif eventFields.entityType == "monster" then
    eventFields.monsterType = world.monsterType(entityId)
  elseif eventFields.entityType == "object" then
    eventFields.objectName = world.entityName(entityId)
  end
  eventFields.aggressive = world.entityAggressive(entityId)

  local damageTeam = world.entityDamageTeam(entityId)
  eventFields.damageTeam = damageTeam.team
  eventFields.damageTeamType = damageTeam.type

  return eventFields
end

function worldEventFields()
  return {
      worldThreatLevel = world.threatLevel()
    }
end
