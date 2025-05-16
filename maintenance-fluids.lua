local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")
local event = require("event")
local term = require("term")
local computer = require("computer")

local me = component.me_interface
local gpu = component.gpu
local screen = component.screen

local DEBUG_MODE = true  -- Set to false for real crafting

local FLUID_STATE_FILE = "/fluid_levels.json"
local FLUID_THRESHOLDS_FILE = "/fluid_thresholds.json"
local CRAFT_LOG_FILE = "/craft_log.json"
local MAX_LOG_ENTRIES = 1000
local DISPLAY_ENTRIES = 10
local CRAFT_RETRY_DELAY = 5
local MAX_RETRIES = 5
local LOOP_INTERVAL = 60

local function read_thresholds()
  local handle, err = io.open(FLUID_THRESHOLDS_FILE, "r")
  if not handle then return {} end
  local content = handle:read("*a")
  handle:close()
  return serialization.unserialize(content) or {}
end

local function get_fluids()
  local fluids = me.getFluidsInNetwork()
  local fluid_map = {}
  for _, fluid in ipairs(fluids or {}) do
    fluid_map[fluid.label] = fluid.amount
  end
  return fluid_map
end

local function save_json_chunked(tbl, path)
  local handle, err = io.open(path, "w")
  if not handle then return false end
  handle:write("{\n")
  local first = true
  for k, v in pairs(tbl) do
    if not first then
      handle:write(",\n")
    end
    handle:write(string.format("  %q: %d", k, v))
    first = false
  end
  handle:write("\n}\n")
  handle:close()
  return true
end

local function request_craft_with_retry(fluid, amount)
  if DEBUG_MODE then return true end
  for attempt = 1, MAX_RETRIES do
    local success = me.requestCraft({{name = fluid, amount = amount}}, false)
    if success then return true end
    os.sleep(CRAFT_RETRY_DELAY * attempt)
  end
  return false
end

local function load_craft_log()
  local f = io.open(CRAFT_LOG_FILE, "r")
  if not f then return {} end
  local log = serialization.unserialize(f:read("*a")) or {}
  f:close()
  return log
end

local function save_craft_log(log)
  while #log > MAX_LOG_ENTRIES do
    table.remove(log, 1)
  end
  local f = io.open(CRAFT_LOG_FILE, "w")
  if f then
    f:write(serialization.serialize(log))
    f:close()
  end
end

local function update_display(log, low_fluids)
  term.clear()
  term.setCursor(1, 1)
  print("GTNH Fluid Monitor")
  print("Below Thresholds:")
  for i = 1, math.min(DISPLAY_ENTRIES, #low_fluids) do
    local fluid = low_fluids[i]
    print(string.format(" - %s: %d / min %d", fluid.name, fluid.amount, fluid.min))
  end
  print("\nRecent Craft Attempts:")
  for i = math.max(1, #log - DISPLAY_ENTRIES + 1), #log do
    local entry = log[i]
    print(string.format(" %s %d units of %s", entry.success and "✓" or "✗", entry.amount, entry.name))
  end
end

-- Main loop
while true do
  local fluids = get_fluids()
  save_json_chunked(fluids, FLUID_STATE_FILE)

  local thresholds = read_thresholds()
  local craft_log = load_craft_log()

  local low_fluids = {}

  for name, limits in pairs(thresholds) do
    local current = fluids[name] or 0
    if current < limits.lower then
      table.insert(low_fluids, {name = name, amount = current, min = limits.lower})
      local craft_success = request_craft_with_retry(name, limits.upper - current)
      table.insert(craft_log, {
        time = os.time(),
        name = name,
        amount = limits.upper - current,
        success = craft_success,
        debug = DEBUG_MODE
      })
    end
  end

  save_craft_log(craft_log)
  table.sort(low_fluids, function(a, b) return a.name < b.name end)
  update_display(craft_log, low_fluids)

  os.sleep(LOOP_INTERVAL)
end
