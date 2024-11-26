require("/scripts/util.lua")
require("/scripts/questgen/util.lua")

QuestPlugin = createClass("QuestPlugin")

function QuestPlugin:init(questManager, storageArea, questId, pluginConfig)
  self.questManager = questManager
  self.questId = questId
  self.questDescriptor = questManager:questDescriptor(questId)
  self.templateId = self.questDescriptor.templateId
  self.questParameters = self.questDescriptor.parameters
  self.config = pluginConfig
  self.data = storageArea
end

function QuestPlugin:update()
end

function QuestPlugin:questStarted()
end

function QuestPlugin:questFinished()
end

function QuestPlugin:playerStarted(player)
end

function QuestPlugin:playerFailed(player)
  self:playerFinished(player)
end

function QuestPlugin:playerCompleted(player)
  self:playerFinished(player)
end

function QuestPlugin:playerFinished(player)
end

function QuestPlugin:participantDied(participant, respawner)
end

QuestPluginManager = createClass("QuestPluginManager")

function QuestPluginManager:init(questManager, storageArea, config)
  self.questManager = questManager
  self.storage = storageArea
  self.plugins = {}

  for questId, plugins in pairs(config) do
    for i,plugin in pairs(plugins) do
      self:loadPlugin(questId, i, plugin.script, plugin.pluginClass, plugin.pluginConfig or {})
    end
  end
end

function QuestPluginManager:loadPlugin(questId, pluginIndex, script, className, scriptConfig)
  require(script)
  local class = _ENV[className]

  self.storage[questId] = self.storage[questId] or {}
  self.storage[questId][pluginIndex] = self.storage[questId][pluginIndex] or {}
  local pluginStorage = self.storage[questId][pluginIndex]

  local plugin = class.new(self.questManager, pluginStorage, questId, scriptConfig)
  self.plugins[questId] = self.plugins[questId] or {}
  self.plugins[questId][pluginIndex] = plugin
end

function QuestPluginManager:update()
  for _,plugins in pairs(self.plugins) do
    for _,plugin in pairs(plugins) do
      plugin:update()
    end
  end
end

local function broadcastPluginCall(pluginMethod)
  return function (pluginManager, ...)
      for _,plugins in pairs(pluginManager.plugins) do
        for _,plugin in pairs(plugins) do
          plugin[pluginMethod](plugin, ...)
        end
      end
    end
end

local function filteredPluginCall(pluginMethod)
  return function (pluginManager, questId, ...)
      for _,plugin in pairs(pluginManager.plugins[questId] or {}) do
        plugin[pluginMethod](plugin, ...)
      end
    end
end

QuestPluginManager.update = broadcastPluginCall("update")
QuestPluginManager.questStarted = filteredPluginCall("questStarted")
QuestPluginManager.questFinished = filteredPluginCall("questFinished")
QuestPluginManager.playerStarted = filteredPluginCall("playerStarted")
QuestPluginManager.playerFailed = filteredPluginCall("playerFailed")
QuestPluginManager.playerCompleted = filteredPluginCall("playerCompleted")
QuestPluginManager.participantDied = broadcastPluginCall("participantDied")
