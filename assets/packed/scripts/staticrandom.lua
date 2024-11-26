function valueOrRandom(value, seed, seedMix)
  if value then
    return value
  else
    return sb.staticRandomDouble(seed, seedMix)
  end
end

function randomFromList(list, seed, seedMix)
  if type(list) == "table" then
    return list[sb.staticRandomI32Range(1, #list, seed, seedMix)]
  else
    return list
  end
end

function randomInRange(list, seed, seedMix)
  if type(list) == "table" then
    return sb.staticRandomDoubleRange(list[1], list[2], seed, seedMix)
  else
    return list
  end
end

function randomIntInRange(list, seed, seedMix)
  if type(list) == "table" then
    return sb.staticRandomI32Range(list[1], list[2], seed, seedMix)
  else
    return list
  end
end
