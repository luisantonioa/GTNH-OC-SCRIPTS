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

local interfaceAddress = "bea7e9dc-bc7f-4b4b-88dc-8d65b08df7b0"
local meInterface = component.proxy(interfaceAddress)
local meController = component.me_controller

-- Settings
local DISPLAY_ENTRIES = 10
local LOOP_INTERVAL = 60  -- seconds
local DEBUG_MODE = false
local LOG_FILE = "/home/craft_log.lua"
local THRESHOLD_FILE = "/home/fluid_thresholds.lua"
local MAX_LOG_ENTRIES = 1000

local fluidStatuses = {}
local STATUS_SYMBOLS = {
  ok = "✅",
  crafting = "🔄",
  error = "❌"
}

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

-- Retry cooldowns per fluid
local retryCooldowns = {}

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

local function displayStatus(fluids, timeLeft)
  term.clear()
  gpu.setForeground(0xFFFFFF)
  gpu.set(1, 1, "=== Fluid Monitor ===")

  -- Tracked fluids
  gpu.set(1, 3, "Tracked Fluids:")
  local i = 0
  local names = {}
  for name in pairs(thresholds) do table.insert(names, name) end
  table.sort(names)
  for i, name in ipairs(names) do
    if i >= DISPLAY_ENTRIES then break end
    local val = fluids[name] or 0
    local limits = thresholds[name]
    local status = fluidStatuses[name] or "ok"
    local symbol = STATUS_SYMBOLS[status] or "?"
    local line = string.format("%d. %s %-20s: %8s / [%s, %s]",
      i,
      symbol,
      name,
      formatNumber(val),
      formatNumber(limits.lower),
      formatNumber(limits.upper)
    )
    gpu.set(2, 4 + i, unicode.sub(line, 1, w - 2))
    i = i + 1
  end

  -- Last crafts
  gpu.set(1, 16, "Last Craft Attempts:")
  for j = 1, math.min(DISPLAY_ENTRIES, #craftLog) do
    local entry = craftLog[#craftLog - j + 1]
    local line = string.format("[%s] %-20s: %s", entry.time, entry.fluid, formatNumber(entry.amount))
    gpu.set(2, 16 + j, unicode.sub(line, 1, w - 2))
  end

  -- Footer
  gpu.setForeground(0xFFFF00)
  gpu.set(1, h - 1, string.format("Next refresh in: %.0fs", timeLeft))
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

local function findCraftable(fluid)
  for _, craft in ipairs(meInterface.getCraftables()) do
    local stack = craft.getItemStack()
    local fluidToLabel = "drop of " .. fluid
    if stack.label == fluidToLabel then
      return craft
    end
  end
end

-- Cache of fluid name -> CraftingStatus
local activeCrafts = {}

-- Check if a craft is currently running
local function isCraftRunning(fluid)
  local status = activeCrafts[fluid]
  if not status then return false end

  -- Use CraftingStatus API to check if it's still in progress
  local ok, result = pcall(function()
    return not status.isDone() and not status.isCanceled()
  end)

  -- If the status object threw an error or finished, clean it up
  if not ok or not result then
    activeCrafts[fluid] = nil
    fluidStatuses[fluid] = "ok"
    return false
  end

  fluidStatuses[fluid] = "crafting"
  return true
end

local function requestCraft(fluid, amount)
  if DEBUG_MODE then
    print("DEBUG: would request craft for", fluid, amount)
    return true
  end
  if isCraftRunning(fluid) then
    print("[INFO] Skipping craft; already running for " .. fluid)
    return false
  end
  local craft = findCraftable(fluid)
  if craft then
    local ok, result = pcall(function()
      return craft.request(amount)
    end)

    if ok and result then
      activeCrafts[fluid] = result -- result is a CraftingStatus object
      fluidStatuses[fluid] = "crafting"
      print("[INFO] Crafting request accepted for " .. fluid)
      return true
    else
      print("[ERROR] Craft request failed for " .. fluid .. ": " .. tostring(result))
      fluidStatuses[fluid] = "error"
    end
  else
    print("[WARN] No craftable found for " .. fluid)
    fluidStatuses[fluid] = "error"
  end

  return false
end

local function monitor()
  while true do
    local fluids = readFluids()
    local now = computer.uptime()

    -- Loop through thresholds
    for name, t in pairs(thresholds) do
      local amt = fluids[name] or 0
      if amt < t.lower and (not retryCooldowns[name] or retryCooldowns[name] < now) then
        local reqAmt = t.upper - amt
        if requestCraft(name, reqAmt) then
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
        retryCooldowns[name] = now + LOOP_INTERVAL
      end
    end

    -- Countdown loop
    local deadline = computer.uptime() + LOOP_INTERVAL
    repeat
      local timeLeft = deadline - computer.uptime()
      displayStatus(fluids, timeLeft)
      local evt, _, char, code = event.pull(0.1, "key_down")
      if evt and (char == string.byte("q") or code == keyboard.keys.q) then
        print("Exiting...")
        os.exit()
      end
    until computer.uptime() >= deadline
  end
end

monitor()
