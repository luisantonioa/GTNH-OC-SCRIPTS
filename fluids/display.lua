local term = require("term")
local computer = require("computer")
local event = require("event")
local component = require("component")
local gpu = component.gpu
local unicode = require("unicode")

local config = require("fluids/config")
local utils = require("fluids/utils")

local display = {}

local w, h = gpu.maxResolution()
gpu.setResolution(w, h)

function display.status(fluids, thresholds, log, timeLeft)
  term.clear()
  gpu.setForeground(0xFFFFFF)
  gpu.set(1, 1, "=== Fluid Monitor ===")
  gpu.set(1, 3, "Tracked Fluids:")

  local i = 0
  local names = {}
  for name in pairs(thresholds) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    if i >= config.DISPLAY_ENTRIES then break end
    local val = fluids[name] or 0
    local t = thresholds[name]
    local line = string.format("%-20s: %8s / [%s, %s]", name,
      utils.formatNumber(val), utils.formatNumber(t.lower), utils.formatNumber(t.upper))
    gpu.set(2, 4 + i, unicode.sub(line, 1, w - 2))
    i = i + 1
  end

  gpu.set(1, 16, "Last Craft Attempts:")
  for j = 1, math.min(config.DISPLAY_ENTRIES, #log) do
    local entry = log[#log - j + 1]
    local line = string.format("%-20s: %s", entry.fluid, utils.formatNumber(entry.amount))
    gpu.set(2, 16 + j, unicode.sub(line, 1, w - 2))
  end

  gpu.setForeground(0x00FF00)
  gpu.set(1, h, string.format("Press Q to quit | Refresh in: %ds", timeLeft))
end

return display
