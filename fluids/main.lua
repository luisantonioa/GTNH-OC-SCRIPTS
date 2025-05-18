local event = require("event")
local computer = require("computer")
local keyboard = require("keyboard")

local config = require("fluids/config")
local utils = require("fluids/utils")
local display = require("fluids/display")
local craftLog = require("fluids/craft_log")

local thresholds = dofile(config.THRESHOLD_FILE)
local log = craftLog.load()

local function monitor()
  while true do
    local fluids = utils.readFluids()

    for name, t in pairs(thresholds) do
      local amt = fluids[name] or 0
      if amt < t.lower then
        local reqAmt = t.upper - amt
        local craftable = utils.findCraftable(name)
        if craftable then
          if config.DEBUG_MODE then
            print("DEBUG: Would request craft of", reqAmt, name)
          else
            craftable.request(reqAmt)
          end
          table.insert(log, {
            fluid = name,
            amount = reqAmt,
            time = os.time()
          })
          if #log > config.MAX_LOG_ENTRIES then
            table.remove(log, 1)
          end
          craftLog.save(log)
        end
      end
    end

    local refreshTime = config.LOOP_INTERVAL
    while refreshTime > 0 do
      display.status(fluids, thresholds, log, refreshTime)
      local evt, _, char, code = event.pull(1, "key_down")
      if evt and (char == string.byte("q") or code == keyboard.keys.q) then
        print("Exiting...")
        os.exit()
      end
      refreshTime = refreshTime - 1
    end
  end
end

monitor()
