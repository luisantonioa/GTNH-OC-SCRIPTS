local component = require("component")
local fs = require("filesystem")
local event = require("event")
local term = require("term")
local computer = require("computer")

local me = component.me_interface
local gpu = component.gpu

local DEBUG_MODE = true  -- Set to false for real crafting

local FLUID_STATE_FILE = "/fluid_levels.lua"
local FLUID_THRESHOLDS_FILE = "/fluid_thresholds.lua"
local CRAFT_LOG_FILE = "/craft_log.lua"
local MAX_LOG_ENTRIES = 1000
local DISPLAY_ENTRIES = 10
local CRAFT_RETRY_DELAY = 5
local MAX_RETRIES = 5
local LOOP_INTERVAL = 60

-- Load thresholds from Lua file
local function load_thresholds()
  local ok, data = pcall(dofile, FLUID_THRESHOLDS_FILE)
  if ok and type(data) == "table" then return data else return {} end
end

-- Load previous craft log
local function load_craft_log()
  local ok, data = pcall(dofile, CRAFT_LOG_FILE)
  if ok and type(data) == "table" then return data else return {} end
end

-- Save Lua table to file as a Lua table
local function save_lua_table(path, tbl, varname)
  local handle = io.open(path, "w")
  handle:write(varname .. " = {\n")
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      handle:write(string.format("  [%q] = %q,\n", k, v))
    else
      handle:write(string.format("  [%q] = %s,\n", k, tostring(v)))
    end
  end
  handle:write("}\n")
  handle:close()
end

-- Get fluid levels
local function get_fluids()
  local fluids = me.getFluidsInNetwork() or {}
  local result = {}
  for _, fluid in ipairs(fluids) do
    result[fluid.label] = fluid.amount
  end
  return result
end

-- Attempt a craft with retry/backoff
local function request_craft_with_retry(fluid_name, amount)
  if DEBUG_MODE then return true, "DEBUG: Pretend craft" end
  for i = 1, MAX_RETRIES do
    local success, err = me.requestCraft({{name = fluid_name, amount = amount}}, false)
    if success then return true end
    os.sleep(CRAFT_RETRY_DELAY * i)
  end
  return false, "FAILED after retries"
end

-- Main logic
while true do
  local thresholds = load_thresholds()
  local fluids = get_fluids()
  save_lua_table(FLUID_STATE_FILE, fluids, "fluid_levels")

  local log = load_craft_log()
  local updated_log = {}
  local below = {}
  local now = os.time()

  for fluid, thresh in pairs(thresholds) do
    local current = fluids[fluid] or 0
    if current < thresh.lower then
      table.insert(below, {fluid = fluid, amount = current})
      local craft_amount = thresh.upper - current
      local ok, result = request_craft_with_retry(fluid, craft_amount)
      table.insert(log, 1, string.format("[%s] %s: %s %s",
        os.date("%H:%M:%S", now), fluid,
        ok and "Requested" or "Failed", DEBUG_MODE and "(debug)" or result or ""))
    end
  end

  while #log > MAX_LOG_ENTRIES do table.remove(log) end
  save_lua_table(CRAFT_LOG_FILE, log, "craft_log")

  -- Display
  term.clear()
  print("Last 10 Craft Attempts:")
  for i = 1, math.min(DISPLAY_ENTRIES, #log) do
    print(log[i])
  end

  print("\nBelow Threshold Fluids:")
  for i = 1, math.min(DISPLAY_ENTRIES, #below) do
    local entry = below[i]
    print(string.format("%s: %d", entry.fluid, entry.amount))
  end

  os.sleep(LOOP_INTERVAL)
end
