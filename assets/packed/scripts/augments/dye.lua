require "/scripts/util.lua"
require "/scripts/augments/item.lua"

function paletteSwapDirective(color)
  local directive = "replace"
  for key,val in pairs(color) do
    directive = directive .. ";" .. key .. "=" .. val
  end
  return directive
end

function getColorOptions(dyeable)
  local options = {}
  for _,color in ipairs(dyeable:instanceValue("colorOptions", {})) do
    if type(color) == "string" then
      table.insert(options, color)
    else
      table.insert(options, paletteSwapDirective(color))
    end
  end
  return options
end

function getDirectives(dyeable)
  local directives = dyeable:instanceValue("directives", "")
  if directives == "" then
    local colorOptions = getColorOptions(dyeable)
    if #colorOptions > 0 then
      local colorIndex = dyeable:instanceValue("colorIndex", 0)
      directives = "?" .. util.tableWrap(colorOptions, colorIndex + 1)
    end
  end
  return directives
end

function isArmor(item)
  local armors = {
      headarmor = true,
      chestarmor = true,
      legsarmor = true,
      backarmor = true
    }
  return armors[item:type()] == true
end

function apply(input)
  local output = Item.new(input)

  if not isArmor(output) then
    return nil
  end

  local dyeColorIndex = config.getParameter("dyeColorIndex")
  local dyeDirectives = config.getParameter("dyeDirectives")

  local colorOptions = getColorOptions(output)
  local currentDirectives = getDirectives(output)

  if dyeColorIndex then
    if not isEmpty(colorOptions) then
      local dyeDirectives = "?" .. util.tableWrap(colorOptions, dyeColorIndex + 1)
      if dyeDirectives ~= currentDirectives then
        output:setInstanceValue("colorIndex", dyeColorIndex)
        output:setInstanceValue("directives", "")

        return output:descriptor(), 1
      end
    end

  elseif dyeDirectives then
    local processedDirectives = dyeDirectives
    if type(processedDirectives) == "table" then
      processedDirectives = paletteSwapDirective(processedDirectives)
    end

    if processedDirectives ~= currentDirectives then
      output:setInstanceValue("directives", "?" .. processedDirectives)

      return output:descriptor(), 1
    end
  end
end
