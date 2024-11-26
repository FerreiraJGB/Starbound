require "/scripts/interp.lua"

-- param number
-- param factor
-- output result
function multiply(args, board)
  if args.number == nil or args.factor == nil then return false end
  return true, {result = args.number * args.factor}
end

-- param number
-- param addend
-- output result
function add(args, board)
  if args.number == nil or args.addend == nil then return false end
  return true, {result = args.number + args.addend}
end

-- param first
-- param second
-- output result
function sub(args, board)
  if args.first == nil or args.second == nil then return false end
  return true, {result = args.first - args.second}
end

-- param vector
-- param angle
-- param direction
-- output vector
function vecRotate(args, board)
  local angle = args.direction and vec2.angle(args.direction) or args.angle
  if args.vector == nil or angle == nil then return false end

  return true, {vector = vec2.rotate(args.vector, angle)}
end

-- param first
-- param second
-- param number --second in number type
-- output vector
function vecMultiply(args, board)
  local second = args.second or args.number
  if args.first == nil or second == nil then return false end
  return true, {vector = vec2.mul(args.first, second)}
end

-- param first
-- param second
-- output vector
function vecAdd(args, board)
  if args.first == nil or args.second == nil then return false end
  return true, {vector = vec2.add(args.first, args.second)}
end

-- param vector
-- output angle
function vecAngle(args, board)
  if args.vector == nil then return false end
  return true, {angle = math.atan(args.vector[2], args.vector[1])}
end

-- param min
-- param max
-- output number
function random(args, board)
  if args.min == nil or args.max == nil then return false end

  local rand = math.random() * (args.max - args.min) + args.min
  return true, {number = rand}
end

-- param chance
-- param seed
-- param seedMix
function chance(args, board)
  if args.chance == nil then return false end

  if args.seedMix then
    local seed = seed or (npc and npc.seed()) or (monster and monster.seed()) or generateSeed()
    return sb.staticRandomDouble(seed, args.seedMix) < args.chance
  else
    if seed then
      return sb.makeRandomSource(seed):randd() < args.chance
    else
      return math.random() < args.chance
    end
  end
end

-- param min
-- param max
-- param ratio
-- output number
function lerp(args, board)
  return true, {number = interp.linear(args.ratio, args.min, args.max)}
end

-- param ratio
-- param func
-- output ratio
function ease(args, board)
  local ratio = args.ratio
  if args.func == "sin" then
    ratio = math.sin(ratio * math.pi / 2)
  elseif args.func == "doubleSin" then
    ratio = math.sin(ratio * math.pi)
  elseif args.func == "quadSin" then
    ratio = math.sin(ratio * math.pi * 2 - math.pi / 2) / 2 + 0.5
  end
  return true, {ratio = ratio}
end

--------------------------------------------------------------
-- CONDITIONALS
--------------------------------------------------------------

-- param first
-- param second
function greaterThan(args)
  if args.first == nil or args.second == nil then return false end

  return args.first > args.second
end

-- param first
-- param second
function gte(args, board)
  return args.first >= args.second
end
