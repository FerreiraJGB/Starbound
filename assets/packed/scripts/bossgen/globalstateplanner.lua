require "/scripts/questgen/util.lua"
require "/scripts/questgen/planner.lua"

StateOperator = defineSubclass(Operator, "StateOperator")()
function StateOperator:init(name, operatorConfig)
  Operator.init(self, name, operatorConfig)
  self.statemodifiers = operatorConfig.statemodifiers or {}
end

function StateOperator:relationsProvided()
  local provided = {}
  local postconditions = copy(self.postconditions)
  util.appendLists(postconditions, self.statemodifiers)
  for _,predicate in ipairs(self.objectives or postconditions) do
    provided[predicate[1]] = true
  end
  return provided
end

function StateOperator:createOperation(planner, symbols)
  symbols = symbols or shallowCopy(planner.constants)
  local precond = Conjunction.fromJson(self.preconditions or {}, symbols, planner.relations, planner.vartable, planner.context)
  local postcond = Conjunction.fromJson(self.postconditions or {}, symbols, planner.relations, planner.vartable, planner.context)
  local statemods = Conjunction.fromJson(self.statemodifiers or {}, symbols, planner.relations, planner.vartable, planner.context)
  local objectives
  if self.objectives then
    objectives = Conjunction.fromJson(self.objectives, symbols, planner.relations, planner.vartable, planner.context)
  else
    objectives = Conjunction.new(postcond._terms)
    objectives:appendConjunction(statemods)
  end
  return StateOperation.new(planner, self, symbols, precond, postcond, statemods, objectives)
end

StateOperation = defineSubclass(Operation, "StateOperation")()
function StateOperation:init(planner, operator, symbols, precond, postcond, statemods, objectives)
  Operation.init(self, planner, operator, symbols, precond, postcond, objectives)
  self._statemodifiers = statemods:withImplications()
end

function StateOperation:statemodifiers()
  return self._statemodifiers
end

function StateOperation:toString()
  return string.format("Operation{%s, precond=%s, postcond=%s, statemods=%s}", self.name, tostring(self:preconditions()), tostring(self:postconditions()), tostring(self:statemodifiers()))
end

StateOperatorTable = defineSubclass(OperatorTable, "StateOperatorTable")()
function StateOperatorTable:addOperators(json)
  for name, operatorConfig in pairs(json) do
    local operator = StateOperator.new(name, operatorConfig)
    self:addOperator(operator)
  end
end

GlobalStatePlanner = defineSubclass(Planner, "GlobalStatePlanner")()
function GlobalStatePlanner:init(maxCost)
  Planner.init(self, maxCost)
  self.operators = StateOperatorTable.new()
end

function GlobalStatePlanner:chooseOperation(term, globalState)
  local operators = shallowCopy(self.operators:matchingOperators(term))
  table.sort(operators, function (a, b)
      return b.priority < a.priority
    end)

  while #operators ~= 0 do
    local minPriority = operators[#operators].priority
    local priority = operators[1].priority

    local options = util.filter(operators, function (operator)
        local op = operator:createOperation(self)
        -- conditions in the global state must not be negated
        -- preconditions negated by the global state can never be satisfied
        for _,conj in pairs({op:preconditions(), op:postconditions(), op:statemodifiers()}) do
          for _,term in pairs(conj:terms()) do
            if globalState:containsTerm(term:negate()) or term:contradicts(globalState) then
              return false
            end
          end
        end

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
function GlobalStatePlanner:generatePlan(initialState, goal, globalState, maxCost)
  local stackPlan = StateGoalStackPlan.new(self, initialState, globalState, maxCost or self.maxCost)
  local plan = stackPlan:achieveGoal(goal)
  return plan, stackPlan.state, stackPlan.globalState
end

StateGoalStackPlan = defineSubclass(GoalStackPlan, "StateGoalStackPlan")()
function StateGoalStackPlan:init(planner, state, globalState, maxCost)
  GoalStackPlan.init(self, planner, state, maxCost)
  self.globalState = globalState
end

function StateGoalStackPlan:achieveTerm(term)
  -- If the term is not already achieved, push an operation onto the goal stack
  -- that would achieve it.

  local predicate = term.predicate
  if predicate:satisfyWithState(self.state) then
    return
  end

  self:debugLog("Term not immediately satisfiable %s", predicate)
  local op = self.planner:chooseOperation(predicate, self.globalState)
  if not op then
    self:fail("No operator to produce "..tostring(predicate))
    return
  end

  coroutine.yield()

  self.planner:generateAssignments(self.state, op:preconditions())

  self:debugLog("Pushing op %s", op)
  self.globalState = self.globalState:changeState(op:statemodifiers(), Conjunction.new({}))
  self.state = self.state:changeState(op:statemodifiers(), Conjunction.new({}))

  local preconditions = op:preconditions():subtract(op:statemodifiers():negate())
  op = StateOperation.new(self, op.operator, op.symbols, preconditions, op._postconditions, op._statemodifiers, op._objectives)

  table.insert(self.goalStack, op)

  self.maxCost = self.maxCost - op.cost

  coroutine.yield()

  -- remove negated operation state modifiers from its preconditions
  -- to keep it from conflicting with itself

  local preconds = op:dynamicPreconditions():withImplications()
  self:debugLog("Pushing preconds %s", preconds)
  table.insert(self.goalStack, preconds)
end

function StateGoalStackPlan:achieveGoal(goal)
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
      [StateOperation] = function() self:applyOperation(top) end
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
    self:debugLog("Subgoal was clobbered. Generate a subplan to bridge the gap between the current state and the goal state.")
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
