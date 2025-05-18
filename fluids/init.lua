local component = require("component")
local event = require("event")
local computer = require("computer")
local keyboard = require("keyboard")
local fs = require("filesystem")

local config = require("/home/fluids/config")
local utils = require("/home/fluids/utils")
local crafting = require("/home/fluids/crafting")
local display = require("/home/fluids/display")

local DEBUG_MODE = false
local LOOP_INTERVAL = 60
local craftLog = {}
local MAX_LOG_ENTRIES = 100
local thresholds = config.load()

local mainInterface
for _, addr in ipairs(utils.findMEInterfaces()) do
  if component.proxy(addr).getFluidsInNetwork then
    mainInterface = component.proxy(addr)
    break
  end
end

local function readFluids()
  local fluids = {}
  local success, result = pcall(mainInterface.getFluidsInNetwork)
  if not success or type(result) ~= "table" then
    return nil, "AE2 Offline"
  end
  for _, f in ipairs(result) do
    fluids[f.label] = f.amount
  end
  return fluids
end

local function monitor()
  while true do
    local fluids, err = readFluids()
    if not fluids then
      print("[WARN] AE2 offline: " .. (err or "unknown"))
      os.sleep(LOOP_INTERVAL)
    else
      for name, t in pairs(thresholds) do
        local amt = fluids[name] or 0
        if amt < t.lower then
          local reqAmt = t.upper - amt
          local ok, reason = crafting.request(name, reqAmt, DEBUG_MODE)
          table.insert(craftLog, {fluid = name, amount = reqAmt, time = os.time(), status = ok and "ok" or reason})
          if #craftLog > MAX_LOG_ENTRIES then table.remove(craftLog, 1) end
        end
      end
    end
    local nextTick = computer.uptime() + LOOP_INTERVAL
    display.status(fluids or {}, thresholds, craftLog, nextTick)
    repeat
      local evt, _, char, code = event.pull(0.1, "key_down")
      if evt and (char == string.byte("q") or code == keyboard.keys.q) then return end
    until computer.uptime() >= nextTick
  end
end

monitor()
