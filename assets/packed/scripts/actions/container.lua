-- param entity
-- param itemName
-- param amount
-- param parameters
function containerAddItem(args, board)
  if args.itemName == nil or args.entity == nil then return false end

  if world.containerAddItems(args.entity, {name = args.itemName, amount = args.amount, parameters = args.parameters}) then
    return true
  else
    return false
  end
end
