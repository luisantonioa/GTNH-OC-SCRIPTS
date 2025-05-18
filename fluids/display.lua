local term = require("term")
local gpu = require("component").gpu
local computer = require("computer")
local utils = require("/home/fluids/utils")

local display = {}
local w, h = gpu.maxResolution()
gpu.setResolution(w, h)

function display.status(fluids, thresholds, crafts, nextRefresh)
  term.clear()
  gpu.set(1, 1, "=== Fluid Monitor ===")

  gpu.set(1, 3, "Tracked Fluids:")
  local i = 0
  for name, limits in pairs(thresholds) do
    if i >= 10 then break end
    local val = fluids[name] or 0
    local line = string.format("%-20s: %8s / [%s, %s]", name, utils.formatNumber(val), utils.formatNumber(limits.lower), utils.formatNumber(limits.upper))
    gpu.set(2, 4 + i, line)
    i = i + 1
  end

  gpu.set(1, 16, "Last Craft Attempts:")
  for j = 1, math.min(10, #crafts) do
    local entry = crafts[#crafts - j + 1]
    local line = string.format("%-20s: %s", entry.fluid, utils.formatNumber(entry.amount))
    gpu.set(2, 16 + j, line)
  end

  gpu.set(1, h, "Next refresh in: " .. math.max(0, math.floor(nextRefresh - computer.uptime())) .. "s | Press Q to quit")
end

return display
