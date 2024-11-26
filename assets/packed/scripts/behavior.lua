require "/scripts/util.lua"
require "/scripts/behavior/bgroup.lua"
require "/scripts/behavior/bdata.lua"
-----------------------------------------------------------
-- DECORATOR NODES
-----------------------------------------------------------

function repeater(args, board, nodeId)
  local loops = 0

  local result
  repeat
    result = coroutine.yield()
    loops = loops + 1
  until (args.maxLoops > 0 and loops >= args.maxLoops) or (result == true and args.untilSuccess)

  return result
end

function failer(args, board, nodeId)
  coroutine.yield()
  return false
end

function succeeder(args, board, nodeId)
  coroutine.yield()
  return true
end

function inverter(args, board, nodeId)
  local result = coroutine.yield()
  return result == false
end

function cooldown(args, board, nodeId)
  local key = "cooldown-"..nodeId
  local time = board:get("number", key)
  if time and world.time() < time then
    return false
  end

  local result = coroutine.yield()
  if (args.onSuccess and result == true) or (args.onFail and result == false) then
    local cooldown = args.cooldown
    if type(cooldown) == "table" then
      cooldown = util.randomInRange(cooldown)
    end
    board:set("number", key, world.time() + cooldown)
  end
  return result
end

function filter(args, board, nodeId)
  if not args.list then return true end

  local i = 1
  while i <= #args.list do
    local filterItem = args.list[i]
    board:set(args.type, "filterItem", filterItem)

    local result = coroutine.yield()

    if result == false then
      table.remove(args.list, i)
    else
      i = i + 1
    end
  end
  return true
end

function each(args, board, nodeId)
  if not args.list then return true end

  for _,each in pairs(args.list) do
    board:set(args.type, "eachItem", each)

    result = coroutine.yield()
    if result == false then return false end
  end
  return true
end

function optional(args, board, nodeId)
  if args.shouldRun then
    local result = coroutine.yield()
    return result
  else
    return false
  end
end

function logResult(args, board, nodeId)
  local result = coroutine.yield()
  sb.logInfo(args.text, result)
  return result
end

function limiter(args, board, nodeId)
  local limit = args.limit or 1
  local runs = board:getNumber("limiter-"..nodeId) or 0
  if runs >= limit then return false end

  local result = coroutine.yield()
  if result == true then
    runs = runs + 1
    board:setNumber("limiter-"..nodeId, runs)
  end
  return result
end

-----------------------------------------------------------
-- ACTION NODES
-----------------------------------------------------------

function runner(args)
  while true do
    coroutine.yield(nil)
  end
end

function success(args)
  return true
end

function failure(args)
  return false
end

function halt(args)
  coroutine.yield(nil)
  return true
end

-- param text
function logInfo(args)
  sb.logInfo(args.text)
  return true
end

-- param key
-- output number
-- output position
-- output vector
function getStorage(args, board)
  local value = storage[args.key]
  if value == nil then return false end

  local output = {}
  for _,type in pairs(DataTypes) do
    output[type] = value
  end
  return true, output
end

-- param list
-- param entity
-- param number
-- param position
-- param vector
function setStorage(args, board)
  for _,type in pairs(DataTypes) do
    if args[type] ~= nil then
      storage[args.key] = args[type]
      break
    end
  end
  return true
end

-- param path
-- param default
-- output number
-- output position
-- output vector
function entityConfigParameter(args, board)
  local value = config.getParameter(args.path, args.default)

  local output = {}
  for _,type in pairs(DataTypes) do
    output[type] = value
  end
  return true, output
end

-- param property
-- output number
-- output bool
-- output table
function worldProperty(args, board)
  local value = world.getProperty(args.property)
  if not value then return false end

  local output = {}
  for _,type in pairs(DataTypes) do
    output[type] = value
  end
  return true, output
end

-- param groupId
-- param name
-- [output type list]
function groupResource(args, board)
  if args.groupId == nil or args.name == nil then return false end

  local value = BGroup:getResource(args.groupId, args.name)
  if value == nil then return false end

  local output = {}
  for _,type in pairs(DataTypes) do
    output[type] = value
  end
  return true, output
end

-- param func
-- param script
function runFunction(args, board)
  if args.func == nil or args.script == nil then return false end

  require(args.script)
  if _ENV[args.func] ~= nil and type(_ENV[args.func]) == "function" then
    _ENV[args.func](args.dt)
    return true
  end

  return false
end

function notify(notification)
  table.insert(self.notifications, notification)
  return true
end
