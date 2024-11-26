function simpleHandler(fun)
  return function (_, _, ...) return fun(...) end
end

function localHandler(fun)
  return function (_, isLocal, ...)
      if isLocal then return fun(...) end
    end
end

PromiseKeeper = {}
PromiseKeeper.__index = PromiseKeeper

function PromiseKeeper.new()
  local self = setmetatable({}, PromiseKeeper)
  self.promises = {}
  return self
end

-- onSuccess is a function called with the value wrapped by the promise once it
-- is finished successfully.
-- onError is called if the promise returns an error.
-- Both of those on* parameters are optional.
function PromiseKeeper:add(promise, onSuccess, onError)
  self.promises[#self.promises+1] = {
      promise = promise,
      onSuccess = onSuccess,
      onError = onError
    }
end

function PromiseKeeper:empty()
  return #self.promises == 0
end

-- Remove finished promises, calling their callbacks.
function PromiseKeeper:update()
  local promises = self.promises
  -- Ensure promises made while processing callbacks are kept
  self.promises = {}
  for _,promise in pairs(promises) do
    if promise.promise:finished() then
      if promise.promise:succeeded() then
        if promise.onSuccess then promise.onSuccess(promise.promise:result()) end
      else
        if promise.onError then promise.onError(promise.promise:error()) end
      end
    else
      self.promises[#self.promises+1] = promise
    end
  end
end

promises = PromiseKeeper.new()
