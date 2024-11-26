require "/scripts/augments/item.lua"

function applyCollar(output, collarConfig)
  output:setInstanceValue("currentCollar", collarConfig)

  local tooltipFields = output:instanceValue("tooltipFields", {})
  tooltipFields.collarNameLabel = collarConfig.displayName
  tooltipFields.collarIconImage = collarConfig.displayIcon
  tooltipFields.noCollarLabel = ""
  output:setInstanceValue("tooltipFields", tooltipFields)

  return output:descriptor(), 1
end

function apply(input)
  local output = Item.new(input)
  if not output:instanceValue("podUuid") then
    return nil
  end

  local collarConfig = config.getParameter("collar")
  local randomCollars = config.getParameter("randomCollars")

  if collarConfig then
    local currentCollar = output:instanceValue("currentCollar")
    if currentCollar then
      if currentCollar.name == collarConfig.name then
        return nil
      end
    end

    return applyCollar(output, collarConfig)
  elseif randomCollars then
    collarConfig = randomCollars[math.random(#randomCollars)]
    return applyCollar(output, collarConfig)
  end
end
