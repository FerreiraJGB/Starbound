require "/scripts/augments/item.lua"

function apply(input)
  local output = Item.new(input)
  if not output:instanceValue("usesFishingUpgrades") then
    return nil
  end

  local reelType = config.getParameter("reelType")
  if reelType and reelType ~= output:instanceValue("reelType") then
    output:setInstanceValue("reelType", reelType)
    output:setInstanceValue("reelName", config.getParameter("reelName"))
    output:setInstanceValue("reelIcon", config.getParameter("reelIcon"))
    output:setInstanceValue("reelParameters", config.getParameter("reelParameters"))

    return output:descriptor(), 1
  end

  local lureType = config.getParameter("lureType")
  if lureType and lureType ~= output:instanceValue("lureType") then
    output:setInstanceValue("lureType", lureType)
    output:setInstanceValue("lureName", config.getParameter("lureName"))
    output:setInstanceValue("lureIcon", config.getParameter("lureIcon"))
    output:setInstanceValue("lureProjectile", config.getParameter("lureProjectile"))

    return output:descriptor(), 1
  end
end
