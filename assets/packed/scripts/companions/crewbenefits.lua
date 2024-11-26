require "/scripts/util.lua"

local benefitTypes = {}

Benefit = {}
Benefit.__index = Benefit

function Benefit:new(definition, store)
  local benefit = setmetatable({}, self)
  benefit.definition = definition
  benefit:init(store)
  return benefit
end

function Benefit:init()
end

function Benefit:store()
end

function Benefit:shipUpdate(recruit, dt)
end

function Benefit:persistentEffects()
  return {}
end

function Benefit:ephemeralEffects()
  return {}
end

function Benefit:regenerationAmount()
  return 0
end

-- returns a *list* of ship upgrade configurations
function Benefit:shipUpgrades()
  return {}
end

benefitTypes.EphemeralEffect = setmetatable({}, Benefit)
benefitTypes.EphemeralEffect.__index = benefitTypes.EphemeralEffect

function benefitTypes.EphemeralEffect:ephemeralEffects()
  if self.definition.duration then
    return {{
        effect = self.definition.effect,
        duration = self.definition.duration
      }}
  else
    return { self.definition.effect }
  end
end

benefitTypes.PersistentEffect = setmetatable({}, Benefit)
benefitTypes.PersistentEffect.__index = benefitTypes.PersistentEffect

function benefitTypes.PersistentEffect:persistentEffects()
  return { self.definition.effect }
end

benefitTypes.Regeneration = setmetatable({}, Benefit)
benefitTypes.Regeneration.__index = benefitTypes.Regeneration

function benefitTypes.Regeneration:regenerationAmount()
  return self.definition.value
end

local ShipUpgradeBenefit = setmetatable({}, Benefit)
ShipUpgradeBenefit.__index = ShipUpgradeBenefit
ShipUpgradeBenefit.operation = nil
benefitTypes.ShipUpgradeBenefit = ShipUpgradeBenefit

function ShipUpgradeBenefit:init(store)
end

function ShipUpgradeBenefit:shipUpgrades()
  return {
    { [self.definition.property] = self.definition.value }
  }
end

local Composite = setmetatable({}, Benefit)
Composite.__index = Composite

function Composite:init(store)
  store = store or {}
  self.benefits = util.mapWithKeys(self.definition or {}, function (key, definition)
      return loadBenefits(definition, store[key])
    end)
end

function Composite:store()
  return util.mapWithKeys(self.definition or {}, function (key, _)
      return self.benefits[key]:store()
    end)
end

function Composite:persistentEffects()
  local effects = {}
  for _,benefit in pairs(self.benefits) do
    util.appendLists(effects, benefit:persistentEffects())
  end
  return effects
end

function Composite:ephemeralEffects()
  local effects = {}
  for _,benefit in pairs(self.benefits) do
    util.appendLists(effects, benefit:ephemeralEffects())
  end
  return effects
end

function Composite:regenerationAmount()
  local amount = 0
  for _, benefit in pairs(self.benefits) do
    amount = amount + benefit:regenerationAmount()
  end
  return amount
end

function Composite:shipUpgrades()
  local upgrades = {}
  for _,benefit in pairs(self.benefits) do
    util.appendLists(upgrades, benefit:shipUpgrades())
  end
  return upgrades
end

function Composite:shipUpdate(recruit, dt)
  for _, benefit in pairs(self.benefits) do
    benefit:shipUpdate(recruit, dt)
  end
end

function loadBenefits(definition, store)
  if not definition or isEmpty(definition) or definition[1] then
    return Composite:new(definition, store)
  else
    local benefitClass = benefitTypes[definition.type]
    return benefitClass:new(definition, store)
  end
end

function getRegenerationEffect(type, regeneration)
  if regeneration == 0 then return nil end
  local regenEffects = config.getParameter("crewBenefits."..type.."Regeneration")
  local effectName = regenEffects[regeneration] or regenEffects[#regenEffects]
  return effectName
end
