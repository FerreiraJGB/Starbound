Relation = createClass("Relation")
function Relation:init(negated, predicands, context)
  self.negated = negated
  self.predicands = predicands
  self.context = context
end

function Relation.fromJson(json, symbols, relations, vartable, context)
  local negated = false
  local relName = json[1]
  if not relations[relName] and relName:sub(1,1) == "!" then
    relName = relName:sub(2)
    negated = true
  end
  local relation = relations[relName]
  if not relation then
    error("Unknown relation "..relName)
  end

  local predicands = {}
  for i = 2, #json do
    local value = json[i]
    predicands[#predicands+1] = Predicand.fromJson(value, symbols, vartable)
  end
  return relation.new(negated, predicands, context)
end

function defineRelation(name, static, super)
  super = super or Relation
  return function (def)
      local relation = defineSubclass(super, name)(def)
      relation.name = name
      relation.static = static or false
      return relation
    end
end

-- Convenient shorthand when all you want to define for the relation is a new
-- query method.
function defineQueryRelation(name, static, super)
  return function (cases)
      return defineRelation(name, static, super) {
          query = Relation.unpackedQuery(cases)
        }
    end
end

function createRelation(name, static, super)
  return defineRelation(name, static, super) {}
end

function Relation:unpackPredicands(cases)
  local predValues = util.map(self.predicands, function (predicand)
      local value = Predicand.value(predicand)
      if value == nil then value = Nil end
      return value
    end)
  local case = listMatch(predValues, cases)
  if type(case) ~= "function" then
    return case
  end
  return case(self, table.unpack(predValues))
end

function Relation.unpackedQuery(cases)
  return function (self)
    return self:unpackPredicands(cases)
  end
end

-- A relation is static if no operators affect it, i.e. if it can not be used
-- in postconditions. (Heuristic)
function Relation:isStatic()
  return self.static
end

-- Returns true if there is at least one possible assignment of predicands.
function Relation:satisfiable()
  local results = self:query()
  return results == Relation.some or #results > 0
end

-- Returns one example predicand-list that would satisfy this predicate.
-- Or nil if that is not possible, or no examples are available right now.
function Relation:generate()
  local results = self:query()
  if results == Relation.some or #results == 0 then return nil end
  -- Only try 3 values. If a large number of results are returned, and there
  -- are a lot of constraints on the variables, trying every value could
  -- result in a long, expensive search that doesn't offer a (much) greater
  -- chance of success.
  for _,examplePredicands in ipairs(util.take(3, shuffled(results))) do
    local examplePredicate = self.new(self.negated, examplePredicands, self.context)
    if self:unifiable(examplePredicate) then
      return examplePredicate
    end
  end
  return nil
end

Relation.empty = {}
Relation.some = "some"
-- Returns all the possible values the variable predicands could have.
-- Valid return values are:
--  * A list of predicand-lists.
--  * Relation.empty - indicating no assignments can satisfy this predicate.
--  * Relation.some - indicating that some assignments could satisfy the
--    predicate but are not readily available for listing.
function Relation:query()
  if self.negated then return Relation.some end
  return Relation.empty
end

-- Returns any extra terms that are implied by this predicate.
function Relation:implications()
  return Conjunction.new()
end

-- Checks that this predicate does not contradict any other predicates in the
-- condition in non-standard ways. (The only standard contradiction is P & !P,
-- handled elsewhere, but e.g. loyal(X, Y) implies forall Z != Y. !loyal(X, Z),
-- so the loyal(X, Y), loyal(X, Z) contradiction is handled specially.)
function Relation:contradicts(condition)
  return false
end

-- Returns true if this predicate can be satisfied in the given state
-- (a conjunction). Unifies with the state if possible.
function Relation:satisfyWithState(state)
  if state:unifiable(self) then
    state:unify(self)
    return true
  end
  if state:containsTerm(self:negate()) or self:contradicts(state) then
    return false
  end
  local example = self:generate()
  if example then
    self:unify(example)
    return true
  end
  return self:satisfiable()
end

function Relation:isGround()
  for _,predicand in ipairs(self.predicands) do
    if not Predicand.isGround(predicand) then
      return false
    end
  end
  return true
end

function Relation:freeVariables()
  local count = 0
  for _,predicand in ipairs(self.predicands) do
    if not Predicand.isGround(predicand) then
      count = count + 1
    end
  end
  return count
end

function Relation:substitute(replacee, replacement)
  local predicands = {}
  for _,pred in ipairs(self.predicands) do
    if Predicand.matches(pred, replacee) then
      predicands[#predicands+1] = replacement
    else
      predicands[#predicands+1] = pred
    end
  end
  return self.new(self.negated, predicands, self.context)
end

function Relation:applyConstraints()
  for _,predicand in ipairs(self.predicands) do
    if not Predicand.isGround(predicand) then
      predicand:addConstraint(self)
    end
  end
end

function Relation:negate()
  return self.new(not self.negated, self.predicands, self.context)
end

function Relation:similarTo(predicate, predicandsSimilarFunc)
  if self.negated ~= predicate.negated then return false end
  if self.name ~= predicate.name then return false end
  if #self.predicands ~= #predicate.predicands then return false end
  for i,p in ipairs(self.predicands) do
    local q = predicate.predicands[i]
    if not predicandsSimilarFunc(p, q) then
      return false
    end
  end
  return true
end

function Relation:matches(predicate)
  return self:similarTo(predicate, Predicand.matches)
end

function Relation:unifiable(predicate)
  return self:similarTo(predicate, Predicand.unifiable)
end

function Relation:unify(predicate)
  for i,p in ipairs(self.predicands) do
    local q = predicate.predicands[i]
    Predicand.unify(p, q)
  end
end

function Relation:toString()
  local predicandStrs = {}
  for i,pred in ipairs(self.predicands) do
    predicandStrs[i] = tostring(pred)
  end
  local prefix = self.negated and "!" or ""
  return prefix..self.name.."("..table.concat(predicandStrs, ", ")..")"
end

BuiltinRelations = {
  ["!="] = defineQueryRelation("!=", true) {
    [case(1, NonNil, NonNil)] = function (self, a, b)
        if xor(self.negated, not Predicand.equalsHelper(a, b)) then
          return {{a,b}}
        else
          return Relation.empty
        end
      end,

    default = Relation.some
  },

  ["+"] = defineQueryRelation("+", true) {
    -- Relation: a + b = c
    -- Only defined for values >= 0
    [case(1, NonNil, NonNil, NonNil)] = function (self, a,b,c)
        if xor(a + b == c and a >= 0 and b >= 0, self.negated) then
          return {{a,b,c}}
        else
          return Relation.empty
        end
      end,

    [case(2, Nil, NonNil, NonNil)] = function (self, a,b,c)
        a = c - b
        if xor(a >= 0, self.negated) then
          return {{a,b,c}}
        else
          return Relation.empty
        end
      end,

    [case(3, NonNil, Nil, NonNil)] = function (self, a,b,c)
        b = c - a
        if xor(b >= 0, self.negated) then
          return {{a,b,c}}
        else
          return Relation.empty
        end
      end,

    [case(4, NonNil, NonNil, Nil)] = function (self, a,b,c)
        c = a + b
        if xor(c >= 0, self.negated) then
          return {{a,b,c}}
        else
          return Relation.empty
        end
      end,

    default = Relation.some
  },

  [">="] = defineQueryRelation(">=", true) {
    -- Relation: a >= b
    -- Only defined for values >= 0
    [case(1, NonNil, NonNil)] = function(self, a, b)
        if xor(a >= b and a >= 0 and b >= 0, self.negated) then
          return {{a,b}}
        else
          return Relation.empty
        end
      end,

    [case(2, NonNil, Nil)] = function(self, a, b)
        if a < 0 then return Relation.empty end
        if self.negated then
          return {{a, a+1}}
        else
          return {{a,a}}
        end
      end,

    [case(3, Nil, NonNil)] = function(self, a, b)
        if b < 0 then return Relation.empty end
        if self.negated then
          if b < 1 then return Relation.empty end
          return {{b-1,b}}
        else
          return {{b,b}}
        end
      end,

    default = Relation.some
  },

  ["<"] = defineQueryRelation("<", true) {
    -- Relation: a < b
    -- Only defined for values >= 0
    [case(1, NonNil, NonNil)] = function(self, a, b)
        if xor(a < b and a >= 0 and b >= 0, self.negated) then
          return {{a,b}}
        else
          return Relation.empty
        end
      end,

    [case(2, NonNil, Nil)] = function(self, a, b)
        if a < 0 then return Relation.empty end
        if self.negated then
          return {{a, a}}
        else
          return {{a, a+1}}
        end
      end,

    [case(3, Nil, NonNil)] = function(self, a, b)
        if b < 0 then return Relation.empty end
        if self.negated then
          return {{b,b}}
        else
          if b < 1 then return Relation.empty end
          return {{b-1,b}}
        end
      end,

    default = Relation.some
  }
}

Variable = createClass("Variable")
function Variable:init(name, vartable)
  self.name = name
  self.vartable = vartable
  self.id = #self.vartable.variables+1
  self.vartable.variables[self.id] = {self}
  self.vartable.values[self.id] = nil
  self.vartable.constraints[self.id] = Conjunction.new()
end

function Variable:value()
  return self.vartable.values[self.id]
end

function Variable:isGround()
  return self:value() ~= nil
end

function Variable:bindToValue(value)
  if type(value) == "table" and value.setUsed then value:setUsed(true) end
  if not self:isGround() then
    self.vartable.values[self.id] = value
  else
    assert(Predicand.equalsHelper(self:value(), value))
  end
end

function Variable:bindToVariable(other)
  if self.id == other.id then return end
  local sharedId = math.min(self.id, other.id)
  local removedId = math.max(self.id, other.id)
  local equivClass = self.vartable.variables[sharedId]
  for _,var in ipairs(self.vartable.variables[removedId]) do
    var.id = sharedId
    equivClass[#equivClass+1] = var
  end
  -- self.id has now been updated
  self.vartable.constraints[sharedId]:appendConjunction(self.vartable.constraints[removedId])
  self.vartable.variables[removedId] = nil
  self.vartable.constraints[removedId] = nil
  -- self and other are now part of the same equivalence class
end

function Variable:bind(other)
  if Predicand.isGround(other) then
    self:bindToValue(Predicand.value(other))
  else
    self:bindToVariable(other)
  end
end

function Variable:constraints()
  return self.vartable.constraints[self.id]
end

function Variable:addConstraint(predicate)
  local constraint = Conjunction.new({predicate})
  self:constraints():appendConjunction(constraint)
end

-- If this variable had the given value, would its constraints still hold?
function Variable:checkConstraints(value)
  if not self:constraints():substitute(self, value):satisfiable() then
    return false
  end
  return true
end

function Variable:equals(var)
  return self.id == var.id
end

function Variable:toString()
  local str = "$"..self.name.."#"..tostring(self.id)
  if self:isGround() then
    str = str .. ":" .. tostring(self:value())
  end
  return str
end

Predicand = {}
function Predicand.value(p)
  return match (p) {
      [Variable] = function (var)
          return var:value()
        end,
      default = function (value)
          -- Constant
          return value
        end
    }
end

function Predicand.fromJson(value, symbols, vartable)
  if type(value) == "number" then
    return value
  elseif type(value) == "table" then
    if value.literal then
      return value.literal
    else
      return value
    end
  elseif type(value) == "string" then
    local name = value
    if not symbols[name] then
      symbols[name] = Variable.new(name, vartable)
    end
    return symbols[name]
  else
    error("Cannot parse predicand "..tostring(value))
  end
end

function Predicand.equalsHelper(p, q)
  if p == q then return true end
  if p and type(p) == "table" then
    if p.equals then return p:equals(q) end
    return compare(p,q)
  end
  return false
end

function Predicand.isGround(p)
  return match (p) {
      [Variable] = function ()
          return p:isGround()
        end,
      default = function ()
          return true
        end
    }
end

function Predicand.matches(p, q)
  if Predicand.isGround(p) then
    if Predicand.isGround(q) then
      return Predicand.equalsHelper(Predicand.value(p), Predicand.value(q))
    else
      return false
    end
  else
    if Predicand.isGround(q) then
      return false
    else
      return p:equals(q)
    end
  end
end

function Predicand.unifiable(p, q)
  if Predicand.isGround(p) then
    if Predicand.isGround(q) then
      return Predicand.equalsHelper(Predicand.value(p), Predicand.value(q))
    else
      return q:checkConstraints(p)
    end
  else
    if Predicand.isGround(q) then
      return p:checkConstraints(q)
    else
      return true
    end
  end
end

--Predicand.unifiable = util.wrapFunction(Predicand.unifiable, function (base, p, q)
--    local result = base(p,q)
--    sb.logInfo("unifiable(%s, %s) = %s", tostring(p), tostring(q), result)
--    return result
--  end)

function Predicand.unify(p, q)
  if Predicand.isGround(p) then
    if Predicand.isGround(q) then
      assert(Predicand.equalsHelper(Predicand.value(p), Predicand.value(q)))
    else
      q:bind(p)
    end
  else
    p:bind(q)
  end
end

Conjunction = createClass("Conjunction")
function Conjunction:init(terms)
  self._terms = terms or {}
end

function Conjunction.fromJson(json, symbols, relations, vartable, context)
  local terms = {}
  for _,termJson in ipairs(json) do
    local term = Relation.fromJson(termJson, symbols, relations, vartable, context)
    terms[#terms+1] = term
  end
  return Conjunction.new(terms)
end

function Conjunction:applyConstraints()
  for _,term in ipairs(self._terms) do
    if term:isStatic() then
      term:applyConstraints()
    end
  end
end

function Conjunction:terms()
  return self._terms
end

function Conjunction:isGround()
  for _,term in ipairs(self._terms) do
    if not term:isGround() then
      return false
    end
  end
  return true
end

function Conjunction:toString()
  local termStrs = {}
  for i,term in ipairs(self._terms) do
    termStrs[i] = tostring(term)
  end
  return string.format("Conjunction{%s}", table.concat(termStrs, ", "))
end

function Conjunction:unifiable(otherTerm)
  for _,term in ipairs(self._terms) do
    if otherTerm:unifiable(term) then
      return true
    end
  end
  return false
end

function Conjunction:unify(otherTerm)
  assert(self:unifiable(otherTerm))
  for _,term in ipairs(self._terms) do
    if otherTerm:unifiable(term) then
      otherTerm:unify(term)
      break
    end
  end
end

function Conjunction:test(state)
  for _,term in ipairs(self._terms) do
    if not term:satisfyWithState(state) then
      return false
    end
  end
  return true
end

function Conjunction:containsTerm(otherTerm)
  for _,term in ipairs(self._terms) do
    if term:matches(otherTerm) then
      return true
    end
  end
  return false
end

function Conjunction:withImplications()
  local newConj = Conjunction.new(shallowCopy(self._terms))
  for _,term in ipairs(self._terms) do
    newConj:appendConjunction(term:implications():subtract(newConj))
  end
  return newConj
end

function Conjunction:appendConjunction(conj)
  for _,term in ipairs(conj._terms) do
    self._terms[#self._terms+1] = term
  end
end

function Conjunction:negate()
  return self:map(function (term) return term:negate() end)
end

function Conjunction:map(func)
  return Conjunction.new(util.map(self._terms, func))
end

function Conjunction:filter(func)
  local terms = {}
  for _,term in ipairs(self._terms) do
    if func(term) then
      terms[#terms+1] = term
    end
  end
  return Conjunction.new(terms)
end

function Conjunction:positiveTerms()
  return self:filter(function (term) return not term.negated end)
end

function Conjunction:negativeTerms()
  return self:filter(function (term) return term.negated end)
end

function Conjunction:changeState(addList, deleteList)
  return self:subtract(deleteList):add(addList)
end

function Conjunction:subtract(conj)
  return self:filter(function (term)
      return not conj:containsTerm(term)
    end)
end

function Conjunction:add(conj)
  conj = conj:subtract(self) -- Don't add terms already in self
  local negatives = self:negativeTerms():negate():subtract(conj)
  local result = self:positiveTerms()
  result:appendConjunction(conj)
  result:appendConjunction(negatives:negate())
  return result
end

function Conjunction:substitute(predicand, replacement)
  return self:map(function (term)
      return term:substitute(predicand, replacement)
    end)
end

function Conjunction:satisfiable()
  -- Not an accurate satisfiability check! Constraints are checked properly
  -- when the operations are applied, and we rely on nondeterminism /
  -- randomness to find satisfying assignments (assuming that there aren't so
  -- many constraints on variables that it becomes too unlikely).
  for _,term in ipairs(self._terms) do
    if not term:satisfiable() then
      return false
    end
  end
  return true
end

function Conjunction:satisfyWithState(state)
  for _,term in ipairs(self._terms) do
    if not term:satisfyWithState(state) then
      return false
    end
  end
  return true
end

Operator = createClass("Operator")
function Operator:init(name, operatorConfig)
  self.name = name
  self.preconditions = operatorConfig.preconditions
  self.postconditions = operatorConfig.postconditions
  self.objectives = operatorConfig.objectives
  self.priority = operatorConfig.priority or 0
  self.config = operatorConfig
end

function Operator:relationsProvided()
  local provided = {}
  for _,predicate in ipairs(self.objectives or self.postconditions) do
    provided[predicate[1]] = true
  end
  return provided
end

function Operator:createOperation(planner, symbols)
  symbols = symbols or shallowCopy(planner.constants)
  local precond = Conjunction.fromJson(self.preconditions or {}, symbols, planner.relations, planner.vartable, planner.context)
  local postcond = Conjunction.fromJson(self.postconditions or {}, symbols, planner.relations, planner.vartable, planner.context)
  local objectives = postcond
  if self.objectives then
    objectives = Conjunction.fromJson(self.objectives, symbols, planner.relations, planner.vartable, planner.context)
  end
  return Operation.new(planner, self, symbols, precond, postcond, objectives)
end

OperatorTable = createClass("OperatorTable")
function OperatorTable:init()
  self.operatorsIndex = {}
end

function OperatorTable:addOperator(operator)
  for relation,_ in pairs(operator:relationsProvided()) do
    self.operatorsIndex[relation] = self.operatorsIndex[relation] or {}
    local index = self.operatorsIndex[relation]
    index[#index+1] = operator
  end
end

function OperatorTable:addOperators(json)
  for name, operatorConfig in pairs(json) do
    local operator = Operator.new(name, operatorConfig)
    self:addOperator(operator)
  end
end

function OperatorTable:matchingOperators(term)
  local relation = term.operatorIndex or term.name
  return self.operatorsIndex[relation] or {}
end

Operation = createClass("Operation")
function Operation:init(planner, operator, symbols, precond, postcond, objectives)
  self.planner = planner
  self.operator = operator
  self.name = operator.name
  self.symbols = symbols
  self.config = operator.config
  self.cost = self.config.cost or 1

  self._preconditions = precond:withImplications()
  self._dynamicPreconditions = precond:filter(function (term)
      return not term:isStatic()
    end)
  self._constraints = precond:filter(function (term)
      return term:isStatic()
    end)
  self._postconditions = postcond:withImplications()
  self._deleteList = postcond:negativeTerms():negate()
  self._objectives = objectives

  self._constraints:applyConstraints()
end

function Operation:isGround()
  for key,value in pairs(self.symbols) do
    if not Predicand.isGround(value) then
      self.planner:debugLog("Symbol %s is free var %s", key, tostring(value))
      return false
    end
  end
  return true
end

function Operation:dynamicPreconditions()
  return self._dynamicPreconditions
end

function Operation:preconditions()
  return self._preconditions
end

function Operation:constraints()
  return self._constraints
end

function Operation:postconditions()
  return self._postconditions
end

function Operation:deleteList()
  return self._deleteList
end

function Operation:objectives()
  return self._objectives
end

function Operation:apply(state)
  if not self._preconditions:test(state) then
    return nil
  end
  return state:changeState(self:postconditions(), self:deleteList():withImplications())
end

function Operation:toString()
  return string.format("Operation{%s, precond=%s, postcond=%s}", self.name, tostring(self:preconditions()), tostring(self:postconditions()))
end

Planner = {}
Planner = createClass("Planner")
function Planner:init(maxCost)
  self.debug = true

  self.maxCost = maxCost
  self.relations = {}
  self.operators = OperatorTable.new()
  self.constants = PrintableTable.new()
  self:clearVariables()

  self:addRelations(BuiltinRelations)
end

function Planner:debugLog(...)
  if self.debug then
    local args = {...}
    for i, arg in ipairs(args) do
      args[i] = tostring(arg)
    end
    sb.logInfo(table.unpack(args))
  end
end

function Planner:clearVariables()
  self.vartable = { variables = {}, values = {}, constraints = {} }
end

function Planner:addRelations(relations)
  for _,rel in pairs(relations) do
    self.relations[rel.name] = rel
  end
end

function Planner:setConstants(constants)
  self.constants = PrintableTable.new(constants)
end

function Planner:newVariable(name)
  return Variable.new(name, self.vartable)
end

function Planner:addOperators(json)
  self.operators:addOperators(json)
end

function Planner:parseConjunction(json, symbols)
  symbols = symbols or shallowCopy(self.constants)
  return Conjunction.fromJson(json, symbols, self.relations, self.vartable, self.context)
end

function Planner:tryOperator(term, operator)
  local op = operator:createOperation(self)
  local objectives = op:objectives()
  if objectives:unifiable(term) then
    objectives:unify(term)
    return op
  end
  return nil
end

function Planner:tryOperatorsWeighted(term, operators)
  while #operators ~= 0 do
    local index = util.weightedRandom(util.map(util.tableKeys(operators), function (index)
        return {operators[index].config.chance or 1, index}
      end))
    local operator = table.remove(operators, index)
    local op = self:tryOperator(term, operator)
    if op then return op end
  end
  return nil
end

function Planner:tryOperators(term, operators, weightedChoice)
  if weightedChoice then
    return self:tryOperatorsWeighted(term, operators)
  else
    shuffle(operators)

    for _,operator in ipairs(operators) do
      if not operator.config.chance or math.random() < operator.config.chance then
        local op = self:tryOperator(term, operator)
        if op then return op end
      end
    end
    return nil
  end
end

function Planner:chooseOperation(term)
  local operators = shallowCopy(self.operators:matchingOperators(term))
  table.sort(operators, function (a, b)
      return b.priority < a.priority
    end)

  while #operators ~= 0 do
    local minPriority = operators[#operators].priority
    local priority = operators[1].priority

    local options = util.filter(operators, function (operator)
        return operator.priority == priority
      end)

    local op = self:tryOperators(term, options, priority == minPriority)
    if op then return op end

    operators = util.filter(operators, function (operator)
        return operator.priority < priority
      end)
  end
  return nil
end

function Planner:generateAssignments(state, conjunction)
  -- Assign values to variables in conjunction in a way that (as much as possible)
  -- makes it true, or at least feasible.

  local terms = shuffled(conjunction:terms())
  table.sort(terms, function (a,b)
      return a:freeVariables() < b:freeVariables()
    end)

  local changed = true
  -- Assigning some variables can make it easier to generate examples for
  -- other variables, so we keep trying to generate assignments until we've
  -- been through every term without making any changes.
  while changed do
    changed = false
    for _,term in ipairs(terms) do
      if not term:isGround() then
        if state:unifiable(term) then
          state:unify(term)
        else
          local example = term:generate()
          if example then
            term:unify(example)
            if term:isGround() then
              changed = true
            end
          end
        end
      end
    end
    coroutine.yield()
  end
end

Term = createClass("Term")
function Term:init(predicate)
  self.predicate = predicate
end

GoalStackPlan = createClass("GoalStackPlan")
function GoalStackPlan:init(planner, state, maxCost)
  self.planner = planner
  self.debug = planner.debug
  self.state = state
  self.maxCost = maxCost
  self.goalStack = {}
  self.failure = nil
  self.plan = {}
end

function GoalStackPlan:debugLog(...)
  return self.planner:debugLog(...)
end

function GoalStackPlan:fail(message)
  self.failure = message
  self:debugLog("Quest planning failed: %s", message)
end

function GoalStackPlan:interleaveTerms(conjunction)
  local interleaving = shuffled(conjunction:terms())

  -- Heuristic: push non-static relations first, static relations second.
  -- Reasoning: static relations are applied as constraints anyway, so
  -- they can never be violated by the non-static relations, whereas
  -- the reverse order *could* result in unsatisifable assignments.
  table.sort(interleaving, function (a, b)
      if not a.static and b.static then
        return true
      end

      return (a.priority or 0) < (b.priority or 0)
    end)

  return util.map(interleaving, Term.new)
end

function GoalStackPlan:achieveConjunction(conj)
  -- Push all the terms in conj onto the goal stack.
  -- When all the terms have been achieved, the conjunction is achieved.

  local interleaving = self:interleaveTerms(conj)

  if self.debug then
    for _,term in ipairs(interleaving) do
      self:debugLog("Pushing term %s", term)
    end
  end

  util.appendLists(self.goalStack, interleaving)
end

function GoalStackPlan:achieveTerm(term)
  -- If the term is not already achieved, push an operation onto the goal stack
  -- that would achieve it.

  local predicate = term.predicate
  if predicate:satisfyWithState(self.state) then
    return
  end

  self:debugLog("Term not immediately satisfiable %s", predicate)
  local op = self.planner:chooseOperation(predicate)
  if not op then
    self:fail("No operator to produce "..tostring(predicate))
    return
  end

  coroutine.yield()

  self.planner:generateAssignments(self.state, op:preconditions())

  self:debugLog("Pushing op %s", op)
  table.insert(self.goalStack, op)
  self.maxCost = self.maxCost - op.cost

  coroutine.yield()

  local preconds = op:dynamicPreconditions():withImplications()
  self:debugLog("Pushing preconds %s", preconds)
  table.insert(self.goalStack, preconds)
end

function GoalStackPlan:applyOperation(op)
  self.planner:generateAssignments(self.state, op:preconditions())

  self:debugLog("Applying op %s", op)
  if not op:isGround() then
    self:fail("Operation contains free variables")
    return
  end

  self:debugLog("Old state: %s", self.state)
  local newState = op:apply(self.state)
  if newState == nil then
    -- Op's preconds (a subgoal) were clobbered by another op.
    -- Try to bridge the gap between the current state and the preconds
    -- by generating a subplan taking us from the current state to
    -- the preconds.
    self:debugLog("Generating subplan. Cost allowed: %s", self.maxCost)

    self:achieveGoal(op:dynamicPreconditions():withImplications())
    newState = op:apply(self.state)
    if self.failure or not newState then
      self:fail("Subgoal was clobbered")
      return
    end
  end
  self.state = newState
  self:debugLog("New state: %s", self.state)
  self.plan[#self.plan+1] = op
  self:debugLog("Added op %s to plan", op)
end

function GoalStackPlan:achieveGoal(goal)
  -- Nondeterministic regression planning algorithm, based on STRIPS

  self.planner:generateAssignments(self.state, goal)
  self:debugLog("Pushing goal %s", goal)
  table.insert(self.goalStack, goal)

  while not self.failure and #self.goalStack > 0 do
    coroutine.yield()

    local top = table.remove(self.goalStack)
    self:debugLog("Popped %s", top)

    match (top) {
      [Conjunction] = function () self:achieveConjunction(top) end,
      [Term] = function () self:achieveTerm(top) end,
      [Operation] = function() self:applyOperation(top) end
    }

    if self.maxCost <= 0 then
      self:fail("Plan cost too high")
      break
    end
  end

  if not self.failure and not goal:isGround() then
    self.planner:generateAssignments(self.state, goal)
  end

  if self.failure then
    return nil
  end

  if not self.failure and not goal:test(self.state) then
    -- Subgoal was clobbered. Generate a subplan to bridge the gap between
    -- the current state and the goal state.
    return self:achieveGoal(goal)
  end

  self:debugLog("Successfully generated plan:")
  if self.debug then
    for _,op in ipairs(self.plan) do
      self:debugLog("  %s", op)
    end
  end

  coroutine.yield()

  return self.plan
end

function Planner:generatePlan(initialState, goal, maxCost)
  local stackPlan = GoalStackPlan.new(self, initialState, maxCost or self.maxCost)
  local plan = stackPlan:achieveGoal(goal)
  return plan, stackPlan.state
end
