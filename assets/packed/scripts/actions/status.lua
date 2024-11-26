-- param resource
-- param percentage
function resourcePercentage(args, board)
  return status.resourcePercentage(args.resource) > args.percentage
end

-- param statName
-- output value
function stat(args, board)
  return true, {value = status.stat(args.statName)}
end

-- param resource
-- param amount
function setResource(args, board)
  status.setResource(args.resource, args.amount)
  return true
end

-- param resource
-- param percentage
function setResourcePercentage(args, board)
  status.setResourcePercentage(args.resource, args.percentage)
  return true
end

-- param name
-- param duration
function addEphemeralEffect(args, board)
  if args.name == nil or args.name == "" then return false end

  status.addEphemeralEffect(args.name, args.duration)
  return true
end

-- param name
function removeEphemeralEffect(args, board)
  if args.name == nil then return false end

  status.removeEphemeralEffect(args.name)
  return true
end

-- param category
-- param stat
-- param amount
function addStatModifier(args, board)
  if args.stat == nil or args.amount == nil then return false end

  status.addPersistentEffect(args.category, {stat = args.stat, amount = args.amount})
  return true
end

-- param category
function clearPersistentEffects(args, board)
  status.setPersistentEffects(args.category, {})
  return true
end

function suicide(args, board)
  status.setResource("health", 0)
  return true
end
