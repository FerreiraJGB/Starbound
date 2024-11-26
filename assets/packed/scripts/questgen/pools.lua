require "/scripts/set.lua"

PoolRelations = {}

local Item = QuestPredicands.Item
local ItemTag = QuestPredicands.ItemTag
local ItemList = QuestPredicands.ItemList
local NpcType = QuestPredicands.NpcType
local MonsterType = QuestPredicands.MonsterType
local TagSet = QuestPredicands.TagSet

local PoolElementTypes = {}
-- Pools can contain many different types - items, strings, lists of items,
-- npctypes, etc. These 'PoolElementTypes' tell the pool relations how to
-- read elements from the Json definitions, how to index them for fast searches,
-- and how to match predicands against them.
PoolElementTypes.Base = createClass("PoolElementTypes.Base")
-- The matcher is the expression used to match ground (non-free) predicands.
-- It can be the metatable of the predicand type or Nil, NonNil, Any.
PoolElementTypes.Base.matcher = NonNil
-- indexKey returns a value that can be used to narrow the search for the value.
-- Like a hash, this should be the same for other values that are equal, but
-- it doesn't have to uniquely identify the value.
function PoolElementTypes.Base:indexKey(value)
  return value
end
-- Constructs a new value from its json representation in the pool file.
function PoolElementTypes.Base:fromJson(json)
  return json
end

PoolElementTypes.String = subclass(PoolElementTypes.Base, "PoolElementTypes.String")

PoolElementTypes.Item = subclass(PoolElementTypes.Base, "PoolElementTypes.Item")
PoolElementTypes.Item.matcher = Item

function PoolElementTypes.Item:indexKey(item)
  return item.itemName
end

function PoolElementTypes.Item:fromJson(json)
  return Item.new(json)
end

PoolElementTypes.ItemTag = subclass(PoolElementTypes.Base, "PoolElementTypes.ItemTag")
PoolElementTypes.ItemTag.matcher = ItemTag

function PoolElementTypes.ItemTag:indexKey(itemTag)
  return itemTag.tag
end

function PoolElementTypes.ItemTag:fromJson(json)
  return ItemTag.fromJson(json)
end

PoolElementTypes.ItemList = subclass(PoolElementTypes.ItemList, "PoolElementTypes.ItemList")
PoolElementTypes.ItemList.matcher = ItemList

