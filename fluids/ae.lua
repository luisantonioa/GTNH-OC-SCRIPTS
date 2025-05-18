local component = require("component")
local config = require("config")

local meInterface = component.proxy(config.interfaceAddress)

local M = {}

function M.getFluids()
  local fluids = {}
  for _, f in ipairs(meInterface.getFluidsInNetwork() or {}) do
    fluids[f.label] = f.amount
  end
  return fluids
end

function M.findCraftable(fluid)
  for _, craft in ipairs(meInterface.getCraftables() or {}) do
    local stack = craft.getItemStack()
    if stack.label == "drop of " .. fluid then
      return craft
    end
  end
end

function M.requestCraft(fluid, amount)
  local craft = M.findCraftable(fluid)
  if not craft then return false end
  local task = craft.request(amount)
  return task and true or false
end

function M.isOnline()
  return pcall(function() meInterface.getItemsInNetwork() end)
end

return M
