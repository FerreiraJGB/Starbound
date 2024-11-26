require "/scripts/versioningutils.lua"

function update(data)
  executeWhere(data, nil, "acidrain", function(object)
      if object.parameters and object.parameters.power then
        object.parameters.power = 0
      end
    end)

  return data
end
