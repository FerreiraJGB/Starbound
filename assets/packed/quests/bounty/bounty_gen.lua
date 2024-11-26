require "/scripts/bountygeneration.lua"
require "/interface/cockpit/cockpitutil.lua"

function init()
  self.generatedQuests = {}
  self.generators = {}
  local behaviorNames = {
    "crazy"
  }
  local worlds = {}
  local currentWorld
  for i = 1, 10 do
    table.insert(worlds, worldIdCoordinate(player.worldId()))
  end
  for _,behaviorName in ipairs(behaviorNames) do
    table.insert(self.generators, coroutine.create(function()
        local generator, target = questGenerator(behaviorName, "capture_bounty", 2)
        local arc, used = generator:generateBountyArc(target, worlds)
        if arc then
          table.insert(self.generatedQuests, arc)
        else
          error("No arc produced")
        end
      end))
  end

  -- for _,endStep in ipairs({"capture_space_bounty", "capture_ship_bounty"}) do
  --   table.insert(self.generators, coroutine.create(function()
  --       local generator = questGenerator(nil, endStep, 2)
  --       local arc = generator:generateBountyArc(target)
  --       if arc then
  --         table.insert(self.generatedQuests, arc)
  --       else
  --         error("No arc produced")
  --       end
  --     end))
  -- end

  -- for i = 1, 100 do
  --   local gang = generateGang(sb.makeRandomSource():randu64())
  --   sb.logInfo("%s", gang.name)
  -- end
end

function questGenerator(behaviorName, endStep, stepCount)
  local seed = sb.makeRandomSource():randu64()
  local categories = {"planet"}
  local gang = generateGang(seed)
  sb.logInfo("Gang: %s", gang)

  local generator = BountyGenerator.new(seed, systemPosition(celestial.currentSystem()), {"orangestar", "whitestar"}, categories, endStep)
  generator.stepCount = {stepCount, stepCount}
  local target = generator:generateBountyNpc(gang, nil, false)

  generator.level = 4
  generator.preBountyQuest = "pre_bounty"
  generator.captureOnly = false
  generator.captureRewards = {
    money = 500,
    rank = 2
  }
  generator.killRewards = {
    money = 500,
    rank = 1
  }

  generator.debug = true

  return generator, target
end

function update(dt)
  if #self.generators > 0 then
    self.generators = util.filter(self.generators, function(gen)
      local s, res = coroutine.resume(gen)
      if not s then error(res) end

      return coroutine.status(gen) ~= "dead"
    end)
  else
    for _,arc in ipairs(self.generatedQuests) do
      player.startQuest(arc, player.serverUuid())
    end
      quest.complete()
  end
end
