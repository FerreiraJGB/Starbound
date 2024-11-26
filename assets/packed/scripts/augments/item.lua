Item = {}
Item.__index  = Item

function Item.new(...)
  local self = setmetatable({}, Item)
  self:init(...)
  return self
end

function Item:init(descriptor)
  self.name = descriptor.name
  self.count = descriptor.count or 1
  self.parameters = descriptor.parameters or {}
  self.config = root.itemConfig(descriptor).config
end

function Item:type()
  return root.itemType(self.name)
end

function Item:descriptor()
  return {
      name = self.name,
      count = self.count,
      parameters = self.parameters
    }
end

function Item:instanceValue(name, default)
  return sb.jsonQuery(self.parameters, name) or sb.jsonQuery(self.config, name) or default
end

function Item:setInstanceValue(name, value)
  self.parameters[name] = value
end
