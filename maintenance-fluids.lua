local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")
local me = component.me_interface

-- Load thresholds from JSON file
local threshold_path = "/home/thresholds.json"
local threshold_file = io.open(threshold_path, "r")
if not threshold_file then
  error("Failed to open thresholds file: " .. threshold_path)
end
local threshold_data = serialization.unserialize(threshold_file:read("*a"))
threshold_file:close()

-- Read fluid data from AE2
local fluids = me.getFluidsInNetwork()
table.sort(fluids, function(a, b) return a.label < b.label end)

-- Check each fluid against threshold
for _, fluid in ipairs(fluids) do
  local label = fluid.label
  local amount = fluid.amount
  local threshold = threshold_data[label]

  if threshold then
    if amount >= threshold then
      print(string.format("✅ %s: %d ≥ %d", label, amount, threshold))
    else
      print(string.format("⚠️ %s: %d < %d", label, amount, threshold))
    end
  end
end
