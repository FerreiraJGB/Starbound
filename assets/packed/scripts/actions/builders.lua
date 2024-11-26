require "/scripts/behavior.lua"

-- Stores behavior trees for this context so they don't need to be rebuilt every time
BuilderTreeCache = {}

-- param actions
function sequenceActions(args, board, nodeId, dt)
  if #args.actions == 0 then return false end

  local tree = BuilderTreeCache["sequenceActions-"..nodeId]
  if not tree then
    local sequence = {
      type = "composite",
      name = "sequence",
      children = {}
    }
    for _,action in pairs(args.actions) do
      if action.parameters then
        for k,v in pairs(action.parameters) do
          if type(v) ~= "table" or (v.key == nil and v.value == nil) then
            action.parameters[k] = {value = v}
          end
        end
      end
      local actionModule = {
        type = "module",
        name = action.name,
        parameters = action.parameters or {}
      }
      if action.cooldown then
        local cooldown = {
          type = "decorator",
          name = "cooldown",
          parameters = {
            cooldown = {value = action.cooldown}
          }
        }
        cooldown.child = actionModule
        table.insert(sequence.children, cooldown)
      else
        table.insert(sequence.children, actionModule)
      end
    end
    tree = behavior.behavior({name = "sequenceActions-"..nodeId, root = sequence, scripts = jarray()}, config.getParameter("behaviorConfig", {}), _ENV, board)
    BuilderTreeCache["sequenceActions-"..nodeId] = tree
  else
    tree:clear()
  end

  while true do
    local result = tree:run(dt)
    if result == false or result == true then
      return result
    else
      dt = coroutine.yield()
    end
  end
end

-- param actions
function selectorActions(args, board, nodeId, dt)
  if #args.actions == 0 then return false end

  local tree = BuilderTreeCache["selectorActions-"..nodeId]
  if not tree then
    local selector = {
      type = "composite",
      name = args.dynamic and "dynamic" or "selector",
      children = {}
    }
    for _,action in pairs(args.actions) do
      if action.parameters then
        for k,v in pairs(action.parameters) do
          if type(v) ~= "table" or (v.key == nil and v.value == nil) then
            action.parameters[k] = {value = v}
          end
        end
      end
      local actionModule = {
        type = "module",
        name = action.name,
        parameters = action.parameters or {}
      }
      if action.cooldown then
        local cooldown = {
          type = "decorator",
          name = "cooldown",
          parameters = {
            cooldown = {value = action.cooldown}
          }
        }
        cooldown.child = actionModule
        table.insert(selector.children, cooldown)
      else
        table.insert(selector.children, actionModule)
      end
    end
    tree = behavior.behavior({name = "selectorActions-"..nodeId, root = selector, scripts = jarray()}, config.getParameter("behaviorConfig", {}), _ENV, board)
    BuilderTreeCache["selectorActions-"..nodeId] = tree
  else
    tree:clear()
  end

  while true do
    local result = tree:run(dt)
    if result == false or result == true then
      return result
    else
      dt = coroutine.yield()
    end
  end
end

-- param actions
function parallelActions(args, board, nodeId, dt)
  if #args.actions == 0 then return false end

  local tree = BuilderTreeCache["parallelActions-"..nodeId]
  if not tree then
    local parallel = {
      type = "composite",
      name = "parallel",
      children = {}
    }
    for _,action in pairs(args.actions) do
      if action.parameters then
        for k,v in pairs(action.parameters) do
          if type(v) ~= "table" or (v.key == nil and v.value == nil) then
            action.parameters[k] = {value = v}
          end
        end
      end
      local actionModule = {
        type = "module",
        name = action.name,
        parameters = action.parameters or {}
      }
      if action.cooldown then
        local cooldown = {
          type = "decorator",
          name = "cooldown",
          parameters = {
            cooldown = {value = action.cooldown}
          }
        }
        cooldown.child = actionModule
        table.insert(parallel.children, cooldown)
      else
        table.insert(parallel.children, actionModule)
      end
    end

    tree = behavior.behavior({name = "parallelActions-"..nodeId, root = parallel, scripts = jarray()}, config.getParameter("behaviorConfig", {}), _ENV, board)
    BuilderTreeCache["parallelActions-"..nodeId] = tree
  else
    tree:clear()
  end

  while true do
    local result = tree:run(dt)
    if result == false or result == true then
      return result
    else
      dt = coroutine.yield()
    end
  end
end
