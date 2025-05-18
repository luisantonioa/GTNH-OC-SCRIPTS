local utils = {}

function utils.formatNumber(n)
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

function utils.findMEInterfaces()
  local component = require("component")
  local meAddresses = {}
  for addr, ctype in component.list("me_interface") do
    table.insert(meAddresses, addr)
  end
  return meAddresses
end

return utils
