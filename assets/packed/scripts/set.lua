require "/scripts/util.lua"

set = {}

function set.null()
  return {}
end

function set.new(values)
  local newSet = {}
  for _,value in pairs(values) do
    newSet[value] = true
  end
  return newSet
end

function set.empty(set)
  return isEmpty(set)
end

function set.intersection(a, b)
  return util.zipWith(a, b, function(v1, v2)
      return v1 and v2
    end)
end

function set.union(a, b)
  return util.zipWith(a, b, function(v1, v2)
      return v1 or v2
    end)
end

function set.difference(a, b)
  return util.zipWith(a, b, function(v1, v2)
      return v1 and not v2
    end)
end

function set.values(set)
  return util.tableKeys(set)
end

function set.insert(set, value)
  set[value] = true
end

function set.remove(set, value)
  set[value] = nil
end

function set.equals(a, b)
  return compare(a, b)
end

function set.contains(a, value)
  return a[value] ~= nil
end

function set.containsAll(a, b)
  return set.equals(b, set.intersection(a, b))
end
