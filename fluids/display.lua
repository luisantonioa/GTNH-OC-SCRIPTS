local component = require("component")
local term = require("term")
local unicode = require("unicode")
local utils = require("utils")
local config = require("config")

local gpu = component.gpu
local w, h = gpu.maxResolution()
gpu.setResolution(w, h)

local M = {}

function M.draw(fluids, thresholds, craftLog, timeLeft)
  term.clear()
  gpu.setForeground(0xFFFFFF)
  gpu.set(1, 1, "=== Fluid Monitor ===")

  -- Display Tracked Fluids
  gpu.set(1, 3, "Tracked Fluids:")
  local names = {}
  for name in pairs(thresholds) do table.insert(names, name) end
  table.sort(names)
  for i = 1, config.displayEntries do
    local name = names[i]
    if not name then break end
    local val = fluids[name] or 0
    local t = thresholds[name]
    local line = string.format("%-20s: %8s / [%s, %s]",
      name,
      utils.formatNumber(val),
      utils.formatNumber(t.lower),
      utils.formatNumber(t.upper)
    )
    gpu.set(2, 3 + i, unicode.sub(line, 1, w - 2))
  end

  -- Display Craft Log
  gpu.set(1, 15, "Last Craft Attempts:")
  for j = 1, math.min(config.displayEntries, #craftLog) do
    local entry = craftLog[#craftLog - j + 1]
    local line = string.format("%-20s: %s", entry.fluid, utils.formatNumber(entry.amount))
    gpu.set(2, 15 + j, unicode.sub(line, 1, w - 2))
  end

  -- Footer
  gpu.setForeground(0x00FF00)
  gpu.set(1, h - 1, string.format("Next refresh in: %ds | Press Q to quit", timeLeft))
end

return M