function PoolElementTypes.ItemList:indexKey(itemList)
  -- Generating the index key is O(N logN) in the length of the itemList.
  -- If we didn't generate an index key this way, the complexity of performing
  -- a search in the pool would be O(M N) where M is the number of lists.
  -- Thus, the complexity of this function is justified when there are more
  -- lists in the pool than items in the list, which is expected to be the
  -- usual case.
  local nameCounts = {}
  local names = {}
  for _,descriptor in pairs(itemList:descriptors()) do
    nameCounts[descriptor.name] = descriptor.count or 1
    names[#names+1] = descriptor.name
  end
  local key = ""
  table.sort(names)
  for _,name in ipairs(names) do
    key = key .. name .. nameCounts[name]
  end
  return key
end

function PoolElementTypes.ItemList:fromJson(json)
  return ItemList.fromJson(json)
end

PoolElementTypes.NpcType = subclass(PoolElementTypes.NpcType, "PoolElementTypes.NpcType")
PoolElementTypes.NpcType.matcher = NpcType

function PoolElementTypes.NpcType:indexKey(npcType)
  return npcType.species .. npcType.typeName
end

function PoolElementTypes.NpcType:fromJson(json)
  return NpcType.new(json)
end

PoolElementTypes.MonsterType = subclass(PoolElementTypes.MonsterType, "PoolElementTypes.MonsterType")
PoolElementTypes.MonsterType.matcher = MonsterType

function PoolElementTypes.MonsterType:indexKey(monsterType)
  return monsterType.typeName
end

function PoolElementTypes.MonsterType:fromJson(json)
  return MonsterType.new(json)
end

PoolElementTypes.TagSet = subclass(PoolElementTypes.TagSet, "PoolElementTypes.TagSet")
PoolElementTypes.TagSet.matcher = TagSet

function PoolElementTypes.TagSet:indexKey(tagSet)
  local values = set.values(tagSet.tags)
  table.sort(values)
  return table.concat(values)
end

function PoolElementTypes.TagSet:fromJson(json)
  return TagSet.new(json)
end

local Index = createClass("Index")
function Index:init(elementType)
  self.elementType = elementType
  self.index = {}
end

function Index:put(key, record)
  local indexKey = self.elementType:indexKey(key)
  self.index[indexKey] = self.index[indexKey] or {}
  local entries = self.index[indexKey]
  entries[#entries+1] = {
      key = key,
      record = record
    }
end

function Index:get(key)
  local indexKey = self.elementType:indexKey(key)
  local entries = self.index[indexKey] or {}
  local results = {}
  for _,entry in pairs(entries) do
    if Predicand.equalsHelper(entry.key, key) then
      results[#results+1] = entry.record
    end
  end
  return results
end

local function sameRecord(a, b)
  if #a ~= #b then return false end
  for i,field in ipairs(a) do
    if not Predicand.equalsHelper(b[i], field) then
      return false
    end
  end
  return true
end

function Index:contains(key, searchRecord)
  for _,record in pairs(self:get(key)) do
    if sameRecord(record, searchRecord) then
      return true
    end
  end
  return false
end

function Index:list()
  local list = {}
  for _,entries in pairs(self.index) do
    for _,entry in pairs(entries) do
      list[#list+1] = entry.record
    end
  end
  return list
end

local pools = {}

local function loadPool(path, ...)
  if pools[path] then return pools[path] end
  local columns = {...}

  local pool = {}
  for _,column in ipairs(columns) do
    pool[#pool+1] = Index.new(column)
  end
  pools[path] = pool

  for _,levelSection in pairs(root.assetJson(path)) do
    if levelSection[1] <= world.threatLevel() then
      for _,row in pairs(levelSection[2]) do
        if #columns == 1 then row = {row} end

        for i,fieldJson in ipairs(row) do
          row[i] = columns[i]:fromJson(fieldJson)
        end

        for i,field in ipairs(row) do
          pool[i]:put(field, row)
        end
      end
    end
  end

  return pool
end

PoolRelations.UnaryPool = defineSubclass(Relation, "UnaryPool") {
  -- Defined in pools.config:
  type = nil,
  poolFile = nil,
  
  elementType = function (self)
      local result = PoolElementTypes[self.type]
      assert(result ~= nil)
      return result
    end,

  index = function (self)
      return loadPool(self.poolFile, self:elementType())[1]
    end,

  query = function (self)
      return self:unpackPredicands {
        [case(1, self:elementType().matcher)] = function (self, element)
            if xor(self.negated, #self:index():get(element) > 0) then
              return {{element}}
            end
            return Relation.empty
          end,

        [case(2, Nil)] = function (self)
            if self.negated then return Relation.some end
            return self:index():list()
          end,

        default = Relation.empty
      }
    end
}

PoolRelations.BinaryPool = defineSubclass(Relation, "BinaryPool") {
  -- Defined in pools.config:
  types = nil,
  poolFile = nil,

  elementType = function (self, i)
      local result = PoolElementTypes[self.types[i]]
      assert(result ~= nil)
      return result
    end,

  index = function (self, i)
      return loadPool(self.poolFile, self:elementType(1), self:elementType(2))[i]
    end,

  query = function (self)
      return self:unpackPredicands {
        [case(1, self:elementType(1).matcher, self:elementType(2).matcher)] = function (self, left, right)
            if xor(self.negated, self:index(1):contains(left, {left, right})) then
              return {{left, right}}
            end
            return Relation.empty
          end,

        [case(2, self:elementType(1).matcher, Nil)] = function (self, left)
            return self:index(1):get(left)
          end,

        [case(3, Nil, self:elementType(2).matcher)] = function (self, _, right)
            return self:index(2):get(right)
          end,
        
        [case(4, Nil, Nil)] = function (self)
            return self:index(1):list()
          end,

        default = Relation.empty
      }
    end,
}
