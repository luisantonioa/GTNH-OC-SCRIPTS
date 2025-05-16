local component = require("component")
local event = require("event")
local computer = require("computer")
local serialization = require("serialization")
local filesystem = require("filesystem")

local me = component.me_interface
local gpu = component.gpu

local LOG_FILE = "/home/craft_log.txt"
local MAX_LOG_ENTRIES = 1000
local MAX_DISPLAY_CRAFTS = 10
local MAX_DISPLAY_FLUIDS = 10
local LOOP_DELAY = 60 -- seconds between loops

local DEBUG_MODE = true  -- Set to false to enable real crafting

-- Load thresholds
local threshold_data = loadfile("/home/thresholds.lua")()

-- Screen setup
local width, height = gpu.getResolution()
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, width, height, " ")

local function clearScreen()
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, width, height, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.setCursor(1,1)
end

local function writeLine(y, text)
  gpu.setCursor(1, y)
  gpu.fill(1, y, width, 1, " ") -- clear line first
  gpu.setCursor(1, y)
  gpu.write(text)
end

-- Log handling
local function read_log_lines(max_lines)
  if not filesystem.exists(LOG_FILE) then return {} end
  local f = io.open(LOG_FILE, "r")
  if not f then return {} end
  local lines = {}
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()
  local start_index = math.max(#lines - max_lines + 1, 1)
  local result = {}
  for i = start_index, #lines do
    table.insert(result, lines[i])
  end
  return result
end

local function write_log(lines)
  local f = io.open(LOG_FILE, "w")
  if not f then
    return
  end
  for _, line in ipairs(lines) do
    f:write(line.."\n")
  end
  f:close()
end

local function append_log(entry)
  local lines = read_log_lines(MAX_LOG_ENTRIES)
  table.insert(lines, entry)
  while #lines > MAX_LOG_ENTRIES do
    table.remove(lines, 1)
  end
  write_log(lines)
end

-- Craft with retry/backoff
local function request_craft_with_retry(fluid_name, amount, max_retries, delay_sec)
  if DEBUG_MODE then
    -- Pretend to succeed without actually requesting craft
    return true
  end

  max_retries = max_retries or 5
  delay_sec = delay_sec or 5

  for attempt = 1, max_retries do
    local success, err = me.requestCraft({
      {
        name = fluid_name,
        amount = amount,
      }
    }, false)

    if success then
      return true
    else
      if attempt < max_retries then
        os.sleep(delay_sec)
        delay_sec = delay_sec * 2
      end
    end
  end
  return false
end

local function run_once()
  clearScreen()

  local fluids = me.getFluidsInNetwork()
  table.sort(fluids, function(a,b) return a.label < b.label end)

  local low_fluids = {}
  local crafts_this_run = {}

  for _, fluid in ipairs(fluids) do
    local label = fluid.label
    local amount = fluid.amount
    local thresholds = threshold_data[label]

    if thresholds then
      local lower = thresholds.lower
      local upper = thresholds.upper

      if amount < lower then
        table.insert(low_fluids, {label = label, amount = amount, lower = lower})
        if #low_fluids > MAX_DISPLAY_FLUIDS then
          break
        end

        local need = upper - amount
        if need > 0 then
          local success = request_craft_with_retry(fluid.name, need)

          local timestamp = os.date("%Y-%m-%d %H:%M:%S")
          local log_entry = string.format("%s: Craft request for %s amount %d %s", timestamp, label, need, success and "SUCCESS" or "FAILED")
          append_log(log_entry)

          table.insert(crafts_this_run, log_entry)
          if #crafts_this_run > MAX_DISPLAY_CRAFTS then
            table.remove(crafts_this_run, 1)
          end
        end
      end
    end
  end

  -- Show output on screen

  -- Header
  writeLine(1, "GTNH Fluid Craft Monitor - " .. os.date())

  -- Low fluids
  writeLine(3, "Fluids BELOW lower threshold (max "..MAX_DISPLAY_FLUIDS.."):")
  local y = 4
  for i = 1, math.min(#low_fluids, MAX_DISPLAY_FLUIDS) do
    local f = low_fluids[i]
    writeLine(y, string.format("%s: %d < %d", f.label, f.amount, f.lower))
    y = y + 1
  end
  if #low_fluids == 0 then
    writeLine(y, "All fluids above thresholds.")
    y = y + 1
  end

  -- Last crafts
  y = y + 1
  writeLine(y, "Last Craft Attempts (max "..MAX_DISPLAY_CRAFTS.."):")
  y = y + 1
  local last_logs = read_log_lines(MAX_DISPLAY_CRAFTS)
  for i = 1, math.min(#last_logs, MAX_DISPLAY_CRAFTS) do
    writeLine(y, last_logs[#last_logs - MAX_DISPLAY_CRAFTS + i] or last_logs[i])
    y = y + 1
    if y > height then break end
  end
end

-- Main loop
while true do
  local success, err = pcall(run_once)
  if not success then
    clearScreen()
    writeLine(1, "Error: "..tostring(err))
  end
  os.sleep(LOOP_DELAY)
end
