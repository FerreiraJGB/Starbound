-- Helper function for working with tables as 2 component vectors
-- All functions operate on the given vector in-place
vec2 = {}

function vec2.eq(vector1, vector2)
  return vector1[1] == vector2[1] and vector1[2] == vector2[2]
end

function vec2.mag(vector)
  return math.sqrt(vector[1] * vector[1] + vector[2] * vector[2])
end

function vec2.norm(vector)
  return vec2.div(vector, vec2.mag(vector))
end

function vec2.mul(vector, scalar_or_vector)
  if type(scalar_or_vector) == "table" then
    return {
      vector[1] * scalar_or_vector[1],
      vector[2] * scalar_or_vector[2]
    }
  else
    return {
      vector[1] * scalar_or_vector,
      vector[2] * scalar_or_vector
    }
  end
end

function vec2.div(vector, scalar)
  if scalar == 0 then return vector end
  return {
      vector[1] / scalar,
      vector[2] / scalar
    }
end

function vec2.add(vector, scalar_or_vector)
  if type(scalar_or_vector) == "table" then
    return {
        vector[1] + scalar_or_vector[1],
        vector[2] + scalar_or_vector[2]
      }
  else
    return {
        vector[1] + scalar_or_vector,
        vector[2] + scalar_or_vector
      }
  end
end

function vec2.sub(vector, scalar_or_vector)
  if type(scalar_or_vector) == "table" then
    return {
        vector[1] - scalar_or_vector[1],
        vector[2] - scalar_or_vector[2]
      }
  else
    return {
        vector[1] - scalar_or_vector,
        vector[2] - scalar_or_vector
      }
  end
end

function vec2.angle(vector)
  local angle = math.atan(vector[2], vector[1])
  if angle < 0 then angle = angle + 2 * math.pi end
  return angle
end

function vec2.rotate(vector, angle)
  if angle == 0 then return {vector[1], vector[2]} end

  local sinAngle = math.sin(angle)
  local cosAngle = math.cos(angle)

  return {
    vector[1] * cosAngle - vector[2] * sinAngle,
    vector[1] * sinAngle + vector[2] * cosAngle,
  }
end

function vec2.withAngle(angle, magnitude)
  magnitude = magnitude or 1
  return {math.cos(angle) * magnitude, math.sin(angle) * magnitude}
end

function vec2.intersect(a0, a1, b0, b1)
  local segment1 = { a1[1] - a0[1], a1[2] - a0[2] }
  local segment2 = { b1[1] - b0[1], b1[2] - b0[2] }

  local s = (-segment1[2] * (a0[1] - b0[1]) + segment1[1] * (a0[2] - b0[2])) / (-segment2[1] * segment1[2] + segment1[1] * segment2[2]);
  local t = ( segment2[1] * (a0[2] - b0[2]) - segment2[2] * (a0[1] - b0[1])) / (-segment2[1] * segment1[2] + segment1[1] * segment2[2]);

  if s < 0 or s > 1 or t < 0 or t > 1 then
    return nil
  end

  return {
    a0[1] + (t * segment1[1]),
    a0[2] + (t * segment1[2])
  }
end

function vec2.dot(vector1, vector2)
  return vector1[1] * vector2[1] + vector1[2] * vector2[2]
end

function vec2.floor(vector)
  return { math.floor(vector[1]), math.floor(vector[2]) }
end

function vec2.approach(vector, target, rate)
  local maxDist = math.max(math.abs(target[1] - vector[1]), math.abs(target[2] - vector[2]))
  if maxDist <= rate then return target end

  local fractionalRate = rate / maxDist
  return {
    vector[1] + fractionalRate * (target[1] - vector[1]),
    vector[2] + fractionalRate * (target[2] - vector[2])
  }
end

function vec2.print(vector, precision)
  local fstring = "%."..precision.."f, %."..precision.."f"
  return string.format(fstring, vector[1], vector[2])
end

function vec2.lerp(ratio, a, b)
  return {a[1] + (b[1] - a[1]) * ratio, a[2] + (b[2] - a[2]) * ratio}
end
