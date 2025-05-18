local fs = require("filesystem")
local serialization = require("serialization")
local config = require("fluids/config")

local craftLog = {}

function craftLog.load()
  if fs.exists(config.LOG_FILE) then
    local ok, data = pcall(dofile, config.LOG_FILE)
    if ok and type(data) == "table" then
      return data
    end
  end
  return {}
end

function craftLog.save(log)
  local file = io.open(config.LOG_FILE, "w")
  file:write("return " .. serialization.serialize(log))
  file:close()
end

return craftLog
