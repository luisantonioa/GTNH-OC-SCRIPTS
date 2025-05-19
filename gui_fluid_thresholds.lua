local component = require("component")
local event = require("event")
local term = require("term")
local keyboard = require("keyboard")
local serialization = require("serialization")
local unicode = require("unicode")

local gpu = component.gpu
local screen = component.screen
local meInterface = component.me_interface

local PAGE_SIZE = 18

local function readAvailableFluids()
  local fluids = {}
  for _, f in ipairs(meInterface.getFluidsInNetwork()) do
    fluids[f.label] = true
  end
  return fluids
end

local function getSortedFluidNames(thresholds)
  local names = {}
  for k in pairs(thresholds) do
    table.insert(names, k)
  end
  table.sort(names)
  return names
end

local function promptInput(label, default)
  term.setCursor(1, 25)
  term.clearLine()
  io.write(label .. " [default: " .. tostring(default) .. "]: ")
  local input = io.read()
  return tonumber(input) or default
end

local function confirm(prompt)
  term.setCursor(1, 26)
  term.clearLine()
  io.write(prompt .. " (y/N): ")
  local answer = io.read()
  return answer:lower() == "y"
end

local function editThreshold(thresholds, name)
  local current = thresholds[name] or {lower = 0, upper = 0}
  local newLower = promptInput("Enter new lower threshold for " .. name, current.lower)
  local newUpper = promptInput("Enter new upper threshold for " .. name, current.upper)
  thresholds[name] = {lower = newLower, upper = newUpper}

  if confirm("Remove this fluid from tracking?") then
    thresholds[name] = nil
  end
end

local function addFluid(thresholds)
  local available = readAvailableFluids()
  for name in pairs(thresholds) do
    available[name] = nil
  end

  local options = {}
  for name in pairs(available) do
    table.insert(options, name)
  end
  table.sort(options)

  if #options == 0 then
    term.setCursor(1, 25)
    term.clearLine()
    print("No new fluids available to track.")
    os.sleep(2)
    return
  end

  term.clear()
  print("Available Fluids to Add:")
  for i, name in ipairs(options) do
    term.setCursor(2, i + 1)
    print(string.format("%d. %s", i, name))
  end

  term.setCursor(1, #options + 3)
  print("Enter number of fluid to add, or press 'q' to cancel:")

  local input = ""
  while true do
    local _, _, _, _, _, ch = event.pull("key_down")
    if ch == keyboard.keys.q then
      return
    elseif ch >= keyboard.keys['0'] and ch <= keyboard.keys['9'] then
      input = input .. tostring(ch - keyboard.keys['0'])
      term.setCursor(1, #options + 4)
      term.clearLine()
      io.write("Selected: " .. input)
    elseif ch == keyboard.keys.enter then
      local index = tonumber(input)
      if index and options[index] then
        local name = options[index]
        local lower = promptInput("Lower threshold for " .. name, 1000)
        local upper = promptInput("Upper threshold for " .. name, 8000)
        thresholds[name] = {lower = lower, upper = upper}
      end
      return
    end
  end
end

local function saveThresholds(thresholds, file)
  local f = io.open(file, "w")
  f:write("return " .. serialization.serialize(thresholds))
  f:close()
end

local function draw(thresholds, page, filter)
  term.clear()
  gpu.setForeground(0xFFFFFF)
  term.setCursor(1, 1)
  print("Tracked Fluids (click to edit/remove):")

  local sorted = getSortedFluidNames(thresholds)
  if filter and #filter > 0 then
    local filtered = {}
    for _, name in ipairs(sorted) do
      if name:lower():find(filter:lower(), 1, true) then
        table.insert(filtered, name)
      end
    end
    sorted = filtered
  end

  local totalPages = math.max(1, math.ceil(#sorted / PAGE_SIZE))
  page = math.max(1, math.min(page, totalPages))
  local startIdx = (page - 1) * PAGE_SIZE + 1
  local endIdx = math.min(startIdx + PAGE_SIZE - 1, #sorted)

  for i = startIdx, endIdx do
    local name = sorted[i]
    local limits = thresholds[name]
    local line = string.format("%d. %-20s [%d - %d]", i, name, limits.lower, limits.upper)
    term.setCursor(2, 2 + (i - startIdx + 1))
    term.clearLine()
    print(line)
  end

  term.setCursor(1, 23)
  term.clearLine()
  print(string.format("Page %d/%d | Press 'a' to add, 'q' to quit, '/' to filter", page, totalPages))
end

local function run(thresholds, file)
  local page = 1
  local filter = ""
  draw(thresholds, page, filter)

  while true do
    local evt, _, a, b, c, d = event.pull("key_down", "touch")

    if evt == "key_down" then
      local key = d
      if key == keyboard.keys.q then
        break
      elseif key == keyboard.keys.a then
        addFluid(thresholds)
        saveThresholds(thresholds, file)
        draw(thresholds, page, filter)
      elseif key == keyboard.keys.pageDown or key == keyboard.keys.down then
        page = page + 1
        draw(thresholds, page, filter)
      elseif key == keyboard.keys.pageUp or key == keyboard.keys.up then
        page = page - 1
        draw(thresholds, page, filter)
      elseif key == keyboard.keys.slash then
        term.setCursor(1, 25)
        term.clearLine()
        io.write("Filter: ")
        filter = io.read()
        page = 1
        draw(thresholds, page, filter)
      end

    elseif evt == "touch" then
      local x = a
      local y = b
      if y >= 3 and y <= 22 then
        local sorted = getSortedFluidNames(thresholds)
        if filter and #filter > 0 then
          local filtered = {}
          for _, name in ipairs(sorted) do
            if name:lower():find(filter:lower(), 1, true) then
              table.insert(filtered, name)
            end
          end
          sorted = filtered
        end

        local index = (page - 1) * PAGE_SIZE + (y - 2)
        if sorted[index] then
          local name = sorted[index]
          editThreshold(thresholds, name)
          saveThresholds(thresholds, file)
          draw(thresholds, page, filter)
        end
      end
    end
  end
end

return {
  run = run
}
