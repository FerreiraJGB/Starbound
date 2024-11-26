--- A very basic state machine implementation for monsters
--
-- States are implemented with two functions:
--
--   state.enter() / state.enterWith(args)
--      Attempts to enter the state, returning state data (i.e. not nil) that
--      will be available to the state while it is running if the state could
--      be entered.
--
--      A single state need only implement one of these (enter/enterWith) - if
--      args are passed to pickState, enterWith will be called instead of enter,
--      in which case only states that implement enterWith will be called.
--
--      If returning nil (i.e. don't enter state), can also return a second
--      value that will be used as a cooldown time before the state will be
--      considered again.
--
--   state.update(dt, stateData)
--      The update function of the state, which will be called with two
--      arguments: deltaTime and the state data returned from stateStart.
--      When this function returns true, the state will be ended. When
--      returning true, can also optionally return a second value that
--      will be used as a cooldown time, which must elapse before the
--      state can be entered again.
--
-- States can optionally define the following functions:
--
--   state.description()
--      Returns a string used to describe the current state of the state when
--      stateMachine.stateDesc is called. The state name will be used if this
--      function is not provided
--
--   state.enteringState(stateData)
--      Called when the state is being entered, after state.enter has been
--      called, but also after the previous state's (if there was one) leaving
--      callback has been called, after the global leavingState callback has
--      been called, and after the global enteringState callback has been
--      called Note that this may be called on the update prior to the first
--      call to state.update, or on the same update as the first call to
--      state.update (depending on whether there was a previous state).
--
--    state.leavingState(stateData)
--      Called immediately before leaving the state - _before_ the global
--      leavingState callback is called.
--
--    state.preventStateChange(stateData)
--      Called when pickState is called - if a state implements this method and
--      it returns false, the only way to exit the state will be for the state's
--      update function to return true.
--
-- Some configuration options are provided:
--
--    stateMachine.autoPickState (default = true)
--      Set to false to prevent a new state from being chosen automatically when
--      there is no active state
--
--    stateMachine.enteringState (default = nil)
--      Set to a function that will be called with the new state name
--      immediately before changing to a new state
--
--    stateMachine.leavingState (default = nil)
--      Set to a function that will be called with the current state name
--      immediately before exiting the state
--
-- The following functions are exposed:
--
--    stateMachine.hasState()
--      Returns true if a state is currently selected
--
--    stateMachine.stateDesc()
--      Gets the .description() of the current state
--
--    stateMachine.shuffleStates()
--      Randomly shuffles the order of the states, so their enter functions are
--      called in a different order the next time a new state is picked
--
--    stateMachine.moveStateToEnd(stateName)
--      Moves the given state to the end of the list of states, so it is
--      the last state considered next time a new state is picked. Note that if
--      a state shows up multiple times in the list of states (which is valid),
--      only the first instance of the state will be moved to the end
--
--    stateMachine.pickState() / stateMachine.pickState(params)
--      Immediately switch to the first state where the state.enter function
--      returns non-nil. If params are given, only state.enterWith functions
--      will be called.
--      Returns true if a new state was entered.
--
--    stateMachine.endState() / stateMachine.endState(cooldown)
--      End the current state immediately, optionally applying the given
--      cooldown time (in seconds) before its state.enter function can be
--      called again.
--
--    stateMachine.update(dt)
--      Update the current state, pick new states, etc
--
--
stateMachine = {}

---
-- @param availableStates
--  List of string state names
--
-- @param stateTables
--  (optional) If this table is present and contains a state name as a key,
--  that value will be used as the implementation of the state, instead of
--  the entry in the global table. This can be useful if a state is defined
--  dynamically at a point in execution when it can't be added to the global
--  table (e.g. in an init() function, you can add to the global table all you
--  want, but your changes will not be persisted through to the first call to
--  the update(dt) function)
--
function stateMachine.create(availableStates, stateTables)
  local self = {}

  local stateName = nil
  local stateData = nil
  local stateNames = availableStates
  local cooldownTimers = {}

  local getStateTable = function(stateName)
    if stateTables ~= nil then
      local state = stateTables[stateName]
      if state ~= nil then
        return state
      end
    end

    return _ENV[stateName]
  end

  local updateCurrentState = function(dt)
    if stateName ~= nil then
      local originalStateName = stateName
      local state = getStateTable(stateName)

      local stateDone, cooldownTime = state.update(dt, stateData)
      if stateDone and stateName == originalStateName then
        self.endState(cooldownTime)
      end

      return true
    else
      return false
    end
  end

  self.autoPickState = true
  self.enteringState = nil
  self.leavingState = nil

  function self.hasState()
    if stateName ~= nil then
      return true
    else
      return false
    end
  end

  function self.shuffleStates()
    math.randomseed(math.floor((os.time() + (os.clock() % 1)) * 1000))
    local iterations = #stateNames
    local j
    for i = iterations, 2, -1 do
      j = math.random(i)
      stateNames[i], stateNames[j] = stateNames[j], stateNames[i]
    end
  end

  function self.moveStateToEnd(stateToMove)
    for i, stateName in ipairs(stateNames) do
      if stateName == stateToMove then
        table.insert(stateNames, table.remove(stateNames, i))
        return
      end
    end
  end

  function self.pickState(params)
    if stateName ~= nil then
      local state = getStateTable(stateName)
      if state.preventStateChange ~= nil and state.preventStateChange(stateData) then
        return false
      end
    end

    local enterFunctionName = "enter"
    if params ~= nil then enterFunctionName = "enterWith" end

    for i, newStateName in ipairs(stateNames) do
      if cooldownTimers[newStateName] == nil then
        local newState = getStateTable(newStateName)
        local enterFunction = newState[enterFunctionName]
        if enterFunction ~= nil then
          local newStateData, cooldown = enterFunction(params)
          if newStateData ~= nil then
            self.endState()

            if self.enteringState ~= nil then
              self.enteringState(newStateName)
            end

            if newState.enteringState ~= nil then
              newState.enteringState(newStateData)
            end

            stateName = newStateName
            stateData = newStateData
            return true
          elseif cooldown ~= nil then
            cooldownTimers[newStateName] = cooldownTime
          end
        end
      end
    end

    return false
  end

  function self.endState(cooldownTime)
    if stateName == nil then return end

    local stateNameWas = stateName
    local stateDataWas = stateData

    cooldownTimers[stateName] = cooldownTime

    -- Clear state now, in case leavingState calls pickState
    stateName = nil
    stateData = nil

    local state = getStateTable(stateNameWas)
    if state.leavingState ~= nil then
      state.leavingState(stateDataWas)
    end

    if self.leavingState ~= nil then
      self.leavingState(stateNameWas)
    end
  end

  function self.stateDesc()
    if stateName ~= nil then
      local state = getStateTable(stateName)
      if state.description ~= nil then
        return state.description()
      else
        return stateName
      end
    end

    return ""
  end

  function self.stateCooldown(stateName, newCooldown)
    if stateName ~= nil and type(newCooldown) == "number" then
      cooldownTimers[stateName] = newCooldown
    elseif stateName ~= nil and cooldownTimers[stateName] and cooldownTimers[stateName] > 0 then
      return cooldownTimers[stateName]
    else
      return 0
    end
  end

  -- Returns true if a state was updated during this call
  function self.update(dt)
    -- Update current state
    local updatedState = updateCurrentState(dt)

    -- Try and find a new state
    if stateName == nil and self.autoPickState then
      self.pickState()

      if not updatedState then
        updatedState = updateCurrentState(dt)
      end
    end

    -- Tick per-state cooldown timers
    for cooldownState, cooldownTimer in pairs(cooldownTimers) do
      cooldownTimer = cooldownTimer - dt
      if cooldownTimer < 0.0 then
        cooldownTimer = nil
      end
      cooldownTimers[cooldownState] = cooldownTimer
    end

    if not updatedState and stateName == nil then
      return false
    else
      return true
    end
  end

  return self
end

--- Scans the given lua script paths for the given pattern, which should capture
--- a state name from the name of the script
-- Example: stateMachine.scanScripts(config.getParameter("scripts"), "(%a+)State%.lua")
function stateMachine.scanScripts(scripts, pattern)
  local stateNames = {}

  if scripts ~= nil then
    for i, subScript in ipairs(scripts) do
      local stateName = string.match(subScript, pattern)
      if stateName ~= nil then
        local state = _ENV[stateName]
        if state ~= nil and type(state) == "table" and (state["enter"] ~= nil or state["enterWith"] ~= nil) and state["update"] ~= nil then
          table.insert(stateNames, stateName)
        end
      end
    end
  end

  return stateNames
end
