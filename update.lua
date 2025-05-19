local fs = require("filesystem")
local shell = require("shell")
local internet = require("internet")

local baseURL = "https://raw.githubusercontent.com/luisantonioa/GTNH-OC-SCRIPTS/main/fluids/"
local targetDir = "/home/"
local files = {
    "fluid_thresholds",
    "main"
}

local function download(file)
  local url = baseURL .. file .. "?v=" .. tostring(math.random(1, 1e9))
  local path = targetDir .. file
  print("Downloading " .. file .. "...")
  local response = internet.request(url)
  local f = io.open(path, "w")
  for chunk in response do
    f:write(chunk)
  end
  f:close()
end

for _, file in ipairs(files) do
  download(file)
end

-- Create startup.lua to run the monitor
local startup = io.open("/home/startup.lua", "w")
startup:write("dofile(\"" .. targetDir .. "main.lua\")\n")
startup:close()

print("Deploy complete. Reboot to start fluid monitor.")
