function createClass(name)
  local class = {}
  class.__index = class
  class.className = name

  function class.new(...)
    local self = setmetatable({}, class)
    self:init(...)
    return self
  end

  function class:init(...)
    self.args = {...}
  end

  function class:toString()
    local contents = self.args
    if not contents then
      contents = self
    end
    return self.className .. util.tableToString(contents)
  end

  function class:__tostring()
    return self:toString()
  end

  return class
end

function defineSubclass(super, name)
  return function (def)
      local class = def or {}
      class.__index = class
      class.className = name
      setmetatable(class, super)

      function class.new(...)
        local self = setmetatable({}, class)
        self:init(...)
        return self
      end

      function class:__tostring()
        return self:toString()
      end

      return class
    end
end

function subclass(super, name)
  return defineSubclass(super, name) {}
end

function match(value)
  local mt = getmetatable(value)
  return function (cases)
    local case = (mt and cases[mt]) or cases.default
    if not case then
      local name
      if mt then name = mt.className end
      error("Unhandled case "..type(value).." "..tostring(name))
    end
    return case(value)
  end
end

function listMatch(list, cases)
  local matchers = {}
  for k,_ in pairs(cases) do
    matchers[#matchers+1] = k
  end
  table.sort(matchers, function (a,b)
      return b == "default" or a ~= "default" and a[1] < b[1]
    end)
  for _,matcher in ipairs(matchers) do
    if matcher ~= "default" then
      if matcher[2](list) then
        return cases[matcher]
      end
    end
  end
  if cases.default ~= nil then
    return cases.default
  end
  error("Unhandled case in listMatch")
end

Any = {"Any"}
NonNil = {"NonNil"}
Nil = {"Nil"}
function case(precedence, ...)
  local matchElems = {...}
  return {precedence, function (list)
      for i,matchElem in ipairs(matchElems) do
        local elem = list[i]
        if matchElem == Any then
        elseif matchElem == NonNil then
          if elem == nil or elem == Nil then
            return false
          end
        elseif matchElem == Nil then
          if elem ~= nil and elem ~= Nil then
            return false
          end
        elseif matchElem ~= elem and matchElem ~= getmetatable(elem) then
          return false
        end
      end
      return true
    end}
end

PrintableTable = createClass("PrintableTable")
function PrintableTable:init(tbl)
  if tbl then
    for k,v in pairs(tbl) do
      self[k] = v
    end
  end
end
