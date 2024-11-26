require "/scripts/util.lua"

-- an asynchronous function produces a coroutine that can yield any number of times and returns once
function async(f)
 return function(...)
    local args = table.pack(...)
    return coroutine.create(function()
      return f(table.unpack(args))
    end)
 end
end

-- asynchronously waits for a coroutine and returns its return
function await(c)
  local s, res
  while true do
    local res = table.pack(coroutine.resume(c))
    if not res[1] then error(res[2]) end

    if coroutine.status(c) == "dead" then
      return table.unpack(res, 2)
    else
      coroutine.yield(table.unpack(res, 2))
    end
  end
end

-- ticks an async function once and returns the yield
function tick(c)
  local s, res = coroutine.resume(c)
  if not s then error(res) end
  
  local status = coroutine.status(c)
  return status, res
end

-- asynchronously waits for some duration
delay = async(function(duration)
  local timer = 0
  while timer < duration do
    coroutine.yield()
    timer = timer + script.updateDt()
  end
  return
end)

-- runs coroutines/functions in parallel until they have all finished
join = async(function(...)
  local actions = {}
  local returns = {}
  for i, c in ipairs(table.pack(...)) do
    if type(c) == "function" then
      c = coroutine.create(c)
    end
    returns[i] = nil
    table.insert(actions, {
      index = i,
      coroutine = c,
    })
  end

  while #actions > 0 do
    actions = util.filter(actions, function(a)
        local s, res = coroutine.resume(a.coroutine)
        if not s then error(res) end
        if coroutine.status(a.coroutine) == "dead" then
          returns[a.index] = res
          return false
        else
          return true
        end
      end)
    if #actions > 0 then
      coroutine.yield()
    end
  end

  return table.unpack(returns)
end)

-- runs coroutines/functions in parallel until one has finished
select = async(function(...)
  local actions = {}
  for i, c in ipairs(table.pack(...)) do
    if type(c) == "function" then
      c = coroutine.create(c)
    end
    table.insert(actions, c)
  end

  while true do
    for _,a in ipairs(actions) do
      local s, res = coroutine.resume(a)
      if not s then error(res) end

      if coroutine.status(a) == "dead" then
        return res
      end
    end

    coroutine.yield()
  end
end)