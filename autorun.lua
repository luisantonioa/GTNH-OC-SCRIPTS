local computer = require("computer")
local shell = require("shell")
local fs = require("filesystem")

-- Where to log restart times
local logFile = "/home/restart.log"

-- Function to log messages
local function log(msg)
  local file, err = io.open(logFile, "a")
  if not file then
    io.stderr:write("Log error: " .. tostring(err) .. "\n")
    return
  end
  file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
  file:close()
end

-- Run your main program here
local function runMain()
  -- Replace with your program path
  shell.execute("/home/pump.lua")
end

-- Main loop
while true do
  log("Starting main program")
  runMain()

  log("Sleeping for 30 minutes before restart...")
  os.sleep(1800) -- 30 min

  log("Restarting system...")
  computer.shutdown(true) -- true = restart
end
