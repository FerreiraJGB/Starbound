require("/scripts/util.lua")
require("/scripts/quest/manager/plugin.lua")

AddTenant = subclass(QuestPlugin, "AddTenant")

function AddTenant:init(...)
  QuestPlugin.init(self, ...)
end

function AddTenant:playerCompleted(player)
  QuestPlugin.playerCompleted(self, player)

  local deed = self.questParameters[self.config.deedParameter].uniqueId
  local deedEntityId = world.loadUniqueEntity(deed)
  -- Quest should have failed if the deed doesn't exist
  assert(world.entityExists(deedEntityId))

  local tenantParam = self.questParameters[self.config.tenantParameter] or {}
  local tenant = nil

  if tenantParam.type == "monsterType" then
    tenant = {
        spawn = "monster",
        type = tenantParam.typeName,
        overrides = tenantParam.parameters
      }

  elseif tenantParam.type == "npcType" then
    tenant = {
        spawn = "npc",
        species = tenantParam.species,
        type = tenantParam.typeName,
        seed = tenantParam.seed or generateSeed(),
        overrides = tenantParam.parameters
      }

  else
    error(string.format("Invalid parameter type %s for AddTenant quest plugin", tenantParam.type))
  end

  if tenant then
    world.callScriptedEntity(deedEntityId, "addTenant", tenant)
  end
end
