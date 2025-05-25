local component = require("component")
local meInterface = component.me_interface
local db = component.database

-- Debug print helper
local function dbg(fmt, ...)
  print(string.format(fmt, ...))
end

-- Check if a stack is a renamer mold by name and tag presence
local function isRenamerMold(stack)
  if not stack or not stack.withTag then return false end
  local tag = stack.withTag
  local hasName = tag.display and tag.display.Name
  if stack.name and stack.name:find("gregtech:metaitem.01:32315") and hasName then
    return true
  end
  return false
end

-- Find mold in pattern inputs, print all inputs info for debugging
local function findMoldInInputs(pattern)
  for i = 1, 9 do
    local stack = pattern.inputs[i]
    if stack then
      dbg("Pattern input slot %d: name=%s damage=%d hasTag=%s", i, tostring(stack.name), stack.damage or 0, tostring(stack.withTag ~= nil))
      if isRenamerMold(stack) then
        dbg(" -> Matched mold in slot %d (0-based index: %d)", i, i-1)
        return i-1, stack
      end
    else
      dbg("Pattern input slot %d: empty", i)
    end
  end
  return nil, nil
end

-- Search for an item in the database and return its slot index (0-based)
local function findItemInDB(itemStack)
  for slot = 0, 80 do
    local dbStack = db.get(slot)
    if dbStack and dbStack.name == itemStack.name and (dbStack.damage or 0) == (itemStack.damage or 0) then
      -- Simplified: no deep tag compare
      return slot
    end
  end
  return nil
end

-- Add item to DB, returns slot or nil + error
local function addItemToDB(itemStack)
  for slot = 0, 80 do
    if not db.get(slot) then
      local nbtJson = nil
      if itemStack.withTag then
        -- Basic conversion to JSON string for NBT (crude)
        nbtJson = require("json").encode(itemStack.withTag)
      end
      local success, err = db.set(slot, itemStack.name, itemStack.damage or 0, nbtJson)
      if success then
        dbg("Added item to DB slot %d: %s", slot, itemStack.name)
        return slot
      else
        dbg("Failed to add item to DB: %s", err or "unknown error")
        return nil, err
      end
    end
  end
  dbg("No free DB slots available!")
  return nil, "No free DB slots"
end

-- Update pattern by adding mold as byproduct (do not remove from inputs)
local function addMoldToByproducts(patternIndex, moldDbSlot)
  local success = meInterface.addPatternByproduct(patternIndex, moldDbSlot, 1)
  if success then
    dbg("Added mold from DB slot %d as byproduct to pattern %d", moldDbSlot, patternIndex)
  else
    dbg("Failed to add byproduct to pattern %d", patternIndex)
  end
  return success
end

-- Main processing loop for all 36 patterns
local function processPatterns()
  local maxPatterns = 36
  for i = 1, maxPatterns do
    dbg("Processing pattern %d", i)
    local pattern = meInterface.getInterfacePattern(i-1)
    if not pattern then
      dbg("No pattern found at index %d", i-1)
    else
      local moldInputIndex, moldStack = findMoldInInputs(pattern)
      if not moldStack then
        dbg("No mold found in inputs for pattern %d", i)
      else
        dbg("Found mold in pattern %d input slot %d", i, moldInputIndex)
        local moldDbSlot = findItemInDB(moldStack)
        if not moldDbSlot then
          dbg("Mold not found in DB, adding...")
          moldDbSlot = addItemToDB(moldStack)
          if not moldDbSlot then
            dbg("Error adding mold to DB, skipping pattern %d", i)
            goto continue
          end
        else
          dbg("Mold found in DB slot %d", moldDbSlot)
        end
        local ok = addMoldToByproducts(i-1, moldDbSlot)
        if not ok then
          dbg("Failed to update pattern %d", i)
        end
      end
    end
    ::continue::
  end
end

processPatterns()
