-- param type
function receivedNotification(args, board)
  if args.type == nil then return false end

  for i,notification in pairs(self.notifications) do
    if notification.type == args.type then
      table.remove(self.notifications, i)
      return true, {source = notification.sourceId, target = notification.targetId, targetPosition = notification.targetPosition}
    end
  end
  return false
end

-- param type
-- param entity
-- param target
function sendNotification(args, board)
  if args.entity == nil or args.type == nil then return false end

  local notification = {
    sourceId = entity.id(),
    targetId = args.target,
    type = args.type
  }
  world.callScriptedEntity(args.entity, "notify", notification)
  return true
end

-- param type
-- param position
-- param range
-- param entityTypes
-- param target
function broadcastNotification(args, board)
  if args.type == nil or args.position == nil or args.range == nil then return false end

  local notification = {
    sourceId = entity.id(),
    targetId = args.target,
    type = args.type
  }
  local notified = world.entityQuery(args.position, args.range, { includedTypes = args.entityTypes, callScript = "notify", callScriptArgs = {notification} })
  if #notified > 0 then
    return true
  else
    return false
  end
end
