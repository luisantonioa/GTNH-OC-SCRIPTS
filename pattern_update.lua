local component = require("component")
local sides = require("sides")
local ic = component.inventory_controller

-- CONFIGURATION
local interfaceSide = sides.up -- Adjust as needed
local replacements = {
  ["drop of Krypton"] = {
    label = "drop of Xenon",
    ratio = 250/400,  -- multiply amount by this
  },
  ["drop of Nitrogen"] = {
    label = "drop of Xenon",
    ratio = 250/1000, -- multiply amount by this
  }
}

-- Replace label and adjust amount according to ratio
local function applyReplacements(item)
  for from, toData in pairs(replacements) do
    if item.label and item.label:lower():find(from:lower()) then
      local newLabel = item.label:gsub(from, toData.label)
      if newLabel ~= item.label then
        -- Adjust amount if present
        if item.amount and type(item.amount) == "number" then
          local oldAmount = item.amount
          local newAmount = math.floor(oldAmount * toData.ratio + 0.5) -- round nearest
          print(string.format("↪ %s x%d → %s x%d", item.label, oldAmount, newLabel, newAmount))
          item.amount = newAmount
        else
          print(string.format("↪ %s → %s (no amount to adjust)", item.label, newLabel))
        end
        item.label = newLabel
        return true
      end
    end
  end
  return false
end

-- Process single slot pattern
local function processPattern(slot)
  local stack = ic.getStackInSlot(interfaceSide, slot)
  if not stack or not stack.name:find("encoded_pattern") then return false end

  local tag = stack.tag
  if not tag or not tag.pattern then return false end

  local changed = false
  for _, direction in ipairs({ "in", "out" }) do
    local group = tag.pattern[direction]
    if group then
      for _, item in ipairs(group) do
        if applyReplacements(item) then
          changed = true
        end
      end
    end
  end

  if changed then
    ic.replaceStackInSlot(interfaceSide, slot, stack)
    print("✅ Rewritten pattern in slot", slot)
  end

  return changed
end

-- Main loop
local size = ic.getInventorySize(interfaceSide)
for slot = 1, size do
  processPattern(slot)
end

print("✅ Pattern rewriting complete.")
