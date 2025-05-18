local serialization = require("serialization")

local M = {}

function M.formatNumber(n)
  if n >= 1e9 then
    return string.format("%.1fb", n / 1e9)
  elseif n >= 1e6 then
    return string.format("%.1fm", n / 1e6)
  elseif n >= 1e3 then
    return string.format("%.1fk", n / 1e3)
  else
    return tostring(n)
  end
end

function M.loadTable(path)
  local ok, result = pcall(dofile, path)
  if ok and type(result) == "table" then
    return result
  end
  return {}
end

function M.saveTable(path, data)
  local f = assert(io.open(path, "w"))
  f:write("return " .. serialization.serialize(data))
  f:close()
end

return M
