require "/scripts/companions/recruitable.lua"

function hasRecruiter(args, board)
  return recruitable.ownerUuid() ~= nil
end

-- output entity
function recruiterEntity(args, board)
  local uuid = recruitable.ownerUuid()
  if not uuid then return false end

  local entityId = world.loadUniqueEntity(uuid)
  if not entityId or not world.entityExists(entityId) then return false end

  return true, {entity = entityId}
end

function isFollowingRecruiter(args, board)
  return recruitable.isFollowing()
end

function hasFieldBenefit(args, board)
  local benefits = config.getParameter("crew.role.benefits", {})
  for _,benefit in pairs(benefits) do
    if benefit.type == "Regeneration" then
      return true
    end
  end
  return false
end

function hasCombatBenefit(args, board)
  local benefits = config.getParameter("crew.role.benefits", {})
  for _,benefit in pairs(benefits) do
    if benefit.type == "Regeneration" or benefit.type == "EphemeralEffect" then
      return true
    end
  end
  return false
end

function triggerFieldBenefit(args, board)
  recruitable.triggerFieldBenefits()
  return true
end

function triggerCombatBenefit(args, board)
  recruitable.triggerCombatBenefits()
  return true
end
