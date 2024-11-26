require("/scripts/util.lua")

-- NPC relationships are triples consisting of:
--  * The type of relationship,
--  * The first NPC's uniqueId,
--  * The second NPC's uniqueId

-- So for example, (Likes, Bob, Alice) indicates that Bob likes Alice.
-- Alice also has a corresponding, (Likes-converse, Alice, Bob), meaning
-- that she is liked by Bob (but it does not necessarily follow that Alice
-- likes Bob).

-- These relationships are used by the procedural quest system to determine
-- who has offended whom, who has scared whom, who trusts whom, etc.

function getRelationships(relationName, converse)
  storage.relationships = storage.relationships or {}
  storage.relationships[relationName] = storage.relationships[relationName] or { normal = {}, converse = {} }
  local converseKey = "normal"
  if converse then
    converseKey = "converse"
  end

  -- Remove relationships with non-existent npcs
  local relationships = storage.relationships[relationName][converseKey]
  for uniqueId,_ in pairs(relationships) do
    if not world.findUniqueEntity(uniqueId):result() then
      relationships[uniqueId] = nil
    end
  end

  return relationships
end

function hasRelationship(relationName, converse, uniqueId)
  return getRelationships(relationName, converse)[uniqueId] or false
end

function addRelationship(relationName, converse, uniqueId)
  getRelationships(relationName, converse)[uniqueId] = true
end

function removeRelationship(relationName, converse, uniqueId)
  getRelationships(relationName, converse)[uniqueId] = nil
end

function setCriminal(criminal)
  storage.criminal = criminal
end

function isCriminal()
  return storage.criminal or false
end

function getStolenTable()
  storage.stolen = storage.stolen or { items = {}, thieves = {} }
  return storage.stolen
end

function getStolenItems()
  return util.tableKeys(getStolenTable().items)
end

function getThievesForStolenItem(itemName)
  local stolen = getStolenTable()
  if not stolen.items[itemName] then stolen.items[itemName] = {} end
  stolen.items[itemName] = util.filter(stolen.items[itemName], function (uniqueId)
      return world.findUniqueEntity(uniqueId):result() ~= nil
    end)
  return stolen.items[itemName]
end

function getStolenItemsForThief(uniqueId)
  local stolen = getStolenTable()
  if not stolen.thieves[uniqueId] then stolen.thieves[uniqueId] = {} end
  return stolen.thieves[uniqueId]
end

function setStolen(thiefUniqueId, itemName)
  table.insert(getThievesForStolenItem(itemName), thiefUniqueId)
  table.insert(getStolenItemsForThief(thiefUniqueId), itemName)
end

function unsetStolen(thiefUniqueId, itemName)
  local thieves = getThievesForStolenItem(itemName)
  local thiefIndex = contains(thieves, thiefUniqueId)
  if thiefIndex then
    table.remove(thieves, thiefIndex)
  end

  local items = getStolenItemsForThief(thiefUniqueId)
  local itemIndex = contains(items, itemName)
  if itemIndex then
    table.remove(items, itemIndex)
  end
end

function isStolen(thiefUniqueId, itemName)
  return contains(getThievesForStolenItem(itemName), thiefUniqueId)
end
