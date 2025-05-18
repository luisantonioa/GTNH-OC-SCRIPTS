local component = require("component")
local crafting = {}

local craftingAddress = "bea7e9dc-bc7f-4b4b-88dc-8d65b08df7b0"
local me = component.proxy(craftingAddress)

function crafting.findCraftable(fluid)
  for _, craft in ipairs(me.getCraftables()) do
    local stack = craft.getItemStack()
    if stack.label == ("drop of " .. fluid) then
      return craft
    end
  end
end

function crafting.request(fluid, amount, debug)
  local craft = crafting.findCraftable(fluid)
  if not craft then
    return false, "Pattern not found"
  end
  if debug then
    print("DEBUG: Would request", fluid, amount)
    return true
  end
  local success, reason = pcall(function()
    local task = craft.request(amount)
    return task ~= nil
  end)
  return success, reason
end

return crafting
