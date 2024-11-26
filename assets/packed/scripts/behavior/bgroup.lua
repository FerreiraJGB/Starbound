-----------------------------------------------------------
-- BEHAVIOR GROUPS
-----------------------------------------------------------

BGroup = {
  groups = {},
  joinedGroups = {},
  tasks = {},
  joinedTasks = {}
}

function BGroup.findGroupPosition(goalType, goal)
  if goalType == "entity" then
    return world.entityPosition(goal)
  elseif goalType == "position" then
    return goal
  elseif goalType == "list" then
    local sum = {0, 0}
    for _,entityId in pairs(goal) do
      sum = vec2.add(sum, world.entityPosition(entityId))
    end
    return vec2.div(sum, #goal)
  end
end

function BGroup:joinGroup(group, position, unique)
  if self.groups[group.groupId] then
    if world.entityExists(self.groups[group.groupId]) then
      return self:requestJoinGroup(self.groups[group.groupId], group.groupId, group.goalType, group.goal)
    else
      self.groups[group.groupId] = nil
    end
  end
  position = position or BGroup.findGroupPosition(group.goalType, group.goal)

  -- Query existing coordinators
  local stagehands = world.entityQuery(position, 10, {includedTypes = {"stagehand"}})

  -- Filter out ones that don't have the same goal
  stagehands = util.filter(stagehands, function(stagehandId)
    return world.callScriptedEntity(stagehandId, "compareGoals", group.goalType, group.goal)
  end)

  -- Try to join any of the remaining ones
  for k,stagehandId in ipairs(stagehands) do
    if world.stagehandType(stagehandId) == "coordinator" then
      local result = self:requestJoinGroup(stagehandId, group.groupId, group.goalType, group.goal)
      if result == true then
        self.groups[group.groupId] = stagehandId
      end
      -- Return if the coordinator was successfully joined, or if the group is set to be unique
      if result or unique then return result end
    end
  end

  -- There was no existing stagehand with empty space
  local stagehandId = world.spawnStagehand(position, "coordinator", group)
  return self:requestJoinGroup(stagehandId, group.groupId, group.goalType, group.goal)
end

function BGroup:requestJoinGroup(entityId, groupId, goalType, goal)
  self.joinedGroups = self.joinedGroups or {}
  local result = world.callScriptedEntity(entityId, "onRequestJoin", entity.id(), goalType, goal)
  if result then
    self.joinedGroups[groupId] = entityId
    if result == true then
      self.groups[groupId] = entityId
    end
  end
  return result
end

function BGroup:leaveGroup(groupId)
  local coordinator = self:groupCoordinator(groupId)
  if coordinator then
    --sb.logInfo("%s left group %s", entity.id(), groupId)
    world.callScriptedEntity(coordinator, "onLeaveGroup", entity.id())
  end
end

function BGroup:updateGroups()
  --Leave any tasks not joined this update
  for taskId,task in pairs(self.tasks) do
    if not self.joinedTasks[taskId] then
      self:leaveTask(task.groupId, task.taskId)
    end
  end
  self.tasks = self.joinedTasks
  self.joinedTasks = {}

  --Leave any groups not joined this update
  for groupId,entityId in pairs(self.groups) do
    if self.joinedGroups[groupId] == nil or self.joinedGroups[groupId] ~= entityId then
      BGroup:leaveGroup(groupId)
    end
  end
  self.groups = self.joinedGroups
  self.joinedGroups = {}
end

function BGroup:joinTask(groupId, task)
  self.joinedTasks = self.joinedTasks or {}
  local coordinator = self:groupCoordinator(groupId)
  if coordinator then
    local result = world.callScriptedEntity(coordinator, "onRequestTask", entity.id(), task)
    if result then
      self.joinedTasks[groupId.."."..task.taskId] = {groupId = groupId, taskId = task.taskId}
    end
    return result
  end
end

function BGroup:leaveTask(groupId, taskId)
  local coordinator = self:groupCoordinator(groupId)
  if coordinator then
    return world.callScriptedEntity(coordinator, "onLeaveTask", entity.id(), taskId)
  end
end

function BGroup:getResource(groupId, resource)
  local coordinator = self:groupCoordinator(groupId)
  if coordinator then
    return world.callScriptedEntity(coordinator, "onGetResource", entity.id(), resource)
  end
end

function BGroup:setGroupSuccess(groupId, taskId)
  local coordinator = self:groupCoordinator(groupId)
  if coordinator then
    return world.callScriptedEntity(coordinator, "setSuccess", entity.id())
  end
end

function BGroup:groupCoordinator(groupId)
  if self.groups[groupId] and world.entityExists(self.groups[groupId]) then
    return self.groups[groupId]
  else
    return false
  end
end

function BGroup:uninit()
  self.joined = {}
  self.joinedTasks = {}
  self:updateGroups()
end

-- Actions --

-- Group
-- Share a goal with nearby entities with the same goal
-- Keeps running until entity is no longer in the group
function group(args, board)
  local groupId = args.groupId
  local goal = board:get(args.goalType, args.goal)
  if groupId == nil and args.goalType == "list" then
    groupId = "list-"
    for _,v in pairs(goal) do
      groupId = string.format("%s-%s", groupId, v)
    end
  end

  local group = {
    groupId = groupId,
    goalType = args.goalType,
    minMembers = args.minMembers,
    maxMembers = args.maxMembers,
    behavior = args.behavior
  }

  group.goal = goal
  if group.goal == nil then
    return false
  end

  local groupResult = BGroup:joinGroup(group, args.position, args.unique)
  if groupResult == "success" then
    BGroup:leaveGroup(group.groupId)
    return true, {groupId = group.groupId}
  end

  return groupResult == true, {groupId = group.groupId}
end

-- param groupId
function succeedGroup(args, board)
  BGroup:setGroupSuccess(args.groupId)
  return true
end

-- param groupId
-- param taskId
-- param minMembers
-- param maxMembers
function task(args, board)
  local task = {
    taskId = args.taskId,
    minMembers = args.minMembers,
    maxMembers = args.maxMembers
  }
  return BGroup:joinTask(args.groupId, task)
end
