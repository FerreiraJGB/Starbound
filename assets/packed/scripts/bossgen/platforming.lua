require "/scripts/util.lua"
require "/scripts/questgen/util.lua"
require "/scripts/questgen/planner.lua"

-- Uses one predicand of a list of spaces and will unify with a spaceType relation
-- that is included in the spaces in the predicand. When negated, will unify
-- with any spaceType *outside* of the provided spaces. Negated spaceTypes are
-- always ignored
function inclusiveSpacesRelation(name, spaceType, priority)
  local relation = createRelation(name)
  relation.operatorIndex = spaceType
  relation.spaceType = spaceType
  relation.priority = priority
  function relation:find(x, y)
    local spaces = Predicand.value(self.predicands[1])
    for _,space in pairs(shuffled(spaces)) do
      if (x == nil or x == space[1]) and (y == nil or y == space[2]) then
        return space
      end
    end
    return nil
  end
  function relation:unifiable(term)
    if term.negated then return false end
    if term.name ~= self.spaceType then return false end
    if #term.predicands ~= #self.predicands + 1 then return false end
    -- make sure additional predicands are unifiable
    for i = 3, #term.predicands do
      if not Predicand.unifiable(term.predicands[i], self.predicands[i - 1]) then
        return false
      end
    end
    if self.negated then
      return self:find(Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2])) == nil
    else
      return self:find(Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2])) ~= nil
    end
    return true
  end
  function relation:unify(term)
    if not Predicand.isGround(term.predicands[1]) or not Predicand.isGround(term.predicands[2]) then
      local space = self:find(Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2]))
      Predicand.unify(term.predicands[1], space[1])
      Predicand.unify(term.predicands[2], space[2])
    end
    for i = 3, #term.predicands do
      Predicand.unify(term.predicands[i], self.predicands[i - 1])
    end
  end
  function relation:contradicts(state)
    for _,term in pairs(state:terms()) do
      if term.name == spaceType and term.negated then
        if (self.negated and self:find(Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2])) == nil)
           or (not self.negated and self:find(Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2])) ~= nil) then
          return true
        end
      end
    end
  end
  function relation:satisfiable()
    return false
  end

  return relation
end

PlatformingRelations = {}
PlatformingRelations[1] = createRelation("Floor")
PlatformingRelations[2] = createRelation("Danger")
PlatformingRelations[3] = createRelation("Reachable")
-- collection relations relating to spaces. not satisfiable, only use as preconditions
PlatformingRelations[4] = inclusiveSpacesRelation("FloorIn", "Floor")
PlatformingRelations[5] = inclusiveSpacesRelation("DangerIn", "Danger")
PlatformingRelations[6] = inclusiveSpacesRelation("ReachableIn", "Reachable")

local MoveTo = createRelation("MoveTo")
MoveTo.operatorIndex = "Floor"
MoveTo.spaceType = "Floor"
MoveTo.moveRules = {
  {0, 1},
  {1, 1},
  {2, 1}
}
function MoveTo:moveRule(fromX, fromY)
  local toX = Predicand.value(self.predicands[3])
  local toY = Predicand.value(self.predicands[4])
  for _,rule in pairs(self.moveRules) do
    for _,dir in pairs({-1, 1}) do
      local from = {fromX or toX - dir * rule[1], fromY or toY - rule[2]}
      local rule = {rule[1] * dir, rule[2]}
      if compare(vec2.add(from, rule), {toX, toY}) then
        return rule
      end
    end
  end
end
function MoveTo:unifiable(term)
  if term.negated then return false end
  if term.name ~= self.spaceType then return false end
  if not Predicand.isGround(self.predicands[3]) or not Predicand.isGround(self.predicands[4]) then
    return false
  end
  if #term.predicands ~= 2 then return false end
  -- make sure additional predicands are unifiable
  for i = 1, 2 do
    if not Predicand.unifiable(term.predicands[i], self.predicands[i]) then
      return false
    end
  end
  local fromX, fromY = Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2])
  return self:moveRule(fromX, fromY) ~= nil
end
function MoveTo:unify(term)
  if not Predicand.isGround(term.predicands[1]) or not Predicand.isGround(term.predicands[2]) then
    local rule = self:moveRule(Predicand.value(term.predicands[1]), Predicand.value(term.predicands[2]))
    local to = {Predicand.value(self.predicands[3], self.predicands[4])}
    Predicand.unify(self.predicands[1], vec2.sub(to, rule))
    Predicand.unify(self.predicands[2], vec2.sub(to, rule))
  end
  Predicand.unify(term.predicands[1], self.predicands[1])
  Predicand.unify(term.predicands[2], self.predicands[2])
end
function MoveTo:satisfiable()
  return false
end
PlatformingRelations[7] = MoveTo

PlatformingOperators = {
  movement = {
    preconditions = {
      {"MoveTo", "fromX", "fromY", "toX", "toY"}
    },
    postconditions = {
      {"Reachable", "toX", "toY"}
    }
  }
}
