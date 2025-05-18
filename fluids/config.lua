-- File: config.lua
local fs = require("filesystem")
local serialization = require("serialization")

local config = {}
local CONFIG_PATH = "/home/fluids/thresholds.lua"
local DEFAULT_THRESHOLDS = {
  ["Chlorine"] = {lower = 5000000, upper = 10000000},
}

function config.load()
  if fs.exists(CONFIG_PATH) then
    local ok, result = pcall(dofile, CONFIG_PATH)
    if ok and type(result) == "table" then
      return result
    end
  end
  return DEFAULT_THRESHOLDS
end

function config.save(thresholds)
  local file = io.open(CONFIG_PATH, "w")
  file:write("return " .. serialization.serialize(thresholds))
  file:close()
end

return config
