local function itemName(item)
  if type(item) == "table" then
    assert(item.name ~= nil)
    return item.name
  end
  assert(type(item) == "string")
  return item
end

--param item
function itemIsObject(args, board)
  if args.item == nil then return false end
  return root.itemType(itemName(args.item)) == "object"
end

--param item
--param tag
function itemHasObjectTag(args, output)
  if args.item == nil then return false end
  return contains(root.itemConfig(itemName(args.item)).config.tags or {}, args.tag)
end
