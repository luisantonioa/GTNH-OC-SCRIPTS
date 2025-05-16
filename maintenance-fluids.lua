local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")
local me = component.me_interface

local filepath = "/home/fluids.json"
local file, reason = io.open(filepath, "w")
if not file then
  error("Failed to open file: " .. tostring(reason))
end

local fluids = me.getFluidsInNetwork()

-- Sort by label
table.sort(fluids, function(a, b) return a.label < b.label end)

-- Start JSON array
file:write("[\n")

-- Write each fluid entry
for i, fluid in ipairs(fluids) do
  local entry = {
    label = fluid.label,
    name = fluid.name,
    amount = fluid.amount
  }

  -- Serialize each fluid table
  local json = serialization.serialize(entry)

  -- Indent and write to file
  file:write("  " .. json)

  -- Add comma if not last
  if i < #fluids then
    file:write(",\n")
  else
    file:write("\n")
  end
end

-- End JSON array
file:write("]\n")
file:close()

print("✅ Fluid data written to " .. filepath)
