local component = require("component")
local meInterface = component.me_interface

-- Interface and pattern parameters
local MAX_SLOT = 36
local MAX_ITEMS = 9

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
local function applyReplacements(entry)
  for old, new in pairs(replacements) do
    if entry.name and entry.name:lower():find(old:lower()) then
      print("↪ Found", entry.name, "x" .. entry.count)
      entry.name = new.name
      local oldCount = entry.count or 0
      entry.count = math.floor(oldCount * new.ratio + 0.5)
      print("   → Replaced with", entry.name, "x" .. entry.count)
      return true
    end
  end
  return false
end

-- Main logic: read patterns, apply replacements, write back
for i = 1, MAX_SLOT do
  local pattern = meInterface.getInterfacePattern(i)
  if not pattern then goto continue end

  local changed = false
  for _, field in ipairs({"inputs", "outputs"}) do
    if pattern[field] then
      for _, item in ipairs(pattern[field]) do
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
