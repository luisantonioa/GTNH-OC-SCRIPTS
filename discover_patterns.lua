local component = require("component")
local serialization = require("serialization")
local fs = require("filesystem")

local me = component.proxy("bea7e9dc-bc7f-4b4b-88dc-8d65b08df7b0")
local file_path = "/home/requestables.lua"

local function getCraftables()
  local results = {}

  -- Get item craftables
  local items = me.getItemsInNetwork() or {}
  local craftables = me.getCraftables()
  for _, craft in ipairs(craftables) do
    local stack = craft.getItemStack()
    table.insert(results, {
      label = stack.label,
      name = stack.name,
      amount = stack.size,
      isFluid = false
    })
  end

  -- Get fluid craftables
  local fluidCraftables = me.getCraftableFluids and me.getCraftableFluids() or {}
  for _, fluid in ipairs(fluidCraftables) do
    table.insert(results, {
      label = fluid.label,
      name = fluid.name,
      amount = fluid.amount,
      isFluid = true
    })
  end

  return results
end

local function saveAsLua(data, path)
  local f, err = io.open(path, "w")
  if not f then
    error("Failed to open file: " .. tostring(err))
  end
  f:write("return ")
  f:write(serialization.serialize(data))
  f:close()
  print("Saved requestables to: " .. path)
end

local data = getCraftables()
saveAsLua(data, file_path)
