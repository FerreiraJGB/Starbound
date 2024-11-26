require "/scripts/util.lua"

local function isVersioned(v)
  return v.__version or v.version
end

local function loadItem(item)
  if not isVersioned(item) then
    item = {
        id = "Item",
        version = 7,
        content = item
      }
  end
  return root.loadVersionedJson(item, "Item")
end

local function storeItem(item)
  return root.makeCurrentVersionedJson("Item", item)
end

local function loadQuestParameter(paramValue)
  if paramValue.type == "item" then
    paramValue.item = loadItem(paramValue.item)
  elseif paramValue.type == "itemList" then
    paramValue.items = util.map(paramValue.items, loadItem, jarray())
  end
  return paramValue
end

local function storeQuestParameter(paramValue)
  if paramValue.type == "item" then
    paramValue.item = storeItem(paramValue.item)
  elseif paramValue.type == "itemList" then
    paramValue.items = util.map(paramValue.items, storeItem, jarray())
  end
  return paramValue
end

local function loadQuestParameters(parameters)
  for paramName, paramValue in pairs(parameters) do
    parameters[paramName] = loadQuestParameter(paramValue)
  end
  return parameters
end

local function storeQuestParameters(parameters)
  for paramName, paramValue in pairs(parameters) do
    parameters[paramName] = storeQuestParameter(paramValue)
  end
  return parameters
end

function loadQuestDescriptor(versionedJson)
  if not isVersioned(versionedJson) then
    versionedJson = {
        id = "QuestDescriptor",
        version = 1,
        content = versionedJson
      }
  end
  local questDesc = root.loadVersionedJson(versionedJson, "QuestDescriptor")
  questDesc.parameters = loadQuestParameters(questDesc.parameters)
  return questDesc
end

function storeQuestDescriptor(questDesc)
  local questDesc = copy(questDesc)
  questDesc.parameters = storeQuestParameters(questDesc.parameters or {})
  return root.makeCurrentVersionedJson("QuestDescriptor", questDesc)
end

function loadQuestArcDescriptor(versionedJson)
  if not isVersioned(versionedJson) then
    versionedJson = {
        id = "QuestArcDescriptor",
        version = 1,
        content = versionedJson
      }
  end
  local questArc = root.loadVersionedJson(versionedJson, "QuestArcDescriptor")
  for i,questDesc in pairs(questArc.quests) do
    questArc.quests[i] = loadQuestDescriptor(questDesc)
  end
  return questArc
end

function storeQuestArcDescriptor(questArc)
  local questArc = copy(questArc)
  for i,questDesc in pairs(questArc.quests) do
    questArc.quests[i] = storeQuestDescriptor(questDesc)
  end
  return root.makeCurrentVersionedJson("QuestArcDescriptor", questArc)
end
