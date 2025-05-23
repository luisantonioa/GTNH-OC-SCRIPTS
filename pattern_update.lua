local component = require("component")
local meInterface = component.me_interface

-- Replace this table to add more conversions
local replacements = {
  ["drop of Krypton"] = {
    label = "drop of Xenon",
    ratio = 250 / 400
  },
  ["drop of Nitrogen"] = {
    label = "drop of Xenon",
    ratio = 250 / 1000
  }
}

-- Apply label replacement and adjust amount
local function applyReplacements(item)
  for from, data in pairs(replacements) do
    if item.label and item.label:lower():find(from:lower()) then
      local newLabel = item.label:gsub(from, data.label)
      if newLabel ~= item.label then
        if item.amount and type(item.amount) == "number" then
          local oldAmount = item.amount
          local newAmount = math.floor(oldAmount * data.ratio + 0.5)
          print(string.format("↪ %s x%d → %s x%d", item.label, oldAmount, newLabel, newAmount))
          item.amount = newAmount
        else
          print(string.format("↪ %s → %s (no amount)", item.label, newLabel))
        end
        item.label = newLabel
        return true
      end
    end
  end
  return false
end

-- Get number of patterns in this ME Interface
local function countPatterns()
  local i = 0
  while meInterface.getInterfacePattern(i) do
    i = i + 1
  end
  return i
end

-- Main logic: read patterns, apply replacements, write back
for i = 0, countPatterns() - 1 do
  local pattern = meInterface.getInterfacePattern(i)
  if not pattern or not pattern.pattern then goto continue end

  local changed = false
  for _, side in ipairs({ "in", "out" }) do
    local group = pattern.pattern[side]
    if group then
      for _, item in ipairs(group) do
        if applyReplacements(item) then
          changed = true
        end
      end
    end
  end

  if changed then
    meInterface.setInterfacePattern(i, pattern)
    print("✅ Pattern updated at slot", i)
  end

  ::continue::
end

print("✅ All patterns checked.")
