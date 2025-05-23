local component = require("component")
local sides = require("sides")
local ic = component.inventory_controller

-- CONFIGURATION
local interfaceSide = sides.up  -- Change to the side touching your ME Interface
local replacements = {
  ["drop of Krypton"] = "drop of Xenon"
}

-- HELPER: Replace label strings
local function applyReplacements(label)
  for from, to in pairs(replacements) do
    if label:lower():find(from:lower()) then
      return label:gsub(from, to)
    end
  end
  return label
end

-- PROCESS: One pattern in one slot
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
        if item.label then
          local newLabel = applyReplacements(item.label)
          if newLabel ~= item.label then
            print(string.format("↪ %s → %s", item.label, newLabel))
            item.label = newLabel
            changed = true
          end
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

-- MAIN LOOP
local size = ic.getInventorySize(interfaceSide)
for slot = 1, size do
  processPattern(slot)
end

print("✅ Pattern rewriting complete.")
