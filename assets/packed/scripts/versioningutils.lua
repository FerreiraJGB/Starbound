require "/scripts/util.lua"

-- find a key and/or value in a pile of structure and log the relevant path
-- (does no transformation, but useful for determining paths for versioning)
function findInData(data, keyname, value, path)
  if type(data) == "table" then
    path = path or "<base object>"
    for k, v in pairs(data) do
      if (k == keyname or keyname == nil) and (v == value or value == nil) then
        sb.logInfo("Found %s : %s in data at path %s", k, v, path)
      end
      findInData(v, keyname, value, string.format("%s.%s", path, k))
    end
  end
end

function hasPath(data, keyList)
  if #keyList == 0 then
    return true
  else
    local firstKey = table.remove(keyList, 1)
    if data[firstKey] ~= nil then
      return hasPath(data[firstKey], keyList)
    else
      return false
    end
  end
end

-- find a key and/or value in a pile of structure and execute the given function on the containing object
function executeWhere(data, keyname, value, f)
  if type(data) == "table" then
    local didExecute = false
    for k, v in pairs(data) do
      if not didExecute and (k == keyname or keyname == nil) and (v == value or value == nil) then
        f(data)
      end
      executeWhere(v, keyname, value, f)
    end
  end
end

-- find and replace a value buried in an opaque heap of structure
function replaceInData(data, keyname, value, replacevalue)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if (k == keyname or keyname == nil) and (v == value or value == nil) then
        -- sb.logInfo("Replacing value %s of key %s with value %s", v, k, replacevalue)
        data[k] = replacevalue
      else
        replaceInData(v, keyname, value, replacevalue)
      end
    end
  end
end

-- find and transform a value buried in an opaque heap of structure
function transformInData(data, keyname, transformfunction)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if k == keyname then
        -- sb.logInfo("Transforming value %s of key %s into value %s", v, k, transformfunction(copy(data[k])))
        data[k] = transformfunction(data[k])
      else
        transformInData(v, keyname, transformfunction)
      end
    end
  end
end

-- find and replace a key name buried in an opaque heap of structure
function replaceKeyInData(data, oldkey, newkey)
  if type(data) == "table" then
    if data[oldkey] ~= nil then
      if data[newkey] == nil then
        -- sb.logInfo("Renaming key %s to %s (value is %s)", oldkey, newkey, data[oldkey])
        data[oldkey], data[newkey] = nil, data[oldkey]
      else
        -- sb.logInfo("Cannot rename key %s to %s because it already exists with value %s", oldkey, newkey, data[newkey])
      end
    end

    for k, v in pairs(data) do
      replaceKeyInData(v, oldkey, newkey)
    end
  end
end

-- find and replace a string pattern buried in an opaque heap of structure
function replacePatternInData(data, keyname, pattern, replacevalue)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if (k == keyname or keyname == nil) and (type(v) == "string" and v:find(pattern)) then
        data[k] = v:gsub(pattern, replacevalue)
        -- sb.logInfo("Replacing value %s of key %s with value %s", v, k, data[k])
      else
        replacePatternInData(v, keyname, pattern, replacevalue)
      end
    end
  end
end

function removeFromData(data, keyname)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if k == keyname then
        data[k] = nil
      else
        removeFromData(v, keyname)
      end
    end
  end
end

function compare(t1,t2)
  if t1 == t2 then return true end
  if type(t1) ~= type(t2) then return false end
  if type(t1) ~= "table" then return false end
  for k,v in pairs(t1) do
    if not compare(v, t2[k]) then return false end
  end
  for k,v in pairs(t2) do
    if not compare(v, t1[k]) then return false end
  end
  return true
end

function find(t, predicate)
  local current = 0
  for i,value in ipairs(t) do
    if predicate(value) then
      return value, i
    end
  end
end
