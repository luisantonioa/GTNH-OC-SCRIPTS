local event = require("event")
local computer = require("computer")
local keyboard = require("keyboard")

local config = require("config")
local utils = require("utils")
local ae = require("ae")
local display = require("display")

local thresholds = utils.loadTable(config.thresholdFile)
local craftLog = utils.loadTable(config.logFile)

local function logCraft(fluid, amount)
  table.insert(craftLog, {
    fluid = fluid,
    amount = amount,
    time = os.time()
  })
  while #craftLog > config.maxLogEntries do
    table.remove(craftLog, 1)
  end
  utils.saveTable(config.logFile, craftLog)
end

while true do
  local fluids = ae.getFluids()
  if ae.isOnline() then
    for name, t in pairs(thresholds) do
      local amt = fluids[name] or 0
      if amt < t.lower then
        local reqAmt = t.upper - amt
        if config.debugMode then
          print("[DEBUG] Would craft", name, reqAmt)
        else
          if ae.requestCraft(name, reqAmt) then
            logCraft(name, reqAmt)
          end
        end
      end
    end
  else
    print("[WARN] AE2 offline. Skipping craft requests.")
  end

  -- Refresh Display
  for i = config.loopInterval, 0, -1 do
    display.draw(fluids, thresholds, craftLog, i)
    local evt, _, char, code = event.pull(1, "key_down")
    if evt and (char == string.byte("q") or code == keyboard.keys.q) then
      os.exit()
    end
  end
end
