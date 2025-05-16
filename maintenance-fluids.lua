local component = require("component")
local serialization = require("serialization")
local computer = require("computer")
local me = component.me_interface
local filesystem = require("filesystem")

local LOG_FILE = "/home/craft_log.txt"
local MAX_LOG_ENTRIES = 1000
local MAX_DISPLAY_CRAFTS = 10
local MAX_DISPLAY_FLUIDS = 10

-- Load thresholds
local threshold_data = loadfile("/home/thresholds.lua")()

-- Utility: read existing craft log entries (last N)
local function read_log_lines(max_lines)
  if not filesystem.exists(LOG_FILE) then return {} end
  local f = io.open(LOG_FILE, "r")
  if not f then return {} end
  local lines = {}
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()
  -- Return last max_lines lines
  local start_index = math.max(#lines - max_lines + 1, 1)
  local result = {}
  for i = start_index, #lines do
    table.insert(result, lines[i])
  end
  return result
end

-- Utility: write craft log entries (overwrite)
local function write_log(lines)
  local f = io.open(LOG_FILE, "w")
  if not f then
    print("ERROR: Cannot write craft log")
    return
  end
  for _, line in ipairs(lines) do
    f:write(line.."\n")
  end
  f:close()
end

-- Append one log entry, trimming oldest if needed
local function append_log(entry)
  local lines = read_log_lines(MAX_LOG_ENTRIES)
  table.insert(lines, entry)
  while #lines > MAX_LOG_ENTRIES do
    table.remove(lines, 1)
  end
  write_log(lines)
end

-- Craft request with retry/backoff
local function request_craft_with_retry(fluid_name, amount, max_retries, delay_sec)
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
      print(string.format("Craft request failed for %s (attempt %d/%d): %s", fluid_name, attempt, max_retries, tostring(err)))
      if attempt < max_retries then
        print("Retrying in "..delay_sec.." seconds...")
        os.sleep(delay_sec)
        delay_sec = delay_sec * 2 -- exponential backoff
      end
    end
  end
  return false
end

-- Main check & request loop
local fluids = me.getFluidsInNetwork()
table.sort(fluids, function(a, b) return a.label < b.label end)

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
        -- only keep first MAX_DISPLAY_FLUIDS
        break
      end

      local need = upper - amount
      if need > 0 then
        print(string.format("⚠️ %s low (%d < %d). Requesting craft for %d units.", label, amount, lower, need))

        local success = request_craft_with_retry(fluid.name, need)

        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local log_entry = string.format("%s: Craft request for %s amount %d %s", timestamp, label, need, success and "SUCCESS" or "FAILED")
        append_log(log_entry)

        if success then
          print("Craft request submitted.")
        else
          print("Craft request failed after retries.")
        end

        table.insert(crafts_this_run, log_entry)
        if #crafts_this_run > MAX_DISPLAY_CRAFTS then
          table.remove(crafts_this_run, 1)
        end
      end
    else
      print(string.format("✅ %s sufficient (%d ≥ %d).", label, amount, lower))
    end
  end
end

-- Show summary onscreen: last crafts and low fluids
print("\n=== Last Craft Attempts (last "..MAX_DISPLAY_CRAFTS..") ===")
local last_logs = read_log_lines(MAX_DISPLAY_CRAFTS)
for _, entry in ipairs(last_logs) do
  print(entry)
end

print("\n=== Fluids below lower threshold (max "..MAX_DISPLAY_FLUIDS..") ===")
for _, f in ipairs(low_fluids) do
  print(string.format("%s: %d < %d", f.label, f.amount, f.lower))
end
