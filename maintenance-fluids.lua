local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")
local keyboard = require("keyboard")
local fs = require("filesystem")
local unicode = require("unicode")
local serialization = require("serialization")

local gpu = component.gpu
local screen = component.screen
gpu.bind(screen.address)

-- Settings
local DISPLAY_ENTRIES = 10
local LOOP_INTERVAL = 60  -- seconds
local DEBUG_MODE = true
local LOG_FILE = "/home/craft_log.lua"
local THRESHOLD_FILE = "/home/fluid_thresholds.lua"
local MAX_LOG_ENTRIES = 1000

-- Load fluid thresholds
local thresholds = dofile(THRESHOLD_FILE)

-- Craft log
local craftLog = {}
if fs.exists(LOG_FILE) then
  local ok, result = pcall(dofile, LOG_FILE)
  if ok and type(result) == "table" then
    craftLog = result
  end
end

-- Set screen resolution
local w, h = gpu.maxResolution()
gpu.setResolution(w, h)

local function saveCraftLog()
  local file = io.open(LOG_FILE, "w")
  file:write("return " .. serialization.serialize(craftLog))
  file:close()
end

local function formatNumber(n)
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

local function displayStatus(fluids, skipHeader)
  if not skipHeader then
    term.clear()
    gpu.setForeground(0xFFFFFF)
    gpu.set(1, 1, "=== Fluid Monitor ===")
  end

  local baseLine = skipHeader and 2 or 3

  gpu.set(1, baseLine, "Tracked Fluids:")
  local i = 0
  local names = {}
  for name in pairs(thresholds) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    if i >= DISPLAY_ENTRIES then break end
    local val = fluids[name] or 0
    local limits = thresholds[name]
    local line = string.format("%-20s: %8s / [%s, %s]",
      name,
      formatNumber(val),
      formatNumber(limits.lower),
      formatNumber(limits.upper)
    )
    gpu.set(2, baseLine + 1 + i, unicode.sub(line, 1, w - 2))
    i = i + 1
  end

  gpu.set(1, baseLine + 13, "Last Craft Attempts:")
  for j = 1, math.min(DISPLAY_ENTRIES, #craftLog) do
    local entry = craftLog[#craftLog - j + 1]
    local line = string.format("%-20s: %d", entry.fluid, entry.amount)
    gpu.set(2, baseLine + 13 + j, unicode.sub(line, 1, w - 2))
  end

  gpu.setForeground(0x00FF00)
  gpu.set(1, h, "Press Q to quit")
end

local function readFluids()
  local fluids = {}
  local me = component.me_interface
  for _, f in ipairs(me.getFluidsInNetwork()) do
    fluids[f.label] = f.amount
  end
  return fluids
end

local function requestCraft(fluid, amount)
  if DEBUG_MODE then
    print("DEBUG: would request craft for", fluid, amount)
    return true
  end
  local me = component.me_interface
  local success = me.requestCrafting({name = fluid, amount = amount})
  return success
end

local function monitor()
  local nextRefresh = computer.uptime() + LOOP_INTERVAL

  while true do
    local now = computer.uptime()
    local fluids = readFluids()

    -- Craft requests if below thresholds
    for name, t in pairs(thresholds) do
      local amt = fluids[name] or 0
      if amt < t.lower then
        local reqAmt = t.upper - amt
        local success = requestCraft(name, reqAmt)
        table.insert(craftLog, {
          fluid = name,
          amount = reqAmt,
          time = os.time()
        })
        if #craftLog > MAX_LOG_ENTRIES then
          table.remove(craftLog, 1)
        end
        saveCraftLog()
      end
    end

    -- Reset next refresh time
    nextRefresh = computer.uptime() + LOOP_INTERVAL

    -- Inner loop to update countdown every 0.1 seconds and handle quit key
    while computer.uptime() < nextRefresh do
      local timeLeft = math.ceil(nextRefresh - computer.uptime())

      -- Redraw status with countdown line
      term.clear()
      gpu.setForeground(0xFFFFFF)
      gpu.set(1, 1, "=== Fluid Monitor ===   Next refresh in: " .. timeLeft .. "s")

      -- Display the rest without clearing header again
      displayStatus(fluids, true)

      local evt, _, char, code = event.pull(0.1, "key_down")
      if evt and (char == string.byte("q") or code == keyboard.keys.q) then
        print("Exiting...")
        os.exit()
      end
    end
  end
end

monitor()
