if not M33kAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

function M33kAuras.IsDurationObject(duration)
  if type(duration) == "userdata" and duration.GetRemainingDuration then
    return true
  end
  return false
end

local typeToFormatter = {
  elapsed = "FormatElapsedDuration",
  remaining = "FormatRemainingDuration",
  total = "FormatTotalDuration",
}

local typeToGetter = {
  elapsed = "GetElapsedDuration",
  remaining = "GetRemainingDuration",
  total = "GetTotalDuration",
}

function M33kAuras.GetDurationObjectValue(duration, type, formatter)
  if formatter then
    return duration[typeToFormatter[type]](duration, formatter)
  else
    return duration[typeToGetter[type]](duration)
  end
end
