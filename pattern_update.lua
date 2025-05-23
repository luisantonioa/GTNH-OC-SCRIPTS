local component = require("component")
local meInterface = component.me_interface

local replacements = {
  ["drop of Krypton"] = {
    label = "drop of Xenon",
    ratio = 250/400,
  },
  ["drop of Nitrogen"] = {
    label = "drop of Xenon",
    ratio = 250/1000,
  }
}

local function applyReplacements(item)
  for from, toData in pairs(replacements) do
    if item.label and item.label:lower():find(from:lower()) then
      local newLabel = item.label:gsub(from, toData.label)
      if newLabel ~= item.label then
        if item.amount and type(item.amount) == "number" then
          local oldAmount = item.amount
          local newAmount = math.floor(oldAmount * toData.ratio + 0.5)
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

local function processPattern(index)
  local pattern = meInterface.getPattern(index)
  if not pattern or not pattern.pattern then return false end

  local changed = false
  for _, dir in ipairs({ "in", "out" }) do
    local group = pattern.pattern[dir]
    if group then
      for _, item in ipairs(group) do
        if applyReplacements(item) then
          changed = true
        end
      end
    end
  end

  if changed then
    meInterface.setPattern(index, pattern)
    print("✅ Updated pattern at index", index)
  end

  return changed
end

local patterns = meInterface.getPatterns()
if not patterns then
  print("No patterns found in ME Interface.")
  return
end

for index = 1, #patterns do
  processPattern(index)
end

print("✅ Pattern rewriting complete.")
