function blessPlayer(args, board)
  local seed = math.floor(os.time() / args.rotation)

  local blessing = args.blessings[sb.staticRandomI32Range(1, #args.blessings, seed)]
  world.sendEntityMessage(args.entity, "applyStatusEffect", blessing, args.duration, entity.id());
  return true
end
