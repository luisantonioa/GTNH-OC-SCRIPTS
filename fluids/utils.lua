local component = require("component")
local serialization = require("serialization")
local config = require("fluids/config")

local utils = {}

utils.meInterface = component.proxy(config.INTERFACE_ADDRESS)

function utils.formatNumber(n)
  if n >= 1e9 then
    return string.format("%.1fb", n / 1e9)
  elseif n >= 1e6 then
    return string.format("%.1fm", n / 1e6)
  elseif n >= 1e3 then
    return string.format("%.1fk", n / 1e3)
  else
    return tostring(n)
  end
end

function utils.findCraftable(fluid)
  for _, craft in ipairs(utils.meInterface.getCraftables()) do
    local stack = craft.getItemStack()
    if stack.label == "drop of " .. fluid then
      return craft
    end
  end
end

function utils.readFluids()
  local fluids = {}
  for _, f in ipairs(utils.meInterface.getFluidsInNetwork() or {}) do
    fluids[f.label] = f.amount
  end
  return fluids
end

return utils
