
-- Pulls the given rope as tightly as possible around the idealized tile
-- geometry without changing the start or end points of the rope
function windRope(ropePoints)
  local sqrt2d2 = math.sqrt(2) / 2

  -- Returns whether the three given points are in a straight line (returns 0),
  -- go counter clocwise (returns > 0) or go clockwise (returns < 0)
  local function sign(p1, p2, p3)
    return (p1[1] - p3[1]) * (p2[2] - p3[2]) - (p2[1] - p3[1]) * (p1[2] - p3[2])
  end

  local i = 2
  while i < #ropePoints do
    local before = ropePoints[i - 1]
    local current = ropePoints[i]
    local after = ropePoints[i + 1]

    local curSign = sign(before, current, after)
    if curSign == 0 then
      table.remove(ropePoints, i)
    else
      local backDirection = vec2.norm(vec2.sub(before, current))
      local forwardDirection = vec2.norm(vec2.sub(after, current))
      local windDirection = vec2.norm(vec2.add(backDirection, forwardDirection))

      local keepCurrentPoint = false
      local crossedPoints = {}

      local function testCollisionPoint(point, inward)
        -- True if the given point is part of a block that this line is
        -- currently winding around
        local innerPoint = vec2.dot(windDirection, inward) > sqrt2d2

        if vec2.eq(before, point) or vec2.eq(after, point) then
          -- Don't need to collide with the previous and next points, they will
          -- not be removed and don't need to be added again
          return
        elseif vec2.eq(current, point) then
          -- If the current point is a previous collision with a block, keep it
          -- only if it is an inner point on the rope
          if innerPoint then
            keepCurrentPoint = true
          end
        else
          -- Otherwise, test for whether this point is in the triangle formed
          -- by the points before, current, after.  Test inclusively if this is
          -- an inner point, otherwise exclusively.

          local a, b, c
          if curSign < 0 then
            a, b, c = after, current, before
          else
            a, b, c = before, current, after
          end

          if innerPoint then
            if sign(point, a, b) >= 0 and sign(point, b, c) >= 0 and sign(point, c, a) >= 0 then
              table.insert(crossedPoints, point)
            end
          else
            if sign(point, a, b) > 0 and sign(point, b, c) > 0 and sign(point, c, a) > 0 then
              table.insert(crossedPoints, point)
            end
          end
        end
      end

      local xMin = math.ceil(math.min(before[1], current[1], after[1])) - 1
      local xMax = math.floor(math.max(before[1], current[1], after[1])) + 1
      local yMin = math.ceil(math.min(before[2], current[2], after[2])) - 1
      local yMax = math.floor(math.max(before[2], current[2], after[2])) + 1

      for x = xMin, xMax do
        for y = yMin, yMax do
          if world.pointTileCollision({x + 0.5, y + 0.5}, {"dynamic", "block"}) then
            testCollisionPoint({x, y}, {sqrt2d2, sqrt2d2})
            testCollisionPoint({x + 1, y}, {-sqrt2d2, sqrt2d2})
            testCollisionPoint({x + 1, y + 1}, {-sqrt2d2, -sqrt2d2})
            testCollisionPoint({x, y + 1}, {sqrt2d2, -sqrt2d2})
          end
          if keepCurrentPoint then break end
        end
        if keepCurrentPoint then break end
      end

      if keepCurrentPoint then
        -- If we have found that the current point is still an inner tile
        -- collision point, keep it and move on.
        i = i + 1
      elseif #crossedPoints == 0 then
        -- Otherwise, if there are no colliding points, then we can tighten the
        -- rope by eliminating it entirely.
        table.remove(ropePoints, i)
      else
        -- If the point is no longer an inner tile collision point but there
        -- ARE colliding points, add the point that is encountered soonest when
        -- winding the rope around.  We still keep the current point in the
        -- list when adding a new rope point, which generally makes an odd
        -- empty space shape, but this is intentional as we will visit the
        -- current point a second time on the next time through the loop, and
        -- hopefully eliminate the space or possibly cause a second rope
        -- collision.

        -- Sort the crossed points by the lowest rotation angle from the before
        -- -> current vector to the new before -> crossed vector, so as not to
        -- skip any crossed points when adding a new vertex.  If several points
        -- are along the same angle, then sort with the furthest away one
        -- first.  This is common on straight edges of geometry, and prevents
        -- tons of repeat vertexes for a single frame
        table.sort(crossedPoints, function(a, b)
          local aBack = vec2.sub(before, a)
          local bBack = vec2.sub(before, b)
          local lenABack = vec2.mag(aBack)
          local lenBBack = vec2.mag(bBack)
          local dotABack = vec2.dot(vec2.div(aBack, lenABack), backDirection)
          local dotBBack = vec2.dot(vec2.div(bBack, lenBBack), backDirection)
          if dotABack == dotBBack then
            return lenABack > lenBBack
          else
            return dotABack > dotBBack
          end
        end)

        table.insert(ropePoints, i, crossedPoints[1])
        i = i + 1
      end
    end
  end
end
