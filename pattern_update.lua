local component = require("component")
local meInterface = component.me_interface
local db = component.database
local serialization = require("serialization")

-- Interface and pattern parameters
local MAX_SLOT = 36
local MAX_ITEMS = 9

-- You must pick a free slot in the database (0-26)
local dbSlot = 25
local dbAddress = component.getPrimary("database").address

----------------------------------------
-- Step 1: Look up "drop of Xenon"
----------------------------------------
local function findItem(labelSearch)
  local items = meInterface.getItemsInNetwork() or {}
  for _, item in ipairs(items) do
    if item.label and item.label:lower():find(labelSearch:lower()) then
      return {
        id = item.name,
        damage = item.damage,
        nbt = item.hasTag and item.tag and serialization.serialize(item.tag) or nil
      }
    end
  end
  return nil
end

local xenon = {
  id = "ae2fc:fluid_drop",
  damage = 0,
  nbt = '{Fluid: "xenon"}'
}

-- Replace this table to add more conversions
local replacements = {
  ["drop of Krypton"] = {
    target = xenon,
    ratio = 250 / 400
  },
  ["drop of Nitrogen"] = {
    target = xenon,
    ratio = 250 / 1000
  }
}

-- Check if an item needs replacement
local function getReplacement(item)
  for name, rule in pairs(replacements) do
    if item.name:lower():find(name:lower()) then
      return {
        id = rule.target.id,
        damage = rule.target.damage,
        nbt = rule.target.nbt,
        count = math.floor(item.count * rule.ratio + 0.5)
      }
    end
  end
  return nil
end

-- Writes an item into the DB
local function writeToDb(slot, item)
  db.clear(slot)
  local ok, err = db.set(slot, item.id, item.damage, item.nbt)
  if not ok then
    error("Failed to write to DB: " .. tostring(err))
  end
end

-- Main logic: read patterns, apply replacements, write back
for i = 1, MAX_SLOT do
  local pattern = meInterface.getInterfacePattern(i)
  if not pattern then goto continue end

  local changed = false

  -- Inputs
  for a, item in ipairs(pattern.inputs or {}) do
    local newItem = getReplacement(item)
    if newItem then
      writeToDb(dbSlot, newItem)
      meInterface.setInterfacePatternInput(i, dbAddress, dbSlot, newItem.count, a - 1)
      print(string.format("✅ Updated input #%d in pattern %d", a, i))
      changed = true
    end
  end

  if not changed then
    print(string.format("🔎 No changes needed for pattern %d", i))
  end

  ::continue::
end

print("✅ All patterns checked.")
