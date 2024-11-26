require "/scripts/util.lua"

DataTypes = {
  "entity",
  "position",
  "vec2",
  "number",
  "bool",
  "list",
  "table",
  "string"
}

ListTypes = {
  "entity",
  "position",
  "vec2",
  "number",
  "bool",
  "string"
}

-- ACTIONS

-- param name
-- This should really just have an output
function setFlag(args, board)
  board:setBool(args.name, true)
  return true
end

-- param name
-- This should really just have an output
function unsetFlag(args, board)
  board:setBool(args.name, false)
  return true
end

function controlFlag(args, board)
  return true, {bool = args.bool}
end

-- param name
function hasFlag(args, board)
  return args.name == true
end

-- param list
-- param entity
-- param number
-- param position
-- param vec2
function listPush(args, board)
  local list = args.list or jarray()
  for _,type in pairs(ListTypes) do
    if args[type] then
      table.insert(list, args[type])
      return true, {list = list}
    end
  end
  return false, {list = list}
end

-- param list
-- param entity
-- param number
-- param position
-- param vector
function listPushBack(args, board)
  local list = args.list or jarray()
  for _,type in pairs(ListTypes) do
    if args[type] then
      table.insert(list, 1, args[type])
      return true, {list = list}
    end
  end
  return false, {list = list}
end

-- param list
-- output entity
-- output number
-- output position
-- output vector
function listPop(args, board)
  local list = args.list or jarray()
  local value = list[#list]
  if value == nil then return false end
  table.remove(list)
  return true, {list = list, entity = value, number = value, position = value, vector = value, table = value}
end

-- param list
-- output entity
-- output number
-- output position
-- output vector
function listGet(args, board)
  local list = args.list or jarray()
  local value = list[#list]
  if value == nil then return false end
  return true, {entity = value, number = value, position = value, vector = value}
end

-- param list
-- output number
function listSize(args, board)
  if args.list == nil then return false end
  return true, {number = #args.list}
end

-- param list
-- output list
function listShuffle(args, output)
  if args.list == nil then return false end
  return true, {list = shuffled(args.list)}
end

-- param list
-- output list
function listReverse(args, output)
  if args.list == nil then return false end

  local reversed = {}
  for _,v in pairs(args.list) do
    table.insert(reversed, v)
  end

  return true, {list = reversed}
end

-- param list
-- param entity
-- param number
-- param position
-- param vector
function listContains(args)
  if args.list == nil or #args.list == 0 then
    return false
  end
  for _,type in pairs(ListTypes) do
    if args[type] then
      if contains(args.list, args[type]) then
        return true
      end
    end
  end
  return false
end

-- param list
function listClear(args)
  return true, {list = jarray()}
end

-- param entity
-- output entity
function setEntity(args, output)
  return true, {entity = args.entity}
end

-- param entity
-- output entity ephemeral
function controlEntity(args, output)
  return true, {entity = args.entity}
end

-- param number
-- output number
function setNumber(args, output)
  if args.number == nil then return false end
  return true, {number = args.number}
end

-- param position
-- output position
function setPosition(args, output)
  if args.pos == nil then return false end
  return true, {position = pos}
end

-- param vector
-- output vector
function setVector(args, output)
  if args.vector == nil then return false end
  return true, {vector = args.vector}
end

-- param vector
-- output x
-- output y
function breakVector(args, output)
  if args.vector == nil then return false end
  return true, {x = args.vector[1], y = args.vector[2]}
end

-- param type
-- param key
function unset(args, board)
  if args.type == nil or args.key == nil then return false end
  board:set(args.type, args.key, nil)
  return true
end

-- param table
function setTable(args, output)
  return true, {table = args.table}
end
